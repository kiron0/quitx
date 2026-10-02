import AppKit

final class AppListService {
    static let shared = AppListService()
    private init() {}

    func fetchApps(config: QuitXConfig) -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications
        let windowCounts = visibleWindowCounts()
        let cpuUsages = fetchCpuUsages()

        var results: [AppInfo] = []

        for app in running {
            guard let name = app.localizedName else { continue }
            let bundleId = app.bundleIdentifier
            let pid = app.processIdentifier

            let isRegularApp = app.activationPolicy == .regular
            let isBackground = app.activationPolicy == .accessory

            if !isRegularApp && !isBackground { continue }
            if isBackground && !config.includeBackground { continue }

            if let bid = bundleId, config.exclude.contains(bid) { continue }
            if config.exclude.contains(name) { continue }

            if config.neverQuitMusic && config.musicApps.contains(where: { name.localizedCaseInsensitiveContains($0) || bundleId?.localizedCaseInsensitiveContains($0) == true }) {
                continue
            }

            if !config.includeFinder && bundleId == "com.apple.finder" { continue }
            if !config.includeTrash && name == "Trash" { continue }

            let memory = memoryUsage(pid: pid)
            let cpu = cpuUsages[pid, default: 0.0]
            let windows = windowCounts[pid, default: 0]

            results.append(AppInfo(
                name: name,
                bundleId: bundleId,
                pid: pid,
                isBackground: isBackground,
                windowCount: windows,
                memoryBytes: memory,
                cpuUsage: cpu
            ))
        }

        switch config.sortBy {
        case .cpuDesc:
            return results.sorted {
                if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .cpuAsc:
            return results.sorted {
                if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage < $1.cpuUsage }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .memoryDesc:
            return results.sorted {
                if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .memoryAsc:
            return results.sorted {
                if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes < $1.memoryBytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }

    private func fetchCpuUsages() -> [pid_t: Double] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-c", "-A", "-o", "pid,%cpu"]
        proc.standardOutput = pipe
        try? proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }
        var result: [pid_t: Double] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            if parts.count >= 2, let pid = pid_t(parts[0]), let cpu = Double(parts[1]) {
                result[pid] = cpu
            }
        }
        return result
    }

    private func memoryUsage(pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        return info.pti_resident_size
    }

    private func visibleWindowCounts() -> [pid_t: Int] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }

        var counts: [pid_t: Int] = [:]
        for window in list {
            guard let ownerPid = window[kCGWindowOwnerPID as String] as? pid_t else { continue }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            counts[ownerPid, default: 0] += 1
        }
        return counts
    }
}
