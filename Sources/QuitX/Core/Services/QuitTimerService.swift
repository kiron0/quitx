import AppKit
import Foundation

enum QuitTimerDue {
    static func dueKeys(timers: [String: Double], now: Date) -> [String] {
        let epoch = now.timeIntervalSince1970
        return timers.filter { $0.value <= epoch }.map(\.key).sorted()
    }

    static func nextDelay(timers: [String: Double], now: Date, retryAfter: TimeInterval? = nil) -> TimeInterval? {
        guard let earliest = timers.values.filter(\.isFinite).min() else { return nil }
        let untilDue = earliest - now.timeIntervalSince1970
        return min(3600, max(1, retryAfter ?? untilDue))
    }

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

    private func ensureTimer(retryAfter: TimeInterval? = nil) {
        timer?.invalidate()
        timer = nil
        guard let delay = QuitTimerDue.nextDelay(
            timers: ConfigStore.shared.config.quitTimers,
            now: Date(),
            retryAfter: retryAfter
        ) else { return }
        let newTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.fireDueTimers()
            }
        }
        newTimer.tolerance = min(5, delay * 0.05)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func fireDueTimers() async {
        let timers = ConfigStore.shared.config.quitTimers
        let due = QuitTimerDue.dueKeys(timers: timers, now: Date())
        guard !due.isEmpty else {
            ensureTimer()
            return
        }

        let vm = AppListViewModel.shared
        guard !vm.hasPendingOperations else {
            ensureTimer(retryAfter: 5)
            return
        }
        await vm.refresh()
        let dueSet = Set(due)
        let targets = vm.apps.filter { dueSet.contains(PerAppQuitRule.ruleKey(bundleId: $0.bundleId, name: $0.name)) }

        var remaining = ConfigStore.shared.config.quitTimers
        for key in due { remaining.removeValue(forKey: key) }
        ConfigStore.shared.config.quitTimers = remaining
        ConfigStore.shared.save()
        ensureTimer()

        await vm.quitSilently(targets: targets, force: ConfigStore.shared.config.prefersForceQuit)
    }
}
