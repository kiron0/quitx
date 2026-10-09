import Foundation
import Darwin
import os

enum SystemUsage {
    private struct CpuState {
        var previousTicks: [UInt64] = []
        var lastPercent: Double = 0
    }

    private static let cpuLock = OSAllocatedUnfairLock(initialState: [String: CpuState]())

    static func prime(consumer: String = "menuBar") {
        _ = cpuPercent(consumer: consumer)
    }

    static func cpuPercent(consumer: String = "default") -> Double {
        guard let ticks = readPerCoreTicks() else {
            return cpuLock.withLock { $0[consumer]?.lastPercent ?? 0 }
        }
        return cpuLock.withLock { states -> Double in
            var state = states[consumer] ?? CpuState()
            defer { states[consumer] = state }
            guard state.previousTicks.count == ticks.count, !state.previousTicks.isEmpty else {
                state.previousTicks = ticks
                return 0
            }
            let deltas = cpuTickDeltas(previous: state.previousTicks, current: ticks)
            state.previousTicks = ticks
            var deltaBusy: UInt64 = 0
            var deltaTotal: UInt64 = 0
            var index = 0
            while index + 3 < deltas.count {
                deltaBusy += deltas[index] + deltas[index + 2] + deltas[index + 3]
                deltaTotal += deltas[index] + deltas[index + 1] + deltas[index + 2] + deltas[index + 3]
                index += 4
            }
            guard deltaTotal > 0 else { return state.lastPercent }
            let raw = Double(deltaBusy) / Double(deltaTotal) * 100
            let clamped = min(100, max(0, raw))
            state.lastPercent = clamped
            return clamped
        }
    }

    static func memoryUsedBytes() -> UInt64 {
        readVmStats()?.used ?? 0
    }

    struct CpuDetail {
        let total: Double
        let system: Double
        let user: Double
        let idle: Double
        let perCore: [Double]
    }

    struct CpuLevel: Identifiable, Equatable, Sendable {
        let index: Int
        let name: String
        let logicalCores: Int

        var id: Int { index }
    }

    struct CpuTopology: Equatable, Sendable {
        let levels: [CpuLevel]
        let total: Int
    }

    struct MemoryBreakdown {
        let total: UInt64
        let app: UInt64
        let wired: UInt64
        let compressed: UInt64
        let cached: UInt64
        let free: UInt64
        let used: UInt64
    }

    private struct DetailedCpuState {
        var prev: [UInt64] = []
        var lastTotal: Double = 0
        var lastSystem: Double = 0
        var lastUser: Double = 0
        var lastIdle: Double = 100
        var lastPerCore: [Double] = []
    }

    private static let detailedCpuLock = OSAllocatedUnfairLock(initialState: [String: DetailedCpuState]())

    static func cpuDetail(consumer: String) -> CpuDetail {
        guard let ticks = readPerCoreTicks() else {
            return detailedCpuLock.withLock { states in
                let state = states[consumer]
                return CpuDetail(
                    total: state?.lastTotal ?? 0,
                    system: state?.lastSystem ?? 0,
                    user: state?.lastUser ?? 0,
                    idle: state?.lastIdle ?? 100,
                    perCore: state?.lastPerCore ?? []
                )
            }
        }
        let coreCount = ticks.count / 4
        return detailedCpuLock.withLock { states -> CpuDetail in
            var state = states[consumer] ?? DetailedCpuState()
            defer { states[consumer] = state }

            guard state.prev.count == ticks.count, !state.prev.isEmpty else {
                state.prev = ticks
                let zeros = [Double](repeating: 0, count: coreCount)
                state.lastTotal = 0
                state.lastSystem = 0
                state.lastUser = 0
                state.lastIdle = 100
                state.lastPerCore = zeros
                return CpuDetail(total: 0, system: 0, user: 0, idle: 100, perCore: zeros)
            }

            var dUser: UInt64 = 0
            var dIdle: UInt64 = 0
            var dSystem: UInt64 = 0
            var dNice: UInt64 = 0
            var perCore: [Double] = []
            perCore.reserveCapacity(coreCount)

            for core in 0..<coreCount {
                let base = core * 4
                let pUser = state.prev[base]
                let pIdle = state.prev[base + 1]
                let pSystem = state.prev[base + 2]
                let pNice = state.prev[base + 3]
                let dU = cpuTickDelta(previous: pUser, current: ticks[base])
                let dI = cpuTickDelta(previous: pIdle, current: ticks[base + 1])
                let dS = cpuTickDelta(previous: pSystem, current: ticks[base + 2])
                let dN = cpuTickDelta(previous: pNice, current: ticks[base + 3])
                let dTotal = dU + dI + dS + dN
                if dTotal > 0 {
                    perCore.append(min(100, Double(dU + dS + dN) / Double(dTotal) * 100))
                } else if state.lastPerCore.indices.contains(core) {
                    perCore.append(state.lastPerCore[core])
                } else {
                    perCore.append(0)
                }
                dUser += dU
                dIdle += dI
                dSystem += dS
                dNice += dN
            }

            state.prev = ticks
            let totalTicks = dUser + dIdle + dSystem + dNice
            guard totalTicks > 0 else {
                return CpuDetail(
                    total: state.lastTotal,
                    system: state.lastSystem,
                    user: state.lastUser,
                    idle: state.lastIdle,
                    perCore: perCore
                )
            }
            let totalPct = min(100, Double(dUser + dSystem + dNice) / Double(totalTicks) * 100)
            let systemPct = Double(dSystem) / Double(totalTicks) * 100
            let userPct = Double(dUser + dNice) / Double(totalTicks) * 100
            let idlePct = Double(dIdle) / Double(totalTicks) * 100
            state.lastTotal = totalPct
            state.lastSystem = systemPct
            state.lastUser = userPct
            state.lastIdle = idlePct
            state.lastPerCore = perCore
            return CpuDetail(total: totalPct, system: systemPct, user: userPct, idle: idlePct, perCore: perCore)
        }
    }

    static func cpuTickDelta(previous: UInt64, current: UInt64) -> UInt64 {
        UInt64(UInt32(truncatingIfNeeded: current) &- UInt32(truncatingIfNeeded: previous))
    }

    static func cpuTickDeltas(previous: [UInt64], current: [UInt64]) -> [UInt64] {
        guard previous.count == current.count else { return [] }
        return zip(previous, current).map { cpuTickDelta(previous: $0.0, current: $0.1) }
    }

    private static func readPerCoreTicks() -> [UInt64]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let host = mach_host_self()
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        mach_port_deallocate(mach_task_self_, host)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            )
        }
        var ticks: [UInt64] = []
        ticks.reserveCapacity(Int(cpuCount) * 4)
        for core in 0..<Int(cpuCount) {
            let base = core * Int(CPU_STATE_MAX)
            ticks.append(UInt64(UInt32(bitPattern: Int32(info[base + Int(CPU_STATE_USER)]))))
            ticks.append(UInt64(UInt32(bitPattern: Int32(info[base + Int(CPU_STATE_IDLE)]))))
            ticks.append(UInt64(UInt32(bitPattern: Int32(info[base + Int(CPU_STATE_SYSTEM)]))))
            ticks.append(UInt64(UInt32(bitPattern: Int32(info[base + Int(CPU_STATE_NICE)]))))
        }
        return ticks
    }

    static func cpuTopology() -> CpuTopology {
        let total = ProcessInfo.processInfo.activeProcessorCount
        guard let levelCount = sysctlInt("hw.nperflevels"), levelCount > 0 else {
            return CpuTopology(
                levels: [CpuLevel(index: 0, name: "CPU", logicalCores: total)],
                total: total
            )
        }

        let levels = (0..<levelCount).compactMap { index -> CpuLevel? in
            guard let logicalCores = sysctlInt("hw.perflevel\(index).logicalcpu"), logicalCores > 0 else {
                return nil
            }
            let reportedName = sysctlString("hw.perflevel\(index).name")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let name: String
            if let reportedName, !reportedName.isEmpty {
                name = reportedName
            } else {
                name = "Performance level \(index)"
            }
            return CpuLevel(index: index, name: name, logicalCores: logicalCores)
        }

        guard levels.count == levelCount,
              levels.reduce(0, { $0 + $1.logicalCores }) == total else {
            return CpuTopology(
                levels: [CpuLevel(index: 0, name: "CPU", logicalCores: total)],
                total: total
            )
        }
        return CpuTopology(levels: levels, total: total)
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var len = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &len, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func sysctlString(_ name: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 64)
        var len = 64
        guard sysctlbyname(name, &buffer, &len, nil, 0) == 0, len > 0 else { return nil }
        return String(cString: buffer)
    }

    static func loadAverages() -> (Double, Double, Double) {
        var loads = [Double](repeating: 0, count: 3)
        let result = loads.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, 3)
        }
        guard result == 3 else { return (0, 0, 0) }
        return (loads[0], loads[1], loads[2])
    }

    static func uptimeSeconds() -> Double {
        var boot = timeval()
        var len = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &len, nil, 0) == 0 else { return 0 }
        let seconds = Date().timeIntervalSince1970 - (Double(boot.tv_sec) + Double(boot.tv_usec) / 1_000_000)
        return max(0, seconds)
    }

    static func uptimeDescription() -> String {
        let seconds = uptimeSeconds()
        guard seconds > 0 else { return "" }
        let totalHours = Int(seconds) / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s"), \(hours) hour\(hours == 1 ? "" : "s")"
        }
        if totalHours > 0 {
            let minutes = Int(seconds) / 60 % 60
            return "\(totalHours) hour\(totalHours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        let minutes = Int(seconds) / 60
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    static func memoryBreakdown() -> MemoryBreakdown? {
        guard let stats = readVmStats() else { return nil }
        return MemoryBreakdown(
            total: ProcessInfo.processInfo.physicalMemory,
            app: stats.app,
            wired: stats.wired,
            compressed: stats.compressed,
            cached: stats.cached,
            free: stats.free,
            used: stats.used
        )
    }

    struct SwapUsage {
        let used: UInt64
        let total: UInt64
    }

    private struct XswUsageLayout {
        var total: UInt64
        var avail: UInt64
        var used: UInt64
        var pageSize: UInt32
        var encrypted: Int32
    }

    static func swapUsage() -> SwapUsage {
        var usage = XswUsageLayout(total: 0, avail: 0, used: 0, pageSize: 0, encrypted: 0)
        var len = MemoryLayout<XswUsageLayout>.size
        guard sysctlbyname("vm.swapusage", &usage, &len, nil, 0) == 0 else {
            return SwapUsage(used: 0, total: 0)
        }
        return SwapUsage(used: usage.used, total: usage.total)
    }

    private struct VmStats {
        let used: UInt64
        let app: UInt64
        let wired: UInt64
        let compressed: UInt64
        let cached: UInt64
        let free: UInt64
    }

    private static func readVmStats() -> VmStats? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_page_size)
        let internalPages = UInt64(stats.internal_page_count)
        let purgeablePages = UInt64(stats.purgeable_count)
        let app = internalPages >= purgeablePages ? (internalPages - purgeablePages) * pageSize : 0
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let cached = (UInt64(stats.external_page_count) + purgeablePages) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        return VmStats(
            used: app + wired + compressed,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free
        )
    }

    static func memoryPercent() -> Double {
        let total = ProcessInfo.processInfo.physicalMemory
        guard let memory = readVmStats(), total > 0 else { return 0 }
        let raw = Double(memory.used) / Double(total) * 100
        return min(100, max(0, raw))
    }
}
