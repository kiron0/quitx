import AppKit

final class AppListService {
    static let shared = AppListService()
    private init() {}

    func fetchApps(config: QuitXConfig) -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications
        let windowCounts = visibleWindowCounts()
        let cpuUsages = fetchCpuUsages()

        var results: [AppInfo] = []

        let currentPid = ProcessInfo.processInfo.processIdentifier

        for app in running {
            let pid = app.processIdentifier
            if pid == currentPid { continue }
            guard let name = app.localizedName else { continue }
            let bundleId = app.bundleIdentifier
            if bundleId == "com.kiron.quitx" || bundleId == "com.coreify.quitx" { continue }

            let isRegularApp = app.activationPolicy == .regular
            let isBackground = app.activationPolicy == .accessory

            if !isRegularApp && !isBackground { continue }
            if isBackground && !config.includeBackground { continue }

            let lowerName = name.lowercased()
            let lowerBid = bundleId?.lowercased()

            if let bid = lowerBid, config.exclude.map({ $0.lowercased() }).contains(bid) { continue }
            if config.exclude.map({ $0.lowercased() }).contains(lowerName) { continue }

            if config.neverQuitMusic && config.musicApps.contains(where: {
                lowerName.contains($0.lowercased()) || lowerBid?.contains($0.lowercased()) == true
            }) {
                continue
            }

            if !config.includeFinder && (bundleId == "com.apple.finder" || lowerName == "finder") { continue }

            let memory = memoryUsage(pid: pid)
            let cpu = cpuUsages[pid, default: 0.0]
            let windows = windowCounts[pid, default: 0]

            results.append(AppInfo(
                name: name,
                bundleId: bundleId,
                pid: pid,
                pids: [pid],
                isBackground: isBackground,
                windowCount: windows,
                memoryBytes: memory,
                cpuUsage: cpu
            ))
        }

        if config.includeBackground && config.groupBackground {
            var groupedResults: [AppInfo] = []
            var bgGroups: [String: (app: AppInfo, pids: [pid_t], mem: UInt64, cpu: Double, windows: Int)] = [:]

            for app in results {
                if app.isBackground {
                    let key = (app.bundleId ?? app.name).lowercased()
                    if var existing = bgGroups[key] {
                        existing.pids.append(contentsOf: app.pids)
                        existing.mem += app.memoryBytes
                        existing.cpu += app.cpuUsage
                        existing.windows += app.windowCount
                        bgGroups[key] = existing
                    } else {
                        bgGroups[key] = (app: app, pids: app.pids, mem: app.memoryBytes, cpu: app.cpuUsage, windows: app.windowCount)
                    }
                } else {
                    groupedResults.append(app)
                }
            }

            for (_, group) in bgGroups {
                let first = group.app
                groupedResults.append(AppInfo(
                    name: first.name,
                    bundleId: first.bundleId,
                    pid: group.pids.first,
                    pids: group.pids,
                    isBackground: true,
                    windowCount: group.windows,
                    memoryBytes: group.mem,
                    cpuUsage: group.cpu
                ))
            }
            results = groupedResults
        }

        if config.includeTrash {
            let lowerExclude = config.exclude.map { $0.lowercased() }
            if !lowerExclude.contains("trash") && !lowerExclude.contains("com.apple.trash") {
                results.append(AppInfo(
                    name: "Trash",
                    bundleId: "com.apple.trash",
                    pid: nil,
                    pids: [],
                    isBackground: false,
                    windowCount: 0,
                    memoryBytes: 0,
                    cpuUsage: 0.0
                ))
            }
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
