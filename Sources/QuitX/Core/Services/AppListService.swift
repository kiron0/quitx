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

    @MainActor
    func fetchApps(config: QuitXConfig) async -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> RunningAppSnapshot? in
            guard !app.isTerminated else { return nil }
            let rawName = app.localizedName
                ?? app.bundleURL?.deletingPathExtension().lastPathComponent
                ?? app.executableURL?.lastPathComponent
            guard let rawName else { return nil }
            let name = SystemAppProtection.cleanAppName(rawName)
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
        let windowCounts = Self.visibleWindowCounts()
        let scanTask = Task.detached(priority: .userInitiated) {
            Self.buildApps(from: running, windowCounts: windowCounts, config: config)
        }
        return await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    private static func buildApps(from running: [RunningAppSnapshot], windowCounts: [pid_t: Int], config: QuitXConfig) -> [AppInfo] {
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

            if SystemAppProtection.isSystemProtected(
                bundleIdentifier: app.bundleId,
                isBackground: isBackground,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL
            ) { continue }

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
                    let cleanedName = SystemAppProtection.cleanGroupedName(app.name)
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

        return sortApps(results, sortBy: config.sortBy)
    }

    func fetchLiveStats(currentApps: [AppInfo], config: QuitXConfig) async -> [AppInfo] {
        let scanTask = Task.detached(priority: .userInitiated) {
            let cpuUsages = Self.fetchCpuUsages()
            let updated = currentApps.map { app -> AppInfo in
                if app.pids.isEmpty { return app }
                var totalMem: UInt64 = 0
                var totalCpu: Double = 0.0
                for pid in app.pids {
                    totalMem += Self.memoryUsage(pid: pid)
                    totalCpu += cpuUsages[pid, default: 0.0]
                }
                return AppInfo(
                    name: app.name,
                    bundleId: app.bundleId,
                    pid: app.pid,
                    pids: app.pids,
                    isBackground: app.isBackground,
                    windowCount: app.windowCount,
                    memoryBytes: totalMem,
                    cpuUsage: totalCpu
                )
            }
            return Self.sortApps(updated, sortBy: config.sortBy)
        }
        return await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    static func sortApps(_ results: [AppInfo], sortBy: QuitXConfig.SortBy) -> [AppInfo] {
        switch sortBy {
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
            return results.sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
        case .nameDesc:
            return results.sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedDescending
            }
        }
    }

    private static var cachedCpuUsages: [pid_t: Double] = [:]
    private static var lastCpuFetchTime: Date = .distantPast
    private static let cpuCacheLock = NSLock()

    private static func fetchCpuUsages() -> [pid_t: Double] {
        cpuCacheLock.lock()
        if Date().timeIntervalSince(lastCpuFetchTime) < 1.0, !cachedCpuUsages.isEmpty {
            let cached = cachedCpuUsages
            cpuCacheLock.unlock()
            return cached
        }
        cpuCacheLock.unlock()

        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-c", "-A", "-o", "pid,%cpu"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return [:]
        }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }
        var result: [pid_t: Double] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let trimmed = line.drop(while: { $0.isWhitespace })
            guard let spaceIdx = trimmed.firstIndex(where: { $0.isWhitespace }) else { continue }
            let pidStr = trimmed[..<spaceIdx]
            let cpuStr = trimmed[spaceIdx...].drop(while: { $0.isWhitespace })
            if let pid = pid_t(pidStr), let cpu = Double(cpuStr) {
                result[pid] = cpu
            }
        }
        cpuCacheLock.lock()
        cachedCpuUsages = result
        lastCpuFetchTime = Date()
        cpuCacheLock.unlock()
        return result
    }

    private static var cachedMemoryUsages: [pid_t: (bytes: UInt64, timestamp: Date)] = [:]
    private static let memoryCacheLock = NSLock()

    private static func memoryUsage(pid: pid_t) -> UInt64 {
        memoryCacheLock.lock()
        if let cached = cachedMemoryUsages[pid], Date().timeIntervalSince(cached.timestamp) < 1.5 {
            memoryCacheLock.unlock()
            return cached.bytes
        }
        memoryCacheLock.unlock()

        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        let bytes = info.pti_resident_size

        memoryCacheLock.lock()
        cachedMemoryUsages[pid] = (bytes, Date())
        memoryCacheLock.unlock()
        return bytes
    }

    @MainActor
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
