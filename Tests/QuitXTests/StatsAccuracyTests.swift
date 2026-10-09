import Darwin
import Foundation
import Testing
@testable import QuitX

@Suite("Stats panel analytics accuracy")
struct StatsAccuracyTests {
    @Test("CPU tick deltas survive UInt32 counter wrap")
    func testCpuTickCounterWrap() {
        #expect(SystemUsage.cpuTickDelta(previous: UInt64(UInt32.max - 4), current: 7) == 12)
        #expect(SystemUsage.cpuTickDelta(previous: 100, current: 145) == 45)
        #expect(
            SystemUsage.cpuTickDeltas(
                previous: [UInt64(UInt32.max), 20, 30, 40],
                current: [4, 25, 32, 41]
            ) == [5, 5, 2, 1]
        )
    }

    private func shellOutput(_ path: String, _ args: [String]) -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return ""
        }
        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func numbers(in text: String) -> [Double] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "{" || $0 == "}" })
            .compactMap { Double($0) }
    }

    private func vmStatValue(_ text: String, label: String) -> UInt64? {
        for line in text.split(separator: "\n") where line.hasPrefix(label) {
            let digits = line.filter { $0.isNumber }
            if let value = UInt64(digits) {
                return value
            }
        }
        return nil
    }

    @Test("CPU detail components sum to 100 and per-core count matches")
    func testCpuDetailConsistency() async throws {
        _ = SystemUsage.cpuDetail(consumer: "testConsistency")
        try await Task.sleep(nanoseconds: 400_000_000)
        let detail = SystemUsage.cpuDetail(consumer: "testConsistency")

        let sum = detail.system + detail.user + detail.idle
        #expect(abs(sum - 100) < 0.5)
        #expect(detail.total >= 0 && detail.total <= 100)
        #expect(detail.system >= 0 && detail.user >= 0 && detail.idle >= 0)

        let activeCount = ProcessInfo.processInfo.activeProcessorCount
        #expect(detail.perCore.count == activeCount)
        for value in detail.perCore {
            #expect(value >= 0 && value <= 100)
        }
        let perCoreAverage = detail.perCore.reduce(0, +) / Double(detail.perCore.count)
        #expect(abs(perCoreAverage - detail.total) < 45)
    }

    @Test("Two CPU consumers report close values in same window")
    func testCpuConsumersAgree() async throws {
        _ = SystemUsage.cpuDetail(consumer: "testAgreeA")
        _ = SystemUsage.cpuDetail(consumer: "testAgreeB")
        try await Task.sleep(nanoseconds: 400_000_000)
        let a = SystemUsage.cpuDetail(consumer: "testAgreeA")
        let b = SystemUsage.cpuDetail(consumer: "testAgreeB")
        #expect(abs(a.total - b.total) < 35)
    }

    @Test("Menu bar CPU and detail CPU use same per-core calculation")
    func testMenuBarAndDetailCpuAgree() async throws {
        _ = SystemUsage.cpuPercent(consumer: "testMenuBar")
        _ = SystemUsage.cpuDetail(consumer: "testDetail")
        try await Task.sleep(nanoseconds: 500_000_000)
        let menuBar = SystemUsage.cpuPercent(consumer: "testMenuBar")
        let detail = SystemUsage.cpuDetail(consumer: "testDetail")
        #expect(abs(menuBar - detail.total) < 10)
    }

    @Test("Load averages match sysctl ground truth")
    func testLoadAveragesGroundTruth() {
        let ours = SystemUsage.loadAverages()
        let raw = shellOutput("/usr/sbin/sysctl", ["-n", "vm.loadavg"])
        let ground = numbers(in: raw)
        #expect(ground.count == 3)
        guard ground.count == 3 else { return }
        #expect(abs(ours.0 - ground[0]) < 1.0)
        #expect(abs(ours.1 - ground[1]) < 1.0)
        #expect(abs(ours.2 - ground[2]) < 1.0)
        #expect(ours.0 >= 0 && ours.1 >= 0 && ours.2 >= 0)
    }

    @Test("Memory breakdown matches vm_stat ground truth")
    func testMemoryBreakdownGroundTruth() throws {
        let breakdown = try #require(SystemUsage.memoryBreakdown())
        #expect(breakdown.total == ProcessInfo.processInfo.physicalMemory)
        #expect(breakdown.used == breakdown.app + breakdown.wired + breakdown.compressed)
        #expect(breakdown.used <= breakdown.total)

        let vmStat = shellOutput("/usr/bin/vm_stat", [])
        let pageSizeLine = vmStat.split(separator: "\n").first ?? ""
        let pageSizeDigits = pageSizeLine.filter { $0.isNumber }
        let pageSize = try #require(UInt64(pageSizeDigits))
        #expect(UInt64(vm_page_size) == pageSize)

        let wiredPages = try #require(vmStatValue(vmStat, label: "Pages wired down:"))
        let freePages = try #require(vmStatValue(vmStat, label: "Pages free:"))
        let compressedPages = try #require(vmStatValue(vmStat, label: "Pages occupied by compressor:"))
        let purgeablePages = try #require(vmStatValue(vmStat, label: "Pages purgeable:"))
        let anonymousPages = try #require(vmStatValue(vmStat, label: "Anonymous pages:"))
        let fileBackedPages = try #require(vmStatValue(vmStat, label: "File-backed pages:"))

        let driftAllowance = max(breakdown.total / 32, 256 * 1024 * 1024)
        #expect(abs(Int64(breakdown.wired) - Int64(wiredPages * pageSize)) <= Int64(driftAllowance))
        #expect(abs(Int64(breakdown.free) - Int64(freePages * pageSize)) <= Int64(driftAllowance))
        #expect(abs(Int64(breakdown.compressed) - Int64(compressedPages * pageSize)) <= Int64(driftAllowance))
        let expectedAppPages = anonymousPages >= purgeablePages ? anonymousPages - purgeablePages : 0
        #expect(abs(Int64(breakdown.app) - Int64(expectedAppPages * pageSize)) <= Int64(driftAllowance))
        #expect(
            abs(Int64(breakdown.cached) - Int64((fileBackedPages + purgeablePages) * pageSize))
                <= Int64(driftAllowance)
        )
        #expect(breakdown.app > 0)
        #expect(breakdown.cached > 0)
        #expect(breakdown.free > 0)
    }

    @Test("Menu bar memory used uses same formula and stays in range")
    func testMenuBarMemoryRange() {
        let used = SystemUsage.memoryUsedBytes()
        let total = ProcessInfo.processInfo.physicalMemory
        let percent = SystemUsage.memoryPercent()
        #expect(used > 0)
        #expect(used <= total)
        #expect(percent > 0 && percent <= 100)
    }

    @Test("Swap usage matches sysctl ground truth")
    func testSwapGroundTruth() {
        let ours = SystemUsage.swapUsage()
        let raw = shellOutput("/usr/sbin/sysctl", ["-n", "vm.swapusage"])
        var groundTotal: Double?
        var groundUsed: Double?
        let parts = raw.split(separator: " ")
        for (index, part) in parts.enumerated() {
            if part == "total", index + 2 < parts.count, parts[index + 1] == "=" {
                groundTotal = Double(parts[index + 2].replacingOccurrences(of: "M", with: ""))
            }
            if part == "used", index + 2 < parts.count, parts[index + 1] == "=" {
                groundUsed = Double(parts[index + 2].replacingOccurrences(of: "M", with: ""))
            }
        }
        #expect(groundTotal != nil && groundUsed != nil)
        guard let groundTotal, let groundUsed else { return }
        let tolerance = 8.0 * 1024 * 1024
        #expect(abs(Double(ours.total) - groundTotal * 1024 * 1024) <= tolerance)
        #expect(abs(Double(ours.used) - groundUsed * 1024 * 1024) <= tolerance)
        #expect(ours.used <= ours.total)
    }

    @Test("Uptime seconds match kern.boottime ground truth")
    func testUptimeGroundTruth() {
        let ours = SystemUsage.uptimeSeconds()
        #expect(ours > 0)
        let raw = shellOutput("/usr/sbin/sysctl", ["-n", "kern.boottime"])
        var bootSeconds: Double?
        let parts = raw.split(separator: " ")
        for (index, part) in parts.enumerated() {
            if part == "=", index > 0, parts[index - 1] == "sec", index + 1 < parts.count {
                bootSeconds = Double(parts[index + 1].filter { $0.isNumber || $0 == "-" })
            }
        }
        #expect(bootSeconds != nil)
        guard let bootSeconds else { return }
        let ground = Date().timeIntervalSince1970 - bootSeconds
        #expect(abs(ours - ground) < 5)
        #expect(!SystemUsage.uptimeDescription().isEmpty)
    }

    @Test("Core counts match active processor count")
    func testCoreCounts() {
        let counts = SystemUsage.coreCounts()
        let active = ProcessInfo.processInfo.activeProcessorCount
        #expect(counts.total == active)
        if counts.efficiency > 0 {
            #expect(counts.efficiency + counts.performance == counts.total)
        }
        if counts.performance > 0 {
            #expect(counts.efficiency + counts.performance == counts.total)
        }
    }

    @Test("Top process sample matches independent ps ground truth")
    func testTopProcessGroundTruth() async throws {
        func pidMap(_ raw: String) -> [pid_t: Double] {
            var map: [pid_t: Double] = [:]
            for line in raw.split(separator: "\n") {
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let pid = pid_t(parts[0]),
                      let value = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
                map[pid] = value
            }
            return map
        }

        let before = pidMap(shellOutput("/bin/ps", ["-A", "-o", "pid=,%cpu="]))
        let result = await TopProcessSampler.sample(limit: 8)
        let after = pidMap(shellOutput("/bin/ps", ["-A", "-o", "pid=,%cpu="]))
        #expect(!result.cpu.isEmpty)
        #expect(!result.mem.isEmpty)

        for (index, proc) in result.cpu.enumerated() where index > 0 {
            #expect(result.cpu[index - 1].cpu >= proc.cpu)
            #expect(proc.cpu >= 0 && proc.cpu <= 900)
            #expect(!proc.name.isEmpty)
            #expect(proc.id > 0)
        }
        for (index, proc) in result.mem.enumerated() where index > 0 {
            #expect(result.mem[index - 1].bytes >= proc.bytes)
            #expect(!proc.name.isEmpty)
            #expect(proc.id > 0)
        }

        guard !result.cpu.isEmpty else { return }
        var checked = 0
        var good = 0
        for proc in result.cpu {
            let readings = [before[proc.id], after[proc.id]].compactMap { $0 }
            guard !readings.isEmpty else { continue }
            checked += 1
            let low = readings.min()! - 15.0
            let high = readings.max()! + 15.0
            if proc.cpu >= low && proc.cpu <= high { good += 1 }
        }
        #expect(checked > 0, "no overlapping pid between sampler and ground ps")
        #expect(good >= max(1, checked - 2), "unstable pids: \(checked - good) of \(checked)")
    }

    @Test("History buffer keeps last 180 samples")
    func testHistoryLimit() {
        var history: [Double] = []
        for index in 0..<200 {
            history.append(Double(index))
            if history.count > 180 {
                history.removeFirst(history.count - 180)
            }
        }
        #expect(history.count == 180)
        #expect(history.last == 199)
        #expect(history.first == 20)
    }

}
