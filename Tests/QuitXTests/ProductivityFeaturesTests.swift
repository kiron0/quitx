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

    @Test("Hog detects threshold breach immediately")
    func testHogImmediateBreach() {
        let tracker = HogTracker()
        #expect(tracker.hogPids(cpuByPid: [101: 70], threshold: 80).isEmpty)
        #expect(tracker.hogPids(cpuByPid: [101: 90], threshold: 80) == [101])
    }

    @Test("Hog resets when below threshold")
    func testHogReset() {
        let tracker = HogTracker()
        #expect(tracker.hogPids(cpuByPid: [101: 90], threshold: 80) == [101])
        #expect(tracker.hogPids(cpuByPid: [101: 10], threshold: 80).isEmpty)
        #expect(tracker.hogPids(cpuByPid: [:], threshold: 80).isEmpty)
    }

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

    private func windowedApp(
        name: String,
        bundleId: String?,
        pid: pid_t,
        windows: Int = 2
    ) -> AppInfo {
        AppInfo(
            name: name,
            bundleId: bundleId,
            pid: pid,
            pids: [pid],
            windowCount: windows
        )
    }

    @Test("Rescue quits inactive windows only, spares frontmost and self")
    func testRescueSparesActive() {
        var config = baseConfig
        config.perAppQuitRules = ["com.never.app": 0]
        let apps = [
            windowedApp(name: "Active", bundleId: "com.active.app", pid: 201),
            windowedApp(name: "Idle", bundleId: "com.idle.app", pid: 202),
            windowedApp(name: "Me", bundleId: "io.coreify.quitx", pid: 203),
            windowedApp(name: "Forever", bundleId: "com.never.app", pid: 204),
            windowedApp(name: "Finder", bundleId: "com.apple.finder", pid: 205),
            windowedApp(name: "Spotify", bundleId: "com.spotify.client", pid: 206),
            windowedApp(name: "Windowless", bundleId: "com.plain.app", pid: 207, windows: 0),
            AppInfo(name: "Daemon", bundleId: "com.daemon.app", pid: 208, pids: [208], isBackground: true),
        ]
        let targets = InactiveRescueTargets.select(
            apps: apps, config: config, frontmostPid: 201, ownPid: 999
        )
        #expect(targets.map(\.name) == ["Idle"])
    }

    @Test("Rescue ignores which app uses more, keeps every guard")
    func testRescueIgnoresUsageSize() {
        let config = QuitXConfig.default
        let apps = [
            AppInfo(name: "Huge", bundleId: "com.huge.app", pid: 301, pids: [301], windowCount: 3, memoryBytes: 8 * 1024 * 1024 * 1024, cpuUsage: 350),
            AppInfo(name: "Small", bundleId: "com.small.app", pid: 302, pids: [302], windowCount: 1, memoryBytes: 12 * 1024 * 1024, cpuUsage: 0.4),
        ]
        let targets = InactiveRescueTargets.select(
            apps: apps, config: config, frontmostPid: 900, ownPid: 999
        )
        #expect(targets.map(\.name) == ["Huge", "Small"])
    }

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
        let tenGB: UInt64 = 10 * 1024 * 1024 * 1024
        #expect(BatterySaver.menuBarText(cpu: 12.6, memoryUsedBytes: tenGB, enabled: true) == "CPU 13% · Memory 10.0 GB")
        #expect(BatterySaver.menuBarText(cpu: 12.6, memoryUsedBytes: tenGB, enabled: false) == nil)
        #expect(BatterySaver.percentText(7.4) == "7%")
        #expect(BatterySaver.compactMemoryText(bytes: tenGB) == "10.0G")
        #expect(BatterySaver.compactMemoryText(bytes: 512 * 1024 * 1024) == "512M")
    }

    @Test("Rescue gate blocks during 60s arm delay")
    func testHogGateArmDelay() {
        var gate = HogRescueGate()
        let start = Date()
        let early = gate.evaluate(cpu: 99, threshold: 80, armedAt: start, now: start.addingTimeInterval(30))
        #expect(!early)
        let justArmed = gate.evaluate(cpu: 99, threshold: 80, armedAt: start, now: start.addingTimeInterval(61))
        #expect(!justArmed)
        let neverArmed = gate.evaluate(cpu: 99, threshold: 80, armedAt: nil, now: start.addingTimeInterval(120))
        #expect(!neverArmed)
    }

    @Test("Rescue gate needs 15s sustained breach")
    func testHogGateSustain() {
        var gate = HogRescueGate()
        let armed = Date().addingTimeInterval(-120)
        let t0 = Date()
        let startBreach = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0)
        #expect(!startBreach)
        let midBreach = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(14))
        #expect(!midBreach)
        let sustained = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(15))
        #expect(sustained)
    }

    @Test("Rescue gate hysteresis keeps episode across small dip")
    func testHogGateHysteresis() {
        var gate = HogRescueGate()
        let armed = Date().addingTimeInterval(-120)
        let t0 = Date()
        _ = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0)
        let smallDip = gate.evaluate(cpu: 78, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(5))
        #expect(!smallDip)
        let resumed = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(15))
        #expect(resumed)
        let bigDrop = gate.evaluate(cpu: 70, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(20))
        #expect(!bigDrop)
        let freshBreach = gate.evaluate(cpu: 99, threshold: 80, armedAt: armed, now: t0.addingTimeInterval(21))
        #expect(!freshBreach)
    }

    @Test("System CPU and memory percent stay in range")
    func testSystemUsageRange() {
        _ = SystemUsage.cpuPercent()
        let cpu = SystemUsage.cpuPercent()
        #expect(cpu >= 0 && cpu <= 100)
        let memory = SystemUsage.memoryPercent()
        #expect(memory > 0 && memory <= 100)
    }

    @Test("Sleep targets respect per-app Never rule")
    func testSleepTargetsRespectNeverRule() {
        var config = baseConfig
        config.perAppQuitRules = ["com.tinyspeck.slackmacgap": 0]
        let apps = [regularApp()]
        let targets = SleepQuitTargets.select(apps: apps, config: config)
        #expect(targets.isEmpty)
    }

    @Test("Effective hog threshold clamps to 80...100")
    func testEffectiveHogThreshold() {
        var config = QuitXConfig.default
        config.hogCpuThreshold = 50
        #expect(config.effectiveHogCpuThreshold == 80)
        config.hogCpuThreshold = 200
        #expect(config.effectiveHogCpuThreshold == 100)
        config.hogCpuThreshold = 90
        #expect(config.effectiveHogCpuThreshold == 90)
    }

    @Test("Due keys split past from future")
    func testTimerDue() {
        let now = Date()
        let timers = ["a": now.timeIntervalSince1970 - 10, "b": now.timeIntervalSince1970 + 600]
        #expect(QuitTimerDue.dueKeys(timers: timers, now: now) == ["a"])
        #expect(QuitTimerDue.pruneExpired(timers: timers, now: now).keys.sorted() == ["b"])
        #expect(QuitTimerDue.dueKeys(timers: [:], now: now).isEmpty)
    }

    @Test("Resistant badge flags only the exact pid that resisted")
    func testResistantFlagExactPid() {
        let app = AppInfo(name: "Slow", bundleId: "com.example.slow", pid: 100)
        let key = PerAppQuitRule.ruleKey(bundleId: "com.example.slow", name: "Slow")
        let result = AppListViewModel.flagResistantApps([app], resistantPids: [key: 100])
        #expect(result.apps.first?.isUnresponsive == true)
        #expect(result.live[key] == 100)
    }

    @Test("Relaunched app with new pid is not flagged and entry pruned")
    func testResistantFlagRelaunchCleared() {
        let fresh = AppInfo(name: "Slow", bundleId: "com.example.slow", pid: 200)
        let key = PerAppQuitRule.ruleKey(bundleId: "com.example.slow", name: "Slow")
        let result = AppListViewModel.flagResistantApps([fresh], resistantPids: [key: 100])
        #expect(result.apps.first?.isUnresponsive == false)
        #expect(result.live.isEmpty)
    }

    @Test("Quit process gone from list prunes entry without flagging others")
    func testResistantFlagProcessGone() {
        let other = AppInfo(name: "Other", bundleId: "com.example.other", pid: 300)
        let key = PerAppQuitRule.ruleKey(bundleId: "com.example.slow", name: "Slow")
        let result = AppListViewModel.flagResistantApps([other], resistantPids: [key: 100])
        #expect(result.apps.first?.isUnresponsive == false)
        #expect(result.live.isEmpty)
    }

    @Test("Quit Others keeps one app")
    func testOthersTargets() {
        let apps = [regularApp(), regularApp(name: "Xcode", bundleId: "com.apple.dt.Xcode", pid: 102)]
        let targets = AppListViewModel.othersTargets(keepingId: apps[0].id, apps: apps)
        #expect(targets.map(\.name) == ["Xcode"])
        #expect(AppListViewModel.othersTargets(keepingId: "missing", apps: apps).count == 2)
        #expect(AppListViewModel.othersTargets(keepingId: apps[0].id, apps: []).isEmpty)
    }
}
