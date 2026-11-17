import Foundation
@preconcurrency import UserNotifications

@MainActor
final class QuickCleanAutoService {
    static let shared = QuickCleanAutoService()

    private let monitor: QuickCleanMonitor
    private var loopTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    private convenience init() {
        self.init(monitor: QuickCleanMonitor.shared)
    }

    init(monitor: QuickCleanMonitor) {
        self.monitor = monitor
    }

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluateNow()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        tickTask?.cancel()
        tickTask = nil
    }

    func evaluateNow() {
        let config = ConfigStore.shared.config
        guard config.quickCleanAutoEnabled, tickTask == nil else { return }
        tickTask = Task { [weak self] in
            await self?.tick(config: config)
            self?.tickTask = nil
        }
    }

    private func tick(config: QuitXConfig) async {
        let maxAge = BatterySaver.isLowPowerMode
            ? max(config.quickCleanBackgroundMaxAge, 3600)
            : config.quickCleanBackgroundMaxAge
        monitor.refreshIfStale(maxAge: maxAge)
        await monitor.waitForWork()
        guard !Task.isCancelled, ConfigStore.shared.config.quickCleanAutoEnabled else { return }
        let threshold = ConfigStore.shared.config.quickCleanAutoThresholdBytes
        monitor.autoCleanIfNeeded(thresholdBytes: threshold) { outcome in
            Self.postNotification(outcome)
        }
    }

    private static func postNotification(_ outcome: QuickCleanMonitor.Outcome) {
        guard outcome.removed > 0 || outcome.skipped > 0 else { return }
        let message = outcome.message
        Task {
            let center = UNUserNotificationCenter.current()
            var status = (await center.notificationSettings()).authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = (await center.notificationSettings()).authorizationStatus
            }
            guard status == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Quick Clean ran automatically"
            content.body = message
            let request = UNNotificationRequest(
                identifier: "quitx-quickclean-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
