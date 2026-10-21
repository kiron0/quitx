import Foundation
import Darwin

enum TopProcessSampler {
    struct Proc: Identifiable, Equatable, Sendable {
        let id: pid_t
        let name: String
        let cpu: Double
        let bytes: UInt64
    }

    static func sample(limit: Int = 8) async -> (cpu: [Proc], mem: [Proc]) {
        await Task.detached(priority: .utility) {
            runSample(limit: limit)
        }.value
    }

    private static func runSample(limit: Int) -> (cpu: [Proc], mem: [Proc]) {
        CpuUsageSampler.start()
        let cpuUsages = CpuUsageSampler.usages()
        let ownPid = ProcessInfo.processInfo.processIdentifier

        var pids = [pid_t](repeating: 0, count: 4096)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else { return ([], []) }

        var rows: [Proc] = []
        rows.reserveCapacity(256)
        var unreadable: [pid_t] = []
        var nameBuffer = [CChar](repeating: 0, count: 1024)

        for pid in pids.prefix(Int(count)) where pid > 0 && pid != ownPid {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else {
                unreadable.append(pid)
                continue
            }
            let bytes = info.pti_resident_size
            guard bytes > 0 else { continue }
            let name = processName(pid: pid, buffer: &nameBuffer)
            guard !name.isEmpty else { continue }
            rows.append(Proc(id: pid, name: name, cpu: cpuUsages[pid] ?? 0, bytes: bytes))
        }

        if !unreadable.isEmpty {
            mergeUnreadable(&rows, pids: unreadable, cpuUsages: cpuUsages)
        }

        let topCpu = rows.sorted { $0.cpu > $1.cpu }.prefix(limit)
        let topMem = rows.sorted { $0.bytes > $1.bytes }.prefix(limit)
        return (Array(topCpu), Array(topMem))
    }

    private static func mergeUnreadable(_ rows: inout [Proc], pids: [pid_t], cpuUsages: [pid_t: Double]) {
        let wanted = Set(pids)
        guard let output = shellOutput("/bin/ps", arguments: ["-A", "-o", "pid=,%cpu=,rss=,comm="]) else { return }
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = pid_t(parts[0]),
                  wanted.contains(pid),
                  let cpu = Double(parts[1]),
                  let rssKb = Double(parts[2]) else { continue }
            let name = URL(fileURLWithPath: String(parts[3])).lastPathComponent
            guard !name.isEmpty else { continue }
            let bytes = UInt64(exactly: rssKb * 1024) ?? 0
            rows.append(Proc(id: pid, name: name, cpu: cpuUsages[pid] ?? cpu, bytes: bytes))
        }
    }

    private static func shellOutput(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let watchdog = DispatchWorkItem { [weak process] in
            if let process, process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: watchdog)

        guard (try? process.run()) != nil else {
            watchdog.cancel()
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        return String(data: data, encoding: .utf8)
    }

    private static func processName(pid: pid_t, buffer: inout [CChar]) -> String {
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }
}
