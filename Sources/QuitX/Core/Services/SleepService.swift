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
               QuitXConstants.supportedBundleIdentifiers.contains(bid) { return false }
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

    static func overlaps(
        sleepStart: Date,
        sleepEnd: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard sleepStart <= sleepEnd else { return false }
        if startMinutes == endMinutes { return true }
        if sleepEnd.timeIntervalSince(sleepStart) >= 86400 { return true }

        if sleepStart == sleepEnd {
            return active(now: sleepStart, startMinutes: startMinutes, endMinutes: endMinutes, calendar: calendar)
        }

        let startOfDay = calendar.startOfDay(for: sleepStart)
        let durationMinutes = startMinutes < endMinutes
            ? (endMinutes - startMinutes)
            : (1440 - startMinutes + endMinutes)

        for dayOffset in -1...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let windowStart = calendar.date(byAdding: .minute, value: startMinutes, to: day),
                  let windowEnd = calendar.date(byAdding: .minute, value: durationMinutes, to: windowStart) else {
                continue
            }
            if max(sleepStart, windowStart) < min(sleepEnd, windowEnd) {
                return true
            }
        }
        return false
    }
}

@MainActor
final class SleepService {
    static let shared = SleepService()

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private(set) var sleepStartDate: Date?
    private(set) var didQuitOnCurrentSleep = false

    private init() {}

    func start() {
        stop()
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleSleep()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleWake()
            }
        }
    }

    func stop() {
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    func handleSleep(now: Date = Date()) {
        guard ConfigStore.shared.config.quitOnSleep else { return }
        sleepStartDate = now
        didQuitOnCurrentSleep = false

        let config = ConfigStore.shared.config
        if SleepLockRange.active(
            now: now,
            startMinutes: config.sleepLockStartMinutes,
            endMinutes: config.sleepLockEndMinutes
        ) {
            didQuitOnCurrentSleep = executeQuitBeforeSleep(config: config)
        }
    }

    func handleWake(wakeDate: Date = Date()) async {
        guard ConfigStore.shared.config.quitOnSleep else {
            sleepStartDate = nil
            didQuitOnCurrentSleep = false
            return
        }
        defer {
            sleepStartDate = nil
            didQuitOnCurrentSleep = false
        }

        guard !didQuitOnCurrentSleep, let sleepStart = sleepStartDate else { return }
        let config = ConfigStore.shared.config
        if SleepLockRange.overlaps(
            sleepStart: sleepStart,
            sleepEnd: wakeDate,
            startMinutes: config.sleepLockStartMinutes,
            endMinutes: config.sleepLockEndMinutes
        ) {
            await executeQuit(config: config)
        }
    }

    private func executeQuitBeforeSleep(config: QuitXConfig) -> Bool {
        StatusItemController.shared?.closePopover()

        var assertionID = IOPMAssertionID(0)
        let assertionProps = [
            kIOPMAssertionTypeKey: kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionNameKey: "QuitX quitting apps on sleep"
        ] as CFDictionary
        let assertOK = IOPMAssertionCreateWithProperties(assertionProps, &assertionID) == kIOReturnSuccess
        defer {
            if assertOK {
                IOPMAssertionRelease(assertionID)
            }
        }

        let ownPid = ProcessInfo.processInfo.processIdentifier
        let targets = SleepQuitTargets.select(
            apps: AppListViewModel.shared.apps,
            config: config
        )
        var pending: [pid_t] = []
        for app in targets {
            for pid in app.pids where pid > 0 && pid != ownPid {
                guard let running = NSRunningApplication(processIdentifier: pid) else { continue }
                if running.terminate() {
                    pending.append(pid)
                }
            }
        }
        guard !pending.isEmpty else { return true }

        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            let stillRunning = pending.filter { QuitService.processIsRunning($0) }
            if stillRunning.isEmpty { return true }
            pending = stillRunning
            usleep(50_000)
        }
        return pending.isEmpty
    }

    private func executeQuit(config: QuitXConfig) async {
        StatusItemController.shared?.closePopover()
        let vm = AppListViewModel.shared

        var assertionID = IOPMAssertionID(0)
        let assertionProps = [
            kIOPMAssertionTypeKey: kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionNameKey: "QuitX quitting apps on sleep"
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
