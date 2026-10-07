import AppKit
import Foundation

enum QuitTimerDue {
    static func dueKeys(timers: [String: Double], now: Date) -> [String] {
        let epoch = now.timeIntervalSince1970
        return timers.filter { $0.value <= epoch }.map(\.key).sorted()
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

        let vm = AppListViewModel.shared
        if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
            await vm.refresh()
        }
        let targets = vm.apps.filter { app in
            let key = PerAppQuitRule.ruleKey(bundleId: app.bundleId, name: app.name)
            return due.contains(key)
        }
        await vm.quitSilently(targets: targets, force: false)
    }
}
