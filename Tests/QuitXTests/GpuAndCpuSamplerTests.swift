import Testing
import Foundation
@testable import QuitX

@Suite("GPU and CPU Sampler Tests")
struct GpuAndCpuSamplerTests {
    @Test("GPU snapshot stays in range")
    func gpuSnapshotIsValid() {
        let snapshot = GpuUsageService.snapshot()
        #expect(snapshot.deviceUtilization >= 0)
        #expect(snapshot.deviceUtilization <= 100)
        #expect(snapshot.rendererUtilization >= 0)
        #expect(snapshot.rendererUtilization <= 100)
        #expect(snapshot.tilerUtilization >= 0)
        #expect(snapshot.tilerUtilization <= 100)
    }

    @Test("GPU snapshot is cached inside the sampling interval")
    func gpuSnapshotIsCached() {
        let first = GpuUsageService.snapshot()
        let second = GpuUsageService.snapshot()
        #expect(first == second)
    }

    @Test("GPU memory usage is not absurd")
    func gpuMemoryIsSane() {
        let snapshot = GpuUsageService.snapshot()
        #expect(snapshot.memoryUsedBytes < 64 * 1_073_741_824)
    }

    @Test("CPU sampler produces a finite usage for this process")
    func cpuSamplerReportsSelf() async throws {
        CpuUsageSampler.start()
        try await Task.sleep(nanoseconds: 2_500_000_000)
        let usages = CpuUsageSampler.usages()
        let selfPid = ProcessInfo.processInfo.processIdentifier
        guard let value = usages[selfPid] else { return }
        #expect(value >= 0)
        #expect(value.isFinite)
    }

    @Test("Menu bar master gate requires both the switch and a stat")
    func menuBarStatsGate() {
        var cfg = QuitXConfig.default
        cfg.showMenuBarStats = false
        cfg.menuBarShowCpu = true
        #expect(cfg.menuBarStatsEnabled == false)

        cfg.showMenuBarStats = true
        #expect(cfg.menuBarStatsEnabled == true)

        cfg.menuBarShowCpu = false
        cfg.menuBarShowMemory = false
        cfg.menuBarShowGpu = false
        cfg.batteryMenuBarEnabled = false
        #expect(cfg.menuBarStatsEnabled == false)
    }

    @Test("Legacy menu bar config migrates to the per-stat flags")
    func legacyConfigMigrates() throws {
        let legacy = """
        {"exclude":[],"force":"normal","includeFinder":false,"includeTrash":false,
        "includeBackground":false,"groupBackground":true,"defaultSelectAll":true,
        "neverQuitMusic":false,"musicApps":[],"autoUpdate":true,"confirmQuitAll":true,
        "confirmIndividualAction":false,"playSounds":true,"quitInactiveAfterMinutes":0,
        "disableQuitTips":false,"sortBy":"name","perAppQuitRules":{},"quitOnSleep":false,
        "quitOnScreenLock":false,"sleepLockStartMinutes":0,"sleepLockEndMinutes":360,
        "sleepLockUse24Hour":true,"showMenuBarStats":true,"batteryMenuBarEnabled":false,
        "menuBarStatStyle":"Icon","menuBarMemoryUnit":"GB","hogAlertEnabled":false,
        "hogCpuThreshold":80,"memoryPressureQuitEnabled":false,
        "memoryPressureThresholdMB":1024,"batterySaverEnabled":false,"quitTimers":{},
        "liquidGlassEnabled":true}
        """
        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: Data(legacy.utf8))
        #expect(decoded.menuBarShowCpu == true)
        #expect(decoded.menuBarShowMemory == true)
        #expect(decoded.menuBarShowGpu == true)
        #expect(decoded.batteryMenuBarEnabled == false)
        #expect(decoded.menuBarStatsEnabled == true)
    }

    @Test("Malformed per-app rule entries do not wipe the whole map")
    func malformedRuleEntriesAreDroppedIndividually() throws {
        let json = """
        {"exclude":[],"force":"normal","includeFinder":false,"includeTrash":false,
        "includeBackground":false,"groupBackground":true,"defaultSelectAll":true,
        "neverQuitMusic":false,"musicApps":[],"autoUpdate":true,"confirmQuitAll":true,
        "confirmIndividualAction":false,"playSounds":true,"quitInactiveAfterMinutes":0,
        "disableQuitTips":false,"sortBy":"name",
        "perAppQuitRules":{"com.good.app":120,"com.bad.app":"nonsense"},
        "quitOnSleep":false,"quitOnScreenLock":false,"sleepLockStartMinutes":0,
        "sleepLockEndMinutes":360,"sleepLockUse24Hour":true,"showMenuBarStats":false,
        "batteryMenuBarEnabled":false,"menuBarStatStyle":"Icon","menuBarMemoryUnit":"GB",
        "hogAlertEnabled":false,"hogCpuThreshold":80,"memoryPressureQuitEnabled":false,
        "memoryPressureThresholdMB":1024,"batterySaverEnabled":false,"quitTimers":{},
        "liquidGlassEnabled":true}
        """
        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: Data(json.utf8))
        #expect(decoded.perAppQuitRules["com.good.app"] == 120)
        #expect(decoded.perAppQuitRules["com.bad.app"] == nil)
        #expect(decoded.perAppQuitRules.count == 1)
    }
}
