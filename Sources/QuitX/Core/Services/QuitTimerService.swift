import AppKit
import Foundation

/// Persistent per-app quit timers.
///
/// Timers survive app restarts: fire dates are stored in config as Unix
/// timestamps. Expired entries are dropped on launch. When a timer fires,
/// the matching running app is asked to quit gracefully (never forced).
enum QuitTimerDue {
    /// Keys whose fire date passed as of `now`.
    static func dueKeys(timers: [String: Double], now: Date) -> [String] {
        let epoch = now.timeIntervalSince1970
        return timers.filter { $0.value <= epoch }.map(\.key).sorted()
    }

    /// Drops expired entries, returning the timers still in the future.
    static func pruneExpired(timers: [String: Double], now: Date) -> [String: Double] {
        let epoch = now.timeIntervalSince1970
        return timers.filter { $0.value > epoch }
    }
}

@MainActor
final class QuitTimerService {
    static let shared = QuitTimerService()

    private var timer: Timer?

    private init() {}

    func start() {
        pruneAndPersist()
        ensureTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Remaining whole minutes for an app rule key, or `nil` when no timer.
    func remainingMinutes(identifier: String) -> Int? {
        let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let fireDate = ConfigStore.shared.config.quitTimers[key] else { return nil }
        let remaining = Int(ceil((fireDate - Date().timeIntervalSince1970) / 60))
        return max(0, remaining)
    }

    func setTimer(identifier: String, minutes: Int) {
        let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, minutes > 0 else { return }
        var timers = ConfigStore.shared.config.quitTimers
        timers[key] = Date().timeIntervalSince1970 + Double(minutes) * 60
        ConfigStore.shared.config.quitTimers = timers
        ConfigStore.shared.save()
        ensureTimer()
    }

    func cancelTimer(identifier: String) {
        let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, ConfigStore.shared.config.quitTimers[key] != nil else { return }
        var timers = ConfigStore.shared.config.quitTimers
        timers.removeValue(forKey: key)
        ConfigStore.shared.config.quitTimers = timers
        ConfigStore.shared.save()
        ensureTimer()
    }

    private func pruneAndPersist() {
        let timers = ConfigStore.shared.config.quitTimers
        let pruned = QuitTimerDue.pruneExpired(timers: timers, now: Date())
        if pruned != timers {
            ConfigStore.shared.config.quitTimers = pruned
            ConfigStore.shared.save()
        }
    }

    private func ensureTimer() {
        let hasTimers = !ConfigStore.shared.config.quitTimers.isEmpty
        if hasTimers, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.fireDueTimers()
                }
            }
        } else if !hasTimers {
            timer?.invalidate()
            timer = nil
        }
    }

    private func fireDueTimers() async {
        let timers = ConfigStore.shared.config.quitTimers
        let due = QuitTimerDue.dueKeys(timers: timers, now: Date())
        guard !due.isEmpty else {
            ensureTimer()
            return
        }
        var remaining = timers
        for key in due { remaining.removeValue(forKey: key) }
        ConfigStore.shared.config.quitTimers = remaining
        ConfigStore.shared.save()
        ensureTimer()

        let running = NSWorkspace.shared.runningApplications
        var appsToQuit: [NSRunningApplication] = []
        for key in due {
            if let match = running.first(where: {
                $0.activationPolicy == .regular &&
                    PerAppQuitRule.ruleKey(bundleId: $0.bundleIdentifier, name: $0.localizedName ?? "") == key
            }) {
                appsToQuit.append(match)
            }
        }
        for app in appsToQuit {
            app.terminate()
        }
    }
}
