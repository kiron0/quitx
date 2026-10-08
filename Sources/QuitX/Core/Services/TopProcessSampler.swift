import Foundation

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
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-A", "-o", "pid=,%cpu=,rss=,comm="]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        let watchdog = DispatchWorkItem { [weak proc] in
            if let proc, proc.isRunning {
                proc.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: watchdog)

        do {
            try proc.run()
        } catch {
            watchdog.cancel()
            return ([], [])
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        watchdog.cancel()

        guard let text = String(data: data, encoding: .utf8) else { return ([], []) }
        let ownPid = ProcessInfo.processInfo.processIdentifier
        var rows: [Proc] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = pid_t(parts[0]),
                  pid != ownPid,
                  let cpu = Double(parts[1]),
                  let rssKb = Double(parts[2]) else { continue }
            let name = URL(fileURLWithPath: String(parts[3])).lastPathComponent
            guard !name.isEmpty else { continue }
            rows.append(Proc(id: pid, name: name, cpu: cpu, bytes: UInt64(rssKb * 1024)))
        }

        let topCpu = rows.sorted { $0.cpu > $1.cpu }.prefix(limit)
        let topMem = rows.sorted { $0.bytes > $1.bytes }.prefix(limit)
        return (Array(topCpu), Array(topMem))
    }
}
