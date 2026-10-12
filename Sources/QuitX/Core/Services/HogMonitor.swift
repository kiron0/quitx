import AppKit
import Combine
import Foundation
@preconcurrency import UserNotifications

struct HogTracker: Sendable {
    func hogPids(
        cpuByPid: [pid_t: Double],
        threshold: Double
    ) -> Set<pid_t> {
        var hogs = Set<pid_t>()
        for (pid, cpu) in cpuByPid where cpu >= threshold {
            hogs.insert(pid)
        }
        return hogs
    }

    mutating func reset() {}
}

struct HogRescueGate {
    static let armDelay: TimeInterval = 15
    static let sustainInterval: TimeInterval = 15
    static let hysteresis: Double = 5

    var overSince: Date?

    mutating func evaluate(cpu: Double, threshold: Double, armedAt: Date?, now: Date) -> Bool {
        guard let armedAt, now.timeIntervalSince(armedAt) >= Self.armDelay else {
            overSince = nil
            return false
        }
        if cpu >= threshold {
            if overSince == nil { overSince = now }
            return now.timeIntervalSince(overSince!) >= Self.sustainInterval
        }
        if cpu < threshold - Self.hysteresis {
            overSince = nil
        }
        return false
    }

    mutating func reset() {
        overSince = nil
    }
}

@MainActor
final class HogMonitor {
    static let shared = HogMonitor()

    private var tracker = HogTracker()
    private var notifiedPids = Set<pid_t>()
    private var notifiedSystemOverLimit = false
    private var gate = HogRescueGate()
    private var armedAt: Date?
    private var popoverGate = HogRescueGate()
    private var popoverArmedAt: Date?
    private var backgroundTask: Task<Void, Never>?
    private var configObserver: AnyCancellable?
    private var lastEnabledValue: Bool?

    private init() {
        configObserver = ConfigStore.shared.$config
            .map(\.hogAlertEnabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                Task { @MainActor [weak self] in
                    self?.handleEnabledChange(enabled)
                }
            }
    }

    private func handleEnabledChange(_ enabled: Bool) {
        let wasEnabled = lastEnabledValue
        lastEnabledValue = enabled
        if enabled, wasEnabled == false {
            armedAt = Date()
            popoverArmedAt = Date()
        }
    }

    func startBackgroundMonitoring() {
        guard backgroundTask == nil else { return }
        backgroundTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let saver = BatterySaver.isSaverActive(config: ConfigStore.shared.config)
                try? await Task.sleep(nanoseconds: saver ? 10_000_000_000 : 2_000_000_000)
                guard !Task.isCancelled else { break }
                await self.backgroundTick()
            }
        }
    }

    func stopBackgroundMonitoring() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    private func backgroundTick() async {
        let config = ConfigStore.shared.config
        guard config.hogAlertEnabled else {
            disarm()
            return
        }
        let threshold = config.effectiveHogCpuThreshold
        let systemCPU = SystemUsage.cpuPercent(consumer: "hog")
        if systemCPU < threshold - HogRescueGate.hysteresis {
            notifiedSystemOverLimit = false
        }
        guard rescueEligible(cpu: systemCPU, threshold: threshold) else { return }
        if !notifiedSystemOverLimit {
            notifiedSystemOverLimit = true
            postNotification(
                title: "High CPU usage",
                body: String(
                    format: "System CPU load stayed at %.0f%% (limit %.0f%%). QuitX will ask you before quitting inactive apps.",
                    systemCPU,
                    threshold
                )
            )
        }
        await AppListViewModel.shared.runBackgroundHogRescue(cpu: systemCPU, limit: threshold)
    }

    func rescueEligible(cpu: Double, threshold: Double) -> Bool {
        if armedAt == nil {
            armedAt = Date()
        }
        return gate.evaluate(cpu: cpu, threshold: threshold, armedAt: armedAt, now: Date())
    }

    func popoverRescueEligible(cpu: Double, threshold: Double) -> Bool {
        if popoverArmedAt == nil {
            popoverArmedAt = Date()
        }
        return popoverGate.evaluate(cpu: cpu, threshold: threshold, armedAt: popoverArmedAt, now: Date())
    }

    private func disarm() {
        notifiedSystemOverLimit = false
        gate.reset()
        armedAt = nil
        popoverGate.reset()
        popoverArmedAt = nil
    }

    func reset() {
        tracker.reset()
        notifiedPids.removeAll()
        disarm()
    }

    func noteLiveApps(
        _ apps: [AppInfo],
        threshold: Double,
        usages: [pid_t: Double]
    ) -> Set<pid_t> {
        var cpuByPid: [pid_t: Double] = [:]
        for app in apps {
            for pid in app.pids {
                if let value = usages[pid] {
                    cpuByPid[pid] = value
                } else if app.pids.count == 1 {
                    cpuByPid[pid] = app.cpuUsage
                }
            }
        }
        return noteCpuSample(
            cpuByPid: cpuByPid,
            threshold: threshold,
            apps: apps
        )
    }

    @discardableResult
    private func noteCpuSample(
        cpuByPid: [pid_t: Double],
        threshold: Double,
        apps: [AppInfo]
    ) -> Set<pid_t> {
        let hogs = tracker.hogPids(
            cpuByPid: cpuByPid,
            threshold: threshold
        )
        // Keep a pid "notified" until CPU drops below threshold minus hysteresis,
        // so oscillation around the threshold does not re-fire notifications.
        let floor = threshold - HogRescueGate.hysteresis
        notifiedPids = notifiedPids.filter { pid in
            (cpuByPid[pid] ?? 0) >= floor
        }
        let fresh = hogs.subtracting(notifiedPids)
        if !fresh.isEmpty {
            notifyHogs(pids: fresh, apps: apps)
            notifiedPids.formUnion(fresh)
        }
        return hogs
    }

    private func notifyHogs(pids: Set<pid_t>, apps: [AppInfo]) {
        let names = apps.filter { !$0.pids.isEmpty && !Set($0.pids).isDisjoint(with: pids) }
            .prefix(3)
            .map(\.name)
        let body: String
        if names.isEmpty {
            body = "\(pids.count) app(s) exceeded CPU limit. Open QuitX to review."
        } else {
            body = "\(names.joined(separator: ", ")) \(names.count == 1 ? "is" : "are") over CPU limit. Open QuitX to review."
        }
        postNotification(title: "High CPU usage", body: body)
    }

    private func postNotification(title: String, body: String) {
        Task { [weak self] in
            let center = UNUserNotificationCenter.current()
            var status = (await center.notificationSettings()).authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = (await center.notificationSettings()).authorizationStatus
            }
            guard status == .authorized else { return }
            guard self != nil else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "quitx-hog-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

final class HogNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HogNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            RescueConsentController.shared.reopenFromNotification()
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
