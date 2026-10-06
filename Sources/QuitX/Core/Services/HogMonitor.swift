import AppKit
import Foundation
@preconcurrency import UserNotifications

struct HogTracker: Sendable {
    private var highSince: [pid_t: Date] = [:]

    mutating func sustainedPids(
        cpuByPid: [pid_t: Double],
        threshold: Double,
        sustainSeconds: Double,
        now: Date
    ) -> Set<pid_t> {
        var sustained = Set<pid_t>()
        for (pid, cpu) in cpuByPid {
            guard cpu >= threshold else {
                highSince.removeValue(forKey: pid)
                continue
            }
            let start = highSince[pid] ?? now
            highSince[pid] = start
            if now.timeIntervalSince(start) >= sustainSeconds {
                sustained.insert(pid)
            }
        }
        for pid in Set(highSince.keys).subtracting(cpuByPid.keys) {
            highSince.removeValue(forKey: pid)
        }
        return sustained
    }

    mutating func reset() {
        highSince.removeAll()
    }
}

@MainActor
final class HogMonitor {
    static let shared = HogMonitor()

    private var tracker = HogTracker()
    private var notifiedPids = Set<pid_t>()
    private var authRequested = false

    private init() {}

    func reset() {
        tracker.reset()
        notifiedPids.removeAll()
    }

    func noteLiveApps(
        _ apps: [AppInfo],
        threshold: Double,
        sustainMinutes: Int
    ) -> Set<pid_t> {
        var cpuByPid: [pid_t: Double] = [:]
        for app in apps {
            for pid in app.pids {
                cpuByPid[pid] = max(cpuByPid[pid, default: 0], app.cpuUsage)
            }
        }
        let sustained = tracker.sustainedPids(
            cpuByPid: cpuByPid,
            threshold: threshold,
            sustainSeconds: Double(max(1, sustainMinutes)) * 60,
            now: Date()
        )
        notifiedPids = notifiedPids.intersection(sustained)
        let fresh = sustained.subtracting(notifiedPids)
        if !fresh.isEmpty {
            notifyHogs(pids: fresh, apps: apps)
            notifiedPids.formUnion(fresh)
        }
        return sustained
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
            content.body = "\(count) app(s) are using sustained high CPU. Open QuitX to review."
        } else {
            content.body = "\(names.joined(separator: ", ")) \(names.count == 1 ? "is" : "are") using sustained high CPU. Open QuitX to review."
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
