import AppKit
import Foundation

enum SleepQuitTargets {
    static func select(apps: [AppInfo], config: QuitXConfig) -> [AppInfo] {
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let musicNames = config.musicApps.map { $0.lowercased() }
        return apps.filter { app in
            guard !app.isBackground else { return false }
            if let bid = app.bundleId,
               QuitXConstants.supportedBundleIdentifiers.contains(bid) { return false }
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

    typealias Quitter = @MainActor ([AppInfo], Bool) async -> Void
    typealias AppSource = @MainActor () async -> [AppInfo]

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private(set) var sleepStartDate: Date?

    var appSource: AppSource = {
        let vm = AppListViewModel.shared
        if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
            await vm.refresh()
        }
        return vm.apps
    }
    var quitter: Quitter = { apps, force in
        await AppListViewModel.shared.quitSilently(targets: apps, force: force)
    }

    init() {}

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

    static func forceMode(_ config: QuitXConfig) -> Bool {
        config.force == .force
    }

    static func shouldQuitOnWake(sleepStart: Date?, wakeDate: Date, config: QuitXConfig) -> Bool {
        guard config.quitOnSleep, let sleepStart else { return false }
        return SleepLockRange.overlaps(
            sleepStart: sleepStart,
            sleepEnd: wakeDate,
            startMinutes: config.sleepLockStartMinutes,
            endMinutes: config.sleepLockEndMinutes
        )
    }

    func handleSleep(now: Date = Date()) {
        sleepStartDate = ConfigStore.shared.config.quitOnSleep ? now : nil
    }

    func handleWake(wakeDate: Date = Date()) async {
        let sleepStart = sleepStartDate
        sleepStartDate = nil
        let config = ConfigStore.shared.config
        guard Self.shouldQuitOnWake(sleepStart: sleepStart, wakeDate: wakeDate, config: config) else { return }
        StatusItemController.shared?.closePopover()
        let targets = SleepQuitTargets.select(apps: await appSource(), config: config)
        guard !targets.isEmpty else { return }
        await quitter(targets, Self.forceMode(config))
    }
}
