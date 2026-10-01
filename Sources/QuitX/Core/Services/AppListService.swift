import AppKit

/// Fetches running user-visible (and optionally background) apps with memory.
final class AppListService {
    static let shared = AppListService()
    private init() {}

    func fetchApps(config: QuitXConfig) -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications

        var results: [AppInfo] = []

        for app in running {
            guard let name = app.localizedName else { continue }
            let bundleId = app.bundleIdentifier
            let pid = app.processIdentifier

            // Filter system / agent apps
            let isRegularApp = app.activationPolicy == .regular
            let isBackground = app.activationPolicy == .accessory

            if !isRegularApp && !isBackground { continue }
            if isBackground && !config.includeBackground { continue }

            // Exclusions
            if let bid = bundleId, config.exclude.contains(bid) { continue }
            if config.exclude.contains(name) { continue }

            // Finder / Trash
            if !config.includeFinder && bundleId == "com.apple.finder" { continue }
            if !config.includeTrash && name == "Trash" { continue }

            let memory = memoryUsage(pid: pid)
            let windows = windowCount(pid: pid, bundleId: bundleId)

            results.append(AppInfo(
                name: name,
                bundleId: bundleId,
                pid: pid,
                isBackground: isBackground,
                windowCount: windows,
                memoryBytes: memory
            ))
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Memory

    private func memoryUsage(pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        guard result == size else { return 0 }
        return info.pti_resident_size
    }

    // MARK: - Window count

    private func windowCount(pid: pid_t, bundleId: String?) -> Int {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return list.filter { window in
            guard let ownerPid = window[kCGWindowOwnerPID as String] as? pid_t else { return false }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { return false }
            return ownerPid == pid
        }.count
    }
}
