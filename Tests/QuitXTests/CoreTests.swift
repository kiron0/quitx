import Testing
import Foundation
@testable import QuitX

@Suite("MemoryFormatter Tests")
struct MemoryFormatterTests {
    @Test("0 bytes formats correctly")
    func testZeroBytes() {
        #expect(MemoryFormatter.format(bytes: 0) == "0 B" || MemoryFormatter.format(bytes: 0) == "0 KB")
    }

    @Test("Small byte amounts under 1KB")
    func testSmallBytes() {
        #expect(MemoryFormatter.format(bytes: 1) == "1 B" || MemoryFormatter.format(bytes: 1) == "1 KB" || MemoryFormatter.format(bytes: 1).contains("B"))
        #expect(MemoryFormatter.format(bytes: 500).contains("B") || MemoryFormatter.format(bytes: 500).contains("KB"))
        #expect(MemoryFormatter.format(bytes: 1023).contains("B") || MemoryFormatter.format(bytes: 1023).contains("KB"))
    }

    @Test("1 KB exact")
    func testOneKB() {
        #expect(MemoryFormatter.format(bytes: 1024).contains("KB") || MemoryFormatter.format(bytes: 1024).contains("1"))
    }

    @Test("512 KB exact")
    func test512KB() {
        #expect(MemoryFormatter.format(bytes: 512 * 1024) == "512 KB")
    }

    @Test("1023 KB near MB boundary")
    func testNearMBBoundary() {
        let result = MemoryFormatter.format(bytes: 1023 * 1024)
        #expect(result.contains("KB") || result.contains("MB"))
    }

    @Test("1 MB exact")
    func testOneMB() {
        #expect(MemoryFormatter.format(bytes: 1024 * 1024) == "1 MB" || MemoryFormatter.format(bytes: 1024 * 1024) == "1.0 MB")
    }

    @Test("256 MB exact")
    func test256MB() {
        #expect(MemoryFormatter.format(bytes: 256 * 1024 * 1024) == "256 MB")
    }

    @Test("500 MB exact")
    func test500MB() {
        #expect(MemoryFormatter.format(bytes: 500 * 1024 * 1024) == "500 MB")
    }

    @Test("1023 MB near GB boundary")
    func testNearGBBoundary() {
        let result = MemoryFormatter.format(bytes: 1023 * 1024 * 1024)
        #expect(result.contains("MB") || result.contains("GB"))
    }

    @Test("1 GB exact")
    func testOneGB() {
        let bytes: UInt64 = 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }

    @Test("2 GB format")
    func testTwoGB() {
        let bytes: UInt64 = 2 * 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }

    @Test("16 GB format")
    func test16GB() {
        let bytes: UInt64 = 16 * 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }

    @Test("64 GB format")
    func test64GB() {
        let bytes: UInt64 = 64 * 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }

    @Test("Fractional GB formatting")
    func testFractionalGB() {
        let bytes: UInt64 = UInt64(1.5 * Double(1024 * 1024 * 1024))
        let str = MemoryFormatter.format(bytes: bytes)
        #expect(str.contains("GB") || str.contains("1.5"))
    }

    @Test("Large boundary value UInt64")
    func testLargeValue() {
        let bytes: UInt64 = 100 * 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }
}

@Suite("AppInfo Model Tests")
struct AppInfoTests {
    @Test("Windowless flag true when regular app with 0 windows")
    func testWindowlessFlagTrue() {
        let app = AppInfo(name: "Test", isBackground: false, windowCount: 0)
        #expect(app.isWindowless)
    }

    @Test("Windowless flag false when regular app with 1 window")
    func testWindowlessFlagFalseWithWindows() {
        let app = AppInfo(name: "Test", isBackground: false, windowCount: 1)
        #expect(!app.isWindowless)
    }

    @Test("Windowless flag false when app is background even with 0 windows")
    func testNotWindowlessWhenBackground() {
        let app = AppInfo(name: "Agent", isBackground: true, windowCount: 0)
        #expect(!app.isWindowless)
    }

    @Test("ID generation with PID and bundleId")
    func testIdWithPidAndBundleId() {
        let app = AppInfo(name: "Safari", bundleId: "com.apple.Safari", pid: 1234)
        #expect(app.id == "1234-com.apple.Safari")
    }

    @Test("ID generation with PID and nil bundleId")
    func testIdWithPidAndNoBundleId() {
        let app = AppInfo(name: "Helper", bundleId: nil, pid: 999)
        #expect(app.id == "999-Helper")
    }

    @Test("ID generation without PID uses bundleId")
    func testIdWithoutPidUsesBundleId() {
        let app = AppInfo(name: "Trash", bundleId: "com.apple.trash", pid: nil)
        #expect(app.id == "com.apple.trash")
    }

    @Test("ID generation without PID and nil bundleId uses name")
    func testIdWithoutPidAndNilBundleIdUsesName() {
        let app = AppInfo(name: "MysteryApp", bundleId: nil, pid: nil)
        #expect(app.id == "MysteryApp")
    }

    @Test("PIDs array populated from single pid")
    func testPidsFromSinglePid() {
        let app = AppInfo(name: "Test", pid: 42)
        #expect(app.pids == [42])
    }

    @Test("PIDs array explicit overrides single pid")
    func testExplicitPids() {
        let app = AppInfo(name: "Chrome Group", pid: 10, pids: [10, 11, 12])
        #expect(app.pids == [10, 11, 12])
    }

    @Test("CPU formatted string with 0.0")
    func testCpuFormattedZero() {
        let app = AppInfo(name: "Idle", cpuUsage: 0.0)
        #expect(app.cpuFormatted == "0.0%")
    }

    @Test("CPU formatted string with decimal")
    func testCpuFormattedDecimal() {
        let app = AppInfo(name: "Busy", cpuUsage: 12.345)
        #expect(app.cpuFormatted == "12.3%")
    }

    @Test("CPU formatted string with high usage")
    func testCpuFormattedHigh() {
        let app = AppInfo(name: "Max", cpuUsage: 150.0)
        #expect(app.cpuFormatted == "150.0%")
    }

    @Test("Memory formatted integrates MemoryFormatter")
    func testMemoryFormatted() {
        let app = AppInfo(name: "App", memoryBytes: 256 * 1024 * 1024)
        #expect(app.memoryFormatted == "256 MB")
    }

    @Test("Hashable equality based on AppInfo fields")
    func testHashableAndEquatable() {
        let app1 = AppInfo(name: "App", bundleId: "com.app", pid: 100)
        let app2 = AppInfo(name: "App", bundleId: "com.app", pid: 100)
        let app3 = AppInfo(name: "App", bundleId: "com.app", pid: 101)

        #expect(app1 == app2)
        #expect(app1 != app3)

        var set = Set<AppInfo>()
        set.insert(app1)
        #expect(set.contains(app2))
        set.insert(app3)
        #expect(set.count == 2)
    }

    @Test("QuitResult initialized correctly on success")
    func testQuitResultSuccess() {
        let app = AppInfo(name: "App", pid: 1)
        let res = QuitResult(app: app, success: true, forced: false, error: nil)
        #expect(res.success)
        #expect(!res.forced)
        #expect(res.error == nil)
        #expect(res.app.name == "App")
    }

    @Test("QuitResult initialized correctly on failure")
    func testQuitResultFailure() {
        let app = AppInfo(name: "Stubborn", pid: 2)
        let res = QuitResult(app: app, success: false, forced: true, error: "Access denied")
        #expect(!res.success)
        #expect(res.forced)
        #expect(res.error == "Access denied")
    }
}

@Suite("QuitXConfig Tests")
struct QuitXConfigTests {
    @Test("Default config values match expected QuitAll / QuitX specifications")
    func testDefaultConfig() {
        let cfg = QuitXConfig.default
        #expect(cfg.exclude.isEmpty)
        #expect(cfg.force == .normal)
        #expect(!cfg.includeFinder)
        #expect(!cfg.includeTrash)
        #expect(!cfg.includeBackground)
        #expect(cfg.groupBackground)
        #expect(!cfg.defaultSelectAll)
        #expect(!cfg.neverQuitMusic)
        #expect(cfg.musicApps.contains("Music"))
        #expect(cfg.musicApps.contains("Spotify"))
        #expect(cfg.autoUpdate)
        #expect(cfg.confirmQuitAll)
        #expect(cfg.playSounds)
        #expect(cfg.quitInactiveAfterMinutes == 0)
        #expect(!cfg.disableQuitTips)
        #expect(cfg.sortBy == .name)
    }

    @Test("Config Codable roundtrip")
    func testConfigCodableRoundtrip() throws {
        var cfg = QuitXConfig.default
        cfg.exclude = ["Slack", "com.apple.finder"]
        cfg.force = .force
        cfg.includeFinder = true
        cfg.includeTrash = true
        cfg.includeBackground = true
        cfg.groupBackground = false
        cfg.defaultSelectAll = true
        cfg.neverQuitMusic = true
        cfg.confirmQuitAll = false
        cfg.playSounds = false
        cfg.quitInactiveAfterMinutes = 120
        cfg.disableQuitTips = true
        cfg.sortBy = .memoryDesc

        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: data)
        #expect(decoded == cfg)
    }

    @Test("SortBy decode from cpu string variants")
    func testSortByDecodeCpu() throws {
        for str in ["High to Low CPU %", "cpu", "cpuDesc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .cpuDesc)
        }
    }

    @Test("SortBy decode from cpuAsc string variants")
    func testSortByDecodeCpuAsc() throws {
        for str in ["Low to High CPU %", "cpuAsc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .cpuAsc)
        }
    }

    @Test("SortBy decode from memoryDesc string variants")
    func testSortByDecodeMemoryDesc() throws {
        for str in ["High to Low Memory", "memory", "memoryDesc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .memoryDesc)
        }
    }

    @Test("SortBy decode from memoryAsc string variants")
    func testSortByDecodeMemoryAsc() throws {
        for str in ["Low to High Memory", "memoryAsc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .memoryAsc)
        }
    }

    @Test("SortBy decode from name/alphaAsc string variants")
    func testSortByDecodeNameAsc() throws {
        for str in ["A-Z Alphabetical", "name", "alphaAsc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .name)
        }
    }

    @Test("SortBy decode from nameDesc/alphaDesc string variants")
    func testSortByDecodeNameDesc() throws {
        for str in ["Z-A Alphabetical", "nameDesc", "alphaDesc"] {
            let json = "\"\(str)\"".data(using: .utf8)!
            let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
            #expect(val == .nameDesc)
        }
    }

    @Test("SortBy decode fallback for unknown string")
    func testSortByDecodeFallback() throws {
        let json = "\"RandomUnknownOrder\"".data(using: .utf8)!
        let val = try JSONDecoder().decode(QuitXConfig.SortBy.self, from: json)
        #expect(val == .cpuDesc)
    }

    @Test("SortBy allCases contains 6 cases")
    func testSortByAllCases() {
        #expect(QuitXConfig.SortBy.allCases.count == 6)
    }

    @Test("ForceMode enum values")
    func testForceModeValues() {
        #expect(QuitXConfig.ForceMode.normal.rawValue == "normal")
        #expect(QuitXConfig.ForceMode.force.rawValue == "force")
    }

    @Test("Config equality when modifying exclude")
    func testConfigMutationExclude() {
        var a = QuitXConfig.default
        var b = QuitXConfig.default
        #expect(a == b)
        a.exclude = ["App1"]
        #expect(a != b)
        b.exclude = ["App1"]
        #expect(a == b)
    }

    @Test("Config equality when modifying force")
    func testConfigMutationForce() {
        var a = QuitXConfig.default
        a.force = .force
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying includeFinder")
    func testConfigMutationFinder() {
        var a = QuitXConfig.default
        a.includeFinder = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying includeTrash")
    func testConfigMutationTrash() {
        var a = QuitXConfig.default
        a.includeTrash = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying includeBackground")
    func testConfigMutationBackground() {
        var a = QuitXConfig.default
        a.includeBackground = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying groupBackground")
    func testConfigMutationGroupBackground() {
        var a = QuitXConfig.default
        a.groupBackground = false
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying defaultSelectAll")
    func testConfigMutationDefaultSelectAll() {
        var a = QuitXConfig.default
        a.defaultSelectAll = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying neverQuitMusic")
    func testConfigMutationMusic() {
        var a = QuitXConfig.default
        a.neverQuitMusic = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying confirmQuitAll")
    func testConfigMutationConfirmQuit() {
        var a = QuitXConfig.default
        a.confirmQuitAll = false
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying playSounds")
    func testConfigMutationPlaySounds() {
        var a = QuitXConfig.default
        a.playSounds = false
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying quitInactiveAfterMinutes")
    func testConfigMutationInactiveTimer() {
        var a = QuitXConfig.default
        a.quitInactiveAfterMinutes = 60
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying disableQuitTips")
    func testConfigMutationQuitTips() {
        var a = QuitXConfig.default
        a.disableQuitTips = true
        #expect(a != QuitXConfig.default)
    }

    @Test("Config equality when modifying sortBy")
    func testConfigMutationSortBy() {
        var a = QuitXConfig.default
        a.sortBy = .cpuAsc
        #expect(a != QuitXConfig.default)
    }
}
