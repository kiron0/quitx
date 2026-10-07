import AppKit
import Foundation

enum SleepQuitTargets {
    static func select(apps: [AppInfo], config: QuitXConfig) -> [AppInfo] {
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let musicNames = config.musicApps.map { $0.lowercased() }
        return apps.filter { app in
            guard !app.isBackground else { return false }
            if let bid = app.bundleId,
               QuitXIdentity.supportedBundleIdentifiers.contains(bid) { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.finder { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.trash { return false }
            let lowerBid = app.bundleId?.lowercased()
            let lowerName = app.name.lowercased()
            if let lowerBid, excluded.contains(lowerBid) { return false }
            if excluded.contains(lowerName) { return false }
            if config.neverQuitMusic && musicNames.contains(where: {
                lowerName.contains($0) || lowerBid?.contains($0) == true
            }) { return false }
            let ruleMinutes = PerAppQuitRule.storedMinutes(
                bundleId: app.bundleId,
                name: app.name,
                rules: config.perAppQuitRules
            )
            if ruleMinutes == PerAppQuitRule.neverMinutes { return false }
            return true
        }
    }
}

@MainActor
final class SleepService {
    static let shared = SleepService()

    private var sleepObserver: NSObjectProtocol?
    private var lockObserver: NSObjectProtocol?

    private init() {}

    func start() {
        stop()
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleTrigger(enabled: ConfigStore.shared.config.quitOnSleep)
            }
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleTrigger(enabled: ConfigStore.shared.config.quitOnScreenLock)
            }
        }
    }

    func stop() {
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }
        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
            self.lockObserver = nil
        }
    }

    private func handleTrigger(enabled: Bool) async {
        guard enabled else { return }
        let vm = AppListViewModel.shared
        if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
            await vm.refresh()
        }
        let targets = SleepQuitTargets.select(
            apps: vm.apps,
            config: ConfigStore.shared.config
        )
        await vm.quitSilently(targets: targets, force: false)
    }
}
