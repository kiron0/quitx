import Testing
import Foundation
import IOKit.ps
@testable import QuitX

@Suite("Productivity Features Tests")
@MainActor
struct ProductivityFeaturesTests {

    private func regularApp(
        name: String = "Slack",
        bundleId: String? = "com.tinyspeck.slackmacgap",
        pid: pid_t = 101,
        memoryBytes: UInt64 = 100 * 1024 * 1024,
        cpu: Double = 5.0,
        background: Bool = false
    ) -> AppInfo {
        AppInfo(
            name: name,
            bundleId: bundleId,
            pid: pid,
            pids: [pid],
            isBackground: background,
            memoryBytes: memoryBytes,
            cpuUsage: cpu
        )
    }

    private var baseConfig: QuitXConfig {
        var config = QuitXConfig.default
        config.exclude = ["photoshop"]
        config.neverQuitMusic = true
        config.musicApps = ["Spotify", "Music"]
        return config
    }

    // MARK: - HogTracker

    @Test("Hog requires sustained threshold breach")
    func testHogSustain() {
        var tracker = HogTracker()
        let now = Date()
        #expect(tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: now).isEmpty)
        let later = now.addingTimeInterval(299)
        #expect(tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: later).isEmpty)
        let due = now.addingTimeInterval(301)
        #expect(tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: due) == [101])
    }

    @Test("Hog timer resets below threshold and on disappearance")
    func testHogReset() {
        var tracker = HogTracker()
        let now = Date()
        _ = tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: now)
        _ = tracker.sustainedPids(cpuByPid: [101: 10], threshold: 80, sustainSeconds: 300, now: now.addingTimeInterval(400))
        let restarted = now.addingTimeInterval(500)
        #expect(tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: restarted).isEmpty)
        _ = tracker.sustainedPids(cpuByPid: [:], threshold: 80, sustainSeconds: 300, now: restarted)
        #expect(tracker.sustainedPids(cpuByPid: [101: 90], threshold: 80, sustainSeconds: 300, now: restarted).isEmpty)
    }

    // MARK: - RecentlyQuitStore

    @Test("Recent list dedups, prepends, and caps")
    func testRecentInsert() {
        let first = RecentlyQuitEntry(name: "Slack", bundleId: "com.slack", quitAt: Date())
        let list = RecentlyQuitStore.inserting([], entry: first)
        #expect(list == [first])

        let second = RecentlyQuitEntry(name: "Xcode", bundleId: "com.apple.dt.Xcode", quitAt: Date())
        let two = RecentlyQuitStore.inserting(list, entry: second)
        #expect(two.map(\.name) == ["Xcode", "Slack"])

        let slackAgain = RecentlyQuitEntry(name: "slack", bundleId: "COM.SLACK", quitAt: Date())
        let moved = RecentlyQuitStore.inserting(two, entry: slackAgain)
        #expect(moved.map(\.name) == ["slack", "Xcode"])
        #expect(moved.count == 2)

        var big: [RecentlyQuitEntry] = []
        for i in 0..<30 {
            big = RecentlyQuitStore.inserting(big, entry: RecentlyQuitEntry(name: "App\(i)", bundleId: "com.app.\(i)", quitAt: Date()))
        }
        #expect(big.count == RecentlyQuitStore.maxCount)
        #expect(big.first?.name == "App29")
    }

    // MARK: - SleepQuitTargets

    @Test("Sleep targets skip protected apps")
    func testSleepTargets() {
        let apps = [
            regularApp(),
            regularApp(name: "Photoshop", bundleId: "com.adobe.Photoshop", pid: 102),
            regularApp(name: "Spotify", bundleId: "com.spotify.client", pid: 103),
            regularApp(name: "Helper", bundleId: "com.x.helper", pid: 104, background: true),
            regularApp(name: "Finder", bundleId: "com.apple.finder", pid: 105),
            regularApp(name: "QuitX", bundleId: "io.coreify.quitx", pid: 106),
        ]
        let targets = SleepQuitTargets.select(apps: apps, config: baseConfig)
        #expect(targets.map(\.name) == ["Slack"])
    }

    // MARK: - MemoryPressureTargets

    @Test("Pressure targets need threshold bytes and allow rules")
    func testPressureTargets() {
        var config = baseConfig
        config.memoryPressureThresholdMB = 1024
        config.perAppQuitRules = ["com.never.app": 0]
        let apps = [
            regularApp(memoryBytes: 2 * 1024 * 1024 * 1024),
            regularApp(name: "Tiny", bundleId: "com.tiny.app", pid: 102, memoryBytes: 10 * 1024 * 1024),
            regularApp(name: "Forever", bundleId: "com.never.app", pid: 103, memoryBytes: 3 * 1024 * 1024 * 1024),
            regularApp(name: "Spotify", bundleId: "com.spotify.client", pid: 104, memoryBytes: 2 * 1024 * 1024 * 1024),
        ]
        let targets = MemoryPressureTargets.select(apps: apps, config: config)
        #expect(targets.map(\.name) == ["Slack"])
    }

    // MARK: - BatterySaver

    @Test("Battery detection parses power descriptions")
    func testBatteryDetection() {
        let battery = [[kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue as String]]
        let ac = [[kIOPSPowerSourceStateKey as String: "AC Power"]]
        #expect(BatterySaver.isOnBattery(descriptions: battery))
        #expect(!BatterySaver.isOnBattery(descriptions: ac))
        #expect(!BatterySaver.isOnBattery(descriptions: []))

        var config = QuitXConfig.default
        config.batterySaverEnabled = true
        #expect(BatterySaver.isSaverActive(config: config, descriptions: battery))
        #expect(!BatterySaver.isSaverActive(config: config, descriptions: ac))
        config.batterySaverEnabled = false
        #expect(!BatterySaver.isSaverActive(config: config, descriptions: battery))
    }

    @Test("Saver halves timeouts with floor and formats readout")
    func testSaverTimeoutAndReadout() {
        #expect(BatterySaver.effectiveTimeout(minutes: 60, saverActive: true) == 30)
        #expect(BatterySaver.effectiveTimeout(minutes: 1, saverActive: true) == 1)
        #expect(BatterySaver.effectiveTimeout(minutes: 60, saverActive: false) == 60)
        #expect(BatterySaver.effectiveTimeout(minutes: 0, saverActive: true) == 0)
        #expect(BatterySaver.menuBarText(totalCPU: 12.6, enabled: true) == "13%")
        #expect(BatterySaver.menuBarText(totalCPU: 12.6, enabled: false) == nil)
    }

    // MARK: - QuitTimerDue

    @Test("Due keys split past from future")
    func testTimerDue() {
        let now = Date()
        let timers = ["a": now.timeIntervalSince1970 - 10, "b": now.timeIntervalSince1970 + 600]
        #expect(QuitTimerDue.dueKeys(timers: timers, now: now) == ["a"])
        #expect(QuitTimerDue.pruneExpired(timers: timers, now: now).keys.sorted() == ["b"])
        #expect(QuitTimerDue.dueKeys(timers: [:], now: now).isEmpty)
    }

    // MARK: - Quit Others

    @Test("Quit Others keeps one app")
    func testOthersTargets() {
        let apps = [regularApp(), regularApp(name: "Xcode", bundleId: "com.apple.dt.Xcode", pid: 102)]
        let targets = AppListViewModel.othersTargets(keepingId: apps[0].id, apps: apps)
        #expect(targets.map(\.name) == ["Xcode"])
        #expect(AppListViewModel.othersTargets(keepingId: "missing", apps: apps).count == 2)
        #expect(AppListViewModel.othersTargets(keepingId: apps[0].id, apps: []).isEmpty)
    }
}
