import Foundation
import Darwin
import os

enum SystemUsage {
    private struct CpuState {
        var prevBusy: UInt64?
        var prevTotal: UInt64?
        var lastPercent: Double = 0
    }

    private static let cpuLock = OSAllocatedUnfairLock(initialState: CpuState())

    static func prime() {
        _ = cpuPercent()
    }

    static func cpuPercent() -> Double {
        guard let (busy, total) = readCpuTicks() else {
            return cpuLock.withLock { $0.lastPercent }
        }
        return cpuLock.withLock { state -> Double in
            guard let prevBusy = state.prevBusy, let prevTotal = state.prevTotal else {
                state.prevBusy = busy
                state.prevTotal = total
                return 0
            }
            state.prevBusy = busy
            state.prevTotal = total
            guard total > prevTotal else { return state.lastPercent }
            let deltaTotal = total - prevTotal
            guard deltaTotal > 0 else { return state.lastPercent }
            let deltaBusy = busy >= prevBusy ? busy - prevBusy : 0
            let raw = Double(deltaBusy) / Double(deltaTotal) * 100
            let clamped = min(100, max(0, raw))
            state.lastPercent = clamped
            return clamped
        }
    }

    static func memoryUsedBytes() -> UInt64 {
        readMemory()?.used ?? 0
    }

    static func memoryPercent() -> Double {
        guard let memory = readMemory(), memory.total > 0 else { return 0 }
        let raw = Double(memory.used) / Double(memory.total) * 100
        return min(100, max(0, raw))
    }

    private static func readMemory() -> (used: UInt64, total: UInt64)? {
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
        let usedPages = UInt64(stats.active_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        return (usedPages * pageSize, ProcessInfo.processInfo.physicalMemory)
    }

    private static func readCpuTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0)
        let idle = UInt64(info.cpu_ticks.1)
        let system = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice
        return (busy, busy + idle)
    }
}
