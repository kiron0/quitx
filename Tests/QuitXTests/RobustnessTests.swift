import Testing
import Foundation
import Darwin
@testable import QuitX

@Suite("Robustness and Break Tests")
@MainActor
struct RobustnessTests {

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test("Config decode never throws when any key has the wrong type")
    func configFieldTypeFuzz() throws {
        let encoded = try JSONEncoder().encode(QuitXConfig.default)
        let base = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let junk: [Any] = ["x", [1, 2], NSNull(), 1e300, -1, ["k": "v"], true]
        for key in base.keys {
            for value in junk {
                var mutated = base
                mutated[key] = value
                let data = try JSONSerialization.data(withJSONObject: mutated)
                let decoded = try JSONDecoder().decode(QuitXConfig.self, from: data)
                #expect(decoded.sleepLockStartMinutes >= 0 && decoded.sleepLockStartMinutes <= 1439)
                #expect(decoded.effectiveHogCpuThreshold >= 80 && decoded.effectiveHogCpuThreshold <= 100)
            }
        }
        _ = try JSONDecoder().decode(QuitXConfig.self, from: Data("{}".utf8))
    }

    @Test("Random procargs buffers never crash the parser")
    func procargsFuzz() {
        var rng = SeededGenerator(state: 42)
        for _ in 0..<2_000 {
            let count = Int.random(in: 0...96, using: &rng)
            var bytes = (0..<count).map { _ in UInt8.random(in: 0...255, using: &rng) }
            if bytes.count >= 4, Bool.random(using: &rng) {
                bytes[0] = UInt8.random(in: 0...6, using: &rng)
                bytes[1] = 0; bytes[2] = 0; bytes[3] = 0
            }
            if let parsed = ProcessArguments.parse(procargs: bytes) {
                #expect(!parsed.isEmpty)
                #expect(parsed.count <= 4096)
            }
        }
    }

    @Test("Window grouping and titles survive unicode, separators and huge lists")
    func windowGroupingFuzz() {
        let names = ["Work", "Work - Team", "😀 Personal", "Ünïcödé", "a"]
        var titles: [String] = []
        for index in 0..<500 {
            let name = names[index % names.count]
            titles.append(index % 7 == 0 ? "Untitled" : "Page \(index) - \(name)")
        }
        let groups = WindowGrouping.groups(titles: titles, profileNames: names) ?? []
        let covered = groups.flatMap(\.indices).sorted()
        #expect(covered == Array(0..<titles.count))
        #expect(Set(covered).count == covered.count)
        for title in titles + ["", " ", "\u{200B}", String(repeating: "é", count: 500)] {
            let shown = WindowGrouping.displayTitle(title, profile: "Work", maxLength: 40)
            #expect(!shown.isEmpty)
            #expect(shown.count <= 40)
        }
    }

    @Test("Hundreds of identical instances still get unique display names")
    func manyInstancesUnique() {
        let apps = (1...300).map { AppInfo(name: "Code", bundleId: "com.microsoft.VSCode", pid: pid_t($0)) }
        let labeled = AppInstanceLabel.assign(apps) { $0 % 2 == 0 ? "Same" : nil }
        #expect(Set(labeled.map(\.displayName)).count == apps.count)
        #expect(Set(labeled.map(\.id)).count == apps.count)
    }

    @Test("Version comparison is antisymmetric and tolerates garbage")
    func versionGarbage() {
        let samples = ["", "v", "abc", "1..2", "1.2.3-beta", "1.2.3 (45)", "99999999999999999999.1", "١.٢", "½", "1.0.0.0.0.1", " v2 "]
        for lhs in samples {
            for rhs in samples {
                let forward = VersionComparator.compare(lhs, rhs)
                let backward = VersionComparator.compare(rhs, lhs)
                #expect(forward == -backward)
            }
            #expect(VersionComparator.compare(lhs, lhs) == 0)
        }
        #expect(VersionComparator.isGreaterThan("1.0.0.0.0.1", "1"))
    }

    @Test("Formatters handle extreme values")
    func formatterExtremes() {
        #expect(MemoryFormatter.format(bytes: .max).hasSuffix("GB"))
        #expect(MemoryFormatter.format(bytes: 0) == "0 KB")
        #expect(BatterySaver.compactMemoryText(bytes: .max, unit: .percentage, totalBytes: 0) == "0%")
        #expect(BatterySaver.compactMemoryText(bytes: .max, unit: .gb).hasSuffix("G"))
        #expect(BatterySaver.effectiveTimeout(minutes: 1, saverActive: true) == 1)
        #expect(BatterySaver.effectiveTimeout(minutes: -5, saverActive: true) == -5)
    }

    @Test("Sorting tolerates NaN and infinite usage without losing rows")
    func sortingWithNonFiniteValues() {
        let apps = [
            AppInfo(name: "B", pid: 2, cpuUsage: .nan),
            AppInfo(name: "A", pid: 1, cpuUsage: .infinity),
            AppInfo(name: "C", pid: 3, cpuUsage: -.infinity),
            AppInfo(name: "D", pid: 4, memoryBytes: .max, cpuUsage: 1),
            AppInfo(name: "D", pid: 5, cpuUsage: 1)
        ]
        for order in QuitXConfig.SortBy.allCases {
            let sorted = AppListService.sortApps(apps, sortBy: order)
            #expect(Set(sorted.map(\.id)) == Set(apps.map(\.id)))
        }
    }

    @Test("Rule keys and lookups ignore blank identifiers")
    func blankRuleKeys() {
        #expect(PerAppQuitRule.ruleKey(bundleId: "", name: " Safari ") == "safari")
        #expect(PerAppQuitRule.storedMinutes(bundleId: "   ", name: "Safari", rules: ["safari": 15]) == 15)
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: nil, name: "", rules: [:], globalMinutes: 7) == 7)
    }

    @Test("Quit In timer keys isolate instances and keep legacy plain keys")
    func timerKeys() {
        let work = AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 1, instanceLabel: "Work")
        let home = AppInfo(name: "Chrome", bundleId: "com.google.Chrome", pid: 2, instanceLabel: "Home")
        let single = AppInfo(name: "Notes", bundleId: "com.apple.Notes", pid: 3)
        let workKey = QuitTimerDue.timerKey(bundleId: work.bundleId, name: work.name, instanceLabel: work.instanceLabel)
        #expect(workKey == "com.google.chrome#work")
        #expect(QuitTimerDue.isDue(app: work, dueKeys: [workKey]))
        #expect(!QuitTimerDue.isDue(app: home, dueKeys: [workKey]))
        #expect(QuitTimerDue.isDue(app: home, dueKeys: ["com.google.chrome"]))
        #expect(QuitTimerDue.isDue(app: single, dueKeys: ["com.apple.notes"]))
        #expect(!QuitTimerDue.isDue(app: single, dueKeys: ["com.apple.notes#x"]))
        #expect(QuitTimerDue.timerKey(bundleId: nil, name: "Tool", instanceLabel: "") == "tool")
    }

    @Test("Timer delay targets the earliest deadline within safe bounds")
    func timerDelays() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(QuitTimerDue.nextDelay(timers: [:], now: now) == nil)
        #expect(QuitTimerDue.nextDelay(timers: ["a": 1_000_090, "b": 1_000_030], now: now) == 30)
        #expect(QuitTimerDue.nextDelay(timers: ["a": 10], now: now) == 1)
        #expect(QuitTimerDue.nextDelay(timers: ["a": 9e15], now: now) == 3600)
        #expect(QuitTimerDue.nextDelay(timers: ["a": .infinity], now: now) == nil)
        #expect(QuitTimerDue.nextDelay(timers: ["a": 1_000_090], now: now, retryAfter: 5) == 5)
        #expect(QuitTimerDue.nextDelay(timers: ["a": 1_000_090], now: now, retryAfter: -3) == 1)
    }

    @Test("Rescue gate never fires when the clock runs backwards")
    func rescueGateClockSkew() {
        var gate = HogRescueGate()
        let armed = Date(timeIntervalSince1970: 10_000)
        var now = armed.addingTimeInterval(20)
        let fired1 = gate.evaluate(cpu: 100, threshold: 90, armedAt: armed, now: now)
        #expect(!fired1)
        now = armed.addingTimeInterval(-500)
        let fired2 = gate.evaluate(cpu: 100, threshold: 90, armedAt: armed, now: now)
        #expect(!fired2)
        now = armed.addingTimeInterval(19)
        let fired3 = gate.evaluate(cpu: 100, threshold: 90, armedAt: armed, now: now)
        #expect(!fired3)
    }

    @Test("Exclusion store normalizes whitespace, case and duplicates")
    func exclusionNormalization() {
        let store = ConfigStore.shared
        let original = store.config
        defer {
            store.config = original
            store.flush()
        }
        store.removeAllExcludedApps()
        let added = store.addExcludedApps(["  com.Example.App ", "com.example.app", "", "   ", "Other"])
        #expect(added == 2)
        #expect(store.config.exclude == ["com.Example.App", "Other"])
        store.removeExcludedApp("COM.EXAMPLE.APP")
        #expect(store.config.exclude == ["Other"])
        #expect(store.addExcludedApps(["com.example.app"]) == 1)
    }

    @Test("CPU sampler survives concurrent readers and start/stop churn")
    func cpuSamplerConcurrency() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<32 {
                group.addTask {
                    for _ in 0..<50 {
                        if index % 8 == 0 { CpuUsageSampler.start() }
                        _ = CpuUsageSampler.usages()
                    }
                }
            }
        }
        CpuUsageSampler.stop()
        CpuUsageSampler.start()
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        let usages = CpuUsageSampler.usages()
        for value in usages.values {
            #expect(value.isFinite && value >= 0)
        }
    }

    @Test("Live stats drop dead PIDs and never invent rows")
    func liveStatsDeadPids() async {
        let dead = AppInfo(name: "Ghost", bundleId: "x.ghost", pid: 999_999, instanceLabel: "Work")
        let alive = AppInfo(name: "Self", bundleId: "x.self", pid: ProcessInfo.processInfo.processIdentifier)
        let trash = AppInfo(name: "Trash", bundleId: QuitXConstants.SystemBundleIds.trash, pid: nil, pids: [])
        let updated = await AppListService.shared.fetchLiveStats(currentApps: [dead, alive, trash], config: .default)
        #expect(Set(updated.map(\.name)) == ["Self", "Trash"])
    }
}
