import AppKit
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

@MainActor
final class HogMonitor {
    static let shared = HogMonitor()

    private var tracker = HogTracker()
    private var notifiedPids = Set<pid_t>()
    private var authRequested = false
    private var backgroundTask: Task<Void, Never>?

    private init() {}

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
        guard config.hogAlertEnabled else { return }
        let usages = AppListService.fetchCpuUsages()
        var cpuByPid: [pid_t: Double] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            cpuByPid[app.processIdentifier] = usages[app.processIdentifier, default: 0]
        }
        let hogs = noteCpuSample(
            cpuByPid: cpuByPid,
            threshold: max(5, config.hogCpuThreshold),
            apps: []
        )
        guard !hogs.isEmpty else { return }
        await AppListViewModel.shared.runBackgroundHogRescue()
    }

    func reset() {
        tracker.reset()
        notifiedPids.removeAll()
    }

    func noteLiveApps(
        _ apps: [AppInfo],
        threshold: Double
    ) -> Set<pid_t> {
        var cpuByPid: [pid_t: Double] = [:]
        for app in apps {
            for pid in app.pids {
                cpuByPid[pid] = max(cpuByPid[pid, default: 0], app.cpuUsage)
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
        notifiedPids = notifiedPids.intersection(hogs)
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
        Task { [weak self] in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                if settings.authorizationStatus == .notDetermined {
                    _ = try? await center.requestAuthorization(options: [.alert, .sound])
                }
                return
            }
            self?.postHogNotification(names: Array(names), count: pids.count)
        }
    }

    private func postHogNotification(names: [String], count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "High CPU usage"
        if names.isEmpty {
            content.body = "\(count) app(s) exceeded CPU limit. Open QuitX to review."
        } else {
            content.body = "\(names.joined(separator: ", ")) \(names.count == 1 ? "is" : "are") over CPU limit. Open QuitX to review."
        }
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "quitx-hog-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
            StatusItemController.shared?.showPopover()
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
