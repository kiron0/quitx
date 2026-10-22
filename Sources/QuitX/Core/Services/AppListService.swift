import AppKit
import Darwin
import os

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
        let pidsByPath = await Self.pidRecoveryIndex()
        let running = Self.runningSnapshots(pidsByPath: pidsByPath)
        let scanTask = Task.detached(priority: .userInitiated) {
            let windowCounts = Self.visibleWindowCounts()
            return Self.buildApps(from: running, windowCounts: windowCounts, config: config)
        }
        return await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    @MainActor
    func fetchAppsSynchronously(config: QuitXConfig) -> [AppInfo] {
        let pidsByPath = Self.pidRecoveryIndexSynchronously()
        let running = Self.runningSnapshots(pidsByPath: pidsByPath)
        let windowCounts = Self.visibleWindowCounts()
        return Self.buildApps(from: running, windowCounts: windowCounts, config: config)
    }

    @MainActor
    private static func pidRecoveryIndex() async -> [String: pid_t] {
        let workspaceApps = NSWorkspace.shared.runningApplications
        let needsRecovery = workspaceApps.contains {
            !$0.isTerminated && $0.processIdentifier <= 0 && $0.executableURL != nil
        }
        guard needsRecovery else { return [:] }
        return await Task.detached(priority: .utility) {
            Self.pidsByNormalizedPath(Self.runningProcessPaths())
        }.value
    }

    @MainActor
    private static func pidRecoveryIndexSynchronously() -> [String: pid_t] {
        let workspaceApps = NSWorkspace.shared.runningApplications
        let needsRecovery = workspaceApps.contains {
            !$0.isTerminated && $0.processIdentifier <= 0 && $0.executableURL != nil
        }
        guard needsRecovery else { return [:] }
        return pidsByNormalizedPath(runningProcessPaths())
    }

    @MainActor
    private static func runningSnapshots(pidsByPath: [String: pid_t]) -> [RunningAppSnapshot] {
        var seenPids = Set<pid_t>()
        return NSWorkspace.shared.runningApplications.compactMap { app -> RunningAppSnapshot? in
            guard !app.isTerminated else { return nil }
            guard let pid = resolvedProcessIdentifier(
                reportedPid: app.processIdentifier,
                executablePath: app.executableURL?.path,
                pidsByNormalizedPath: pidsByPath
            ), processIsRunning(pid), seenPids.insert(pid).inserted else { return nil }
            let rawName = app.localizedName
                ?? app.bundleURL?.deletingPathExtension().lastPathComponent
                ?? app.executableURL?.lastPathComponent
            guard let rawName else { return nil }
            let name = SystemAppProtection.cleanAppName(rawName)
            guard !name.isEmpty else { return nil }
            return RunningAppSnapshot(
                pid: pid,
                name: name,
                bundleId: app.bundleIdentifier,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL,
                isRegular: app.activationPolicy == .regular,
                isBackground: app.activationPolicy == .accessory
            )
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

            if !config.includeFinder && (bundleId == QuitXConstants.SystemBundleIds.finder || lowerName == "finder") { continue }

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
                cpuUsage: cpu,
                isUnresponsive: false
            ))
        }

        results = AppInstanceGrouping.merge(results)

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

            for (key, group) in bgGroups {
                let first = group.app
                groupedResults.append(AppInfo(
                    id: "background:\(key)",
                    name: group.cleanName,
                    bundleId: first.bundleId,
                    pid: group.pids.first,
                    pids: group.pids,
                    isBackground: true,
                    windowCount: group.windows,
                    memoryBytes: group.mem,
                    cpuUsage: group.cpu,
                    isUnresponsive: first.isUnresponsive
                ))
            }
            results = groupedResults
        }

        if config.includeTrash {
            if !excluded.contains("trash") && !excluded.contains(QuitXConstants.SystemBundleIds.trash) {
                results.append(AppInfo(
                    name: "Trash",
                    bundleId: QuitXConstants.SystemBundleIds.trash,
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

    func fetchLiveStats(currentApps: [AppInfo], config: QuitXConfig, hogPids: Set<pid_t> = [], cpuUsages providedUsages: [pid_t: Double]? = nil) async -> [AppInfo] {
        let scanTask = Task.detached(priority: .userInitiated) {
            let cpuUsages = providedUsages ?? Self.fetchCpuUsages()
            let updated = currentApps.compactMap { app -> AppInfo? in
                if app.pids.isEmpty { return app }
                let livePids = app.pids.filter(Self.processIsRunning)
                guard !livePids.isEmpty else { return nil }
                var totalMem: UInt64 = 0
                var totalCpu: Double = 0.0
                for pid in livePids {
                    totalMem += Self.memoryUsage(pid: pid)
                    totalCpu += cpuUsages[pid, default: 0.0]
                }
                return AppInfo(
                    id: app.id,
                    name: app.name,
                    bundleId: app.bundleId,
                    pid: app.pid.flatMap { livePids.contains($0) ? $0 : nil } ?? livePids.first,
                    pids: livePids,
                    isBackground: app.isBackground,
                    windowCount: app.windowCount,
                    memoryBytes: totalMem,
                    cpuUsage: totalCpu,
                    isUnresponsive: false,
                    isCpuHog: !Set(livePids).isDisjoint(with: hogPids)
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

    static func fetchCpuUsages() -> [pid_t: Double] {
        CpuUsageSampler.start()
        return CpuUsageSampler.usages()
    }

    private static let instanceLabelCache = OSAllocatedUnfairLock(
        uncheckedState: [pid_t: (start: UInt64, label: String?)]()
    )

    static func instanceLabel(for pid: pid_t) -> String? {
        let start = ProcessTree.startTime(of: pid) ?? 0
        if let cached = instanceLabelCache.withLockUnchecked({ $0[pid] }), cached.start == start {
            return cached.label
        }
        let label = ProcessArguments.read(pid: pid).flatMap { arguments in
            AppInstanceLabel.label(arguments: arguments) { userDataDir, profileDirectory in
                ChromiumProfiles.resolveLabel(userDataDir: userDataDir, profileDirectory: profileDirectory)
            }
        }
        instanceLabelCache.withLockUnchecked { cache in
            if cache.count >= 256 { cache.removeAll() }
            cache[pid] = (start, label)
        }
        return label
    }

    private static let memoryCache = OSAllocatedUnfairLock(initialState: [pid_t: (bytes: UInt64, timestamp: Date)]())

    static func processIsRunning(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        errno = 0
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    static func pidsByNormalizedPath(_ processPaths: [pid_t: String]) -> [String: pid_t] {
        var index: [String: pid_t] = [:]
        index.reserveCapacity(processPaths.count)
        for (pid, path) in processPaths where pid > 0 {
            let key = URL(fileURLWithPath: path).standardizedFileURL.path
            if let existing = index[key] {
                if pid < existing { index[key] = pid }
            } else {
                index[key] = pid
            }
        }
        return index
    }

    static func resolvedProcessIdentifier(
        reportedPid: pid_t,
        executablePath: String?,
        pidsByNormalizedPath: [String: pid_t]
    ) -> pid_t? {
        if reportedPid > 0 { return reportedPid }
        guard let executablePath, !executablePath.isEmpty else { return nil }
        let target = URL(fileURLWithPath: executablePath).standardizedFileURL.path
        return pidsByNormalizedPath[target]
    }

    static func resolvedProcessIdentifier(
        reportedPid: pid_t,
        executablePath: String?,
        processPaths: [pid_t: String]
    ) -> pid_t? {
        resolvedProcessIdentifier(
            reportedPid: reportedPid,
            executablePath: executablePath,
            pidsByNormalizedPath: pidsByNormalizedPath(processPaths)
        )
    }

    static func runningProcessPaths() -> [pid_t: String] {
        let estimatedCount = max(0, Int(proc_listallpids(nil, 0)))
        guard estimatedCount > 0 else { return [:] }

        var pids = [pid_t](repeating: 0, count: estimatedCount + 128)
        let byteCount = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let actualCount = proc_listallpids(&pids, byteCount)
        guard actualCount > 0 else { return [:] }

        var paths: [pid_t: String] = [:]
        paths.reserveCapacity(Int(actualCount))
        var buffer = [CChar](repeating: 0, count: 4096)
        for pid in pids.prefix(Int(actualCount)) where pid > 0 {
            let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            guard length > 0 else { continue }
            paths[pid] = String(cString: buffer)
        }
        return paths
    }

    private static func memoryUsage(pid: pid_t) -> UInt64 {
        if let cached = memoryCache.withLock({ $0[pid] }), Date().timeIntervalSince(cached.timestamp) < 1.5 {
            return cached.bytes
        }

        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        let bytes = info.pti_resident_size

        let now = Date()
        memoryCache.withLock { cache in
            if cache.count >= 256 {
                let cutoff = now.addingTimeInterval(-5)
                cache = cache.filter { $0.value.timestamp >= cutoff }
                if cache.count >= 256 {
                    let newest = cache.sorted { $0.value.timestamp > $1.value.timestamp }.prefix(128)
                    cache = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
                }
            }
            cache[pid] = (bytes, now)
        }
        return bytes
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
