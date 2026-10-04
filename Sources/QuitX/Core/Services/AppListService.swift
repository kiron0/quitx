import AppKit

final class AppListService {
    static let shared = AppListService()
    private init() {}

    private struct RunningAppSnapshot: Sendable {
        let pid: pid_t
        let name: String
        let bundleId: String?
        let bundleURL: URL?
        let executableURL: URL?
        let isRegular: Bool
        let isBackground: Bool
    }

    private static func isSystemProtected(app: RunningAppSnapshot) -> Bool {
        let bid = app.bundleId ?? ""
        if !bid.isEmpty && QuitXIdentity.supportedBundleIdentifiers.contains(bid) {
            return true
        }

        let bundlePath = app.bundleURL?.path ?? ""
        let execPath = app.executableURL?.path ?? ""
        let path = bundlePath.isEmpty ? execPath : bundlePath

        if path.hasPrefix("/System/Library/CoreServices/") && bid != "com.apple.finder" {
            return true
        }
        if path.hasPrefix("/System/Library/PrivateFrameworks/") || path.hasPrefix("/usr/") {
            return true
        }

        if app.isBackground {
            if bid.hasPrefix("com.apple.") {
                return true
            }
            if path.hasPrefix("/System/") || path.hasPrefix("/System/Volumes/") || path.hasPrefix("/Library/Apple/") {
                return true
            }
        }

        return false
    }

    private static func cleanAppName(_ rawName: String) -> String {
        rawName.replacingOccurrences(
            of: "[\u{200B}-\u{200D}\u{200E}\u{200F}\u{FEFF}]",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanGroupedName(_ name: String) -> String {
        let pattern = #"\s*\([^)]*\)$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            let stripped = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                return stripped
            }
        }
        return name
    }

    @MainActor
    func fetchApps(config: QuitXConfig) async -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> RunningAppSnapshot? in
            guard !app.isTerminated else { return nil }
            let rawName = app.localizedName
                ?? app.bundleURL?.deletingPathExtension().lastPathComponent
                ?? app.executableURL?.lastPathComponent
            guard let rawName else { return nil }
            let name = Self.cleanAppName(rawName)
            guard !name.isEmpty else { return nil }
            return RunningAppSnapshot(
                pid: app.processIdentifier,
                name: name,
                bundleId: app.bundleIdentifier,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL,
                isRegular: app.activationPolicy == .regular,
                isBackground: app.activationPolicy == .accessory
            )
        }
        let scanTask = Task.detached(priority: .userInitiated) {
            Self.buildApps(from: running, config: config)
        }
        return await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    private static func buildApps(from running: [RunningAppSnapshot], config: QuitXConfig) -> [AppInfo] {
        let windowCounts = visibleWindowCounts()
        let cpuUsages = fetchCpuUsages()
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let protectedMusicApps = config.musicApps.map { $0.lowercased() }

        var results: [AppInfo] = []

        let currentPid = ProcessInfo.processInfo.processIdentifier

        for app in running {
            if Task.isCancelled { return [] }
            let pid = app.pid
            if pid == currentPid { continue }

            let isRegularApp = app.isRegular
            let isBackground = app.isBackground

            if !isRegularApp && !isBackground { continue }
            if isBackground && !config.includeBackground { continue }

            if isSystemProtected(app: app) { continue }

            let name = app.name
            let bundleId = app.bundleId
            let lowerName = name.lowercased()
            let lowerBid = bundleId?.lowercased()

            if let bid = lowerBid, excluded.contains(bid) { continue }
            if excluded.contains(lowerName) { continue }

            if config.neverQuitMusic && protectedMusicApps.contains(where: {
                lowerName.contains($0) || lowerBid?.contains($0) == true
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
            var bgGroups: [String: (app: AppInfo, cleanName: String, pids: [pid_t], mem: UInt64, cpu: Double, windows: Int)] = [:]

            for app in results {
                if app.isBackground {
                    let cleanedName = cleanGroupedName(app.name)
                    let key = (app.bundleId ?? cleanedName).lowercased()
                    if var existing = bgGroups[key] {
                        existing.pids.append(contentsOf: app.pids)
                        existing.mem += app.memoryBytes
                        existing.cpu += app.cpuUsage
                        existing.windows += app.windowCount
                        bgGroups[key] = existing
                    } else {
                        bgGroups[key] = (app: app, cleanName: cleanedName, pids: app.pids, mem: app.memoryBytes, cpu: app.cpuUsage, windows: app.windowCount)
                    }
                } else {
                    groupedResults.append(app)
                }
            }

            for (_, group) in bgGroups {
                let first = group.app
                groupedResults.append(AppInfo(
                    name: group.cleanName,
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
            if !excluded.contains("trash") && !excluded.contains("com.apple.trash") {
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

    private static func fetchCpuUsages() -> [pid_t: Double] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-c", "-A", "-o", "pid,%cpu"]
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            return [:]
        }
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

    private static func memoryUsage(pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        return info.pti_resident_size
    }

    private static func visibleWindowCounts() -> [pid_t: Int] {
        autoreleasepool {
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
}
