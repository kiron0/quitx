import Foundation

struct AppInfo: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleId: String?
    let pid: pid_t?
    let pids: [pid_t]
    let isBackground: Bool
    let windowCount: Int
    let memoryBytes: UInt64
    let cpuUsage: Double
    let isUnresponsive: Bool
    let isCpuHog: Bool

    var isWindowless: Bool { windowCount == 0 && !isBackground }

    var memoryFormatted: String {
        MemoryFormatter.format(bytes: memoryBytes)
    }

    var cpuFormatted: String {
        return String(format: "%.1f%%", cpuUsage)
    }

    init(
        id: String? = nil,
        name: String,
        bundleId: String? = nil,
        pid: pid_t? = nil,
        pids: [pid_t] = [],
        isBackground: Bool = false,
        windowCount: Int = 0,
        memoryBytes: UInt64 = 0,
        cpuUsage: Double = 0.0,
        isUnresponsive: Bool = false,
        isCpuHog: Bool = false
    ) {
        let resolvedPids = pids.isEmpty ? (pid.map { [$0] } ?? []) : pids
        if let id {
            self.id = id
        } else if let p = pid {
            self.id = "\(p)-\(bundleId ?? name)"
        } else if let firstPid = resolvedPids.first {
            self.id = "pids-\(firstPid)-\(resolvedPids.count)-\(bundleId ?? name)"
        } else if isBackground && bundleId == nil {
            self.id = "bg-\(name)"
        } else {
            self.id = bundleId ?? name
        }
        self.name = name
        self.bundleId = bundleId
        self.pid = pid
        self.pids = resolvedPids
        self.isBackground = isBackground
        self.windowCount = windowCount
        self.memoryBytes = memoryBytes
        self.cpuUsage = cpuUsage
        self.isUnresponsive = isUnresponsive
        self.isCpuHog = isCpuHog
    }

    /// Copy with the unresponsive flag replaced. Used for the badge that
    /// marks apps which ignored a previous graceful quit request.
    func settingUnresponsive(_ value: Bool) -> AppInfo {
        AppInfo(
            id: id,
            name: name,
            bundleId: bundleId,
            pid: pid,
            pids: pids,
            isBackground: isBackground,
            windowCount: windowCount,
            memoryBytes: memoryBytes,
            cpuUsage: cpuUsage,
            isUnresponsive: value,
            isCpuHog: isCpuHog
        )
    }
}

struct QuitResult: Sendable {
    let app: AppInfo
    let success: Bool
    let forced: Bool
    let error: String?
}
