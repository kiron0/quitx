import AppKit
import Foundation
import IOKit.pwr_mgt

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

enum SleepLockRange {
    static func active(now: Date, startMinutes: Int, endMinutes: Int, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return active(nowMinutes: hour * 60 + minute, startMinutes: startMinutes, endMinutes: endMinutes)
    }

    static func active(nowMinutes: Int, startMinutes: Int, endMinutes: Int) -> Bool {
        if startMinutes == endMinutes { return true }
        if startMinutes < endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        }
        return nowMinutes >= startMinutes || nowMinutes < endMinutes
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
        let config = ConfigStore.shared.config
        if !SleepLockRange.active(
            now: Date(),
            startMinutes: config.sleepLockStartMinutes,
            endMinutes: config.sleepLockEndMinutes
        ) {
            return
        }
        let vm = AppListViewModel.shared

        var assertionID = IOPMAssertionID(0)
        let assertionProps = [
            kIOPMAssertionTypeKey: kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionNameKey: "QuitX quitting apps on sleep or lock"
        ] as CFDictionary
        let assertOK = IOPMAssertionCreateWithProperties(assertionProps, &assertionID) == kIOReturnSuccess
        defer {
            if assertOK {
                IOPMAssertionRelease(assertionID)
            }
        }

        if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
            await vm.refresh()
        }
        let targets = SleepQuitTargets.select(apps: vm.apps, config: config)
        await vm.quitSilently(targets: targets, force: false)
    }
}
