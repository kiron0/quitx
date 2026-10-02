import Foundation

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleId: String?
    let pid: pid_t?
    let isBackground: Bool
    let windowCount: Int
    let memoryBytes: UInt64
    let cpuUsage: Double

    var isWindowless: Bool { windowCount == 0 && !isBackground }

    var memoryFormatted: String {
        MemoryFormatter.format(bytes: memoryBytes)
    }

    var cpuFormatted: String {
        return String(format: "%.1f%%", cpuUsage)
    }

    init(
        name: String,
        bundleId: String? = nil,
        pid: pid_t? = nil,
        isBackground: Bool = false,
        windowCount: Int = 0,
        memoryBytes: UInt64 = 0,
        cpuUsage: Double = 0.0
    ) {
        if let p = pid {
            self.id = "\(p)-\(bundleId ?? name)"
        } else {
            self.id = bundleId ?? name
        }
        self.name = name
        self.bundleId = bundleId
        self.pid = pid
        self.isBackground = isBackground
        self.windowCount = windowCount
        self.memoryBytes = memoryBytes
        self.cpuUsage = cpuUsage
    }
}

struct QuitResult {
    let app: AppInfo
    let success: Bool
    let forced: Bool
    let error: String?
}

struct StashData: Codable {
    let timestamp: String
    let apps: [StashEntry]
}

struct StashEntry: Codable {
    let name: String
    let bundleId: String?
}

enum OnQuitFailureMode: String, Codable, CaseIterable {
    case prompt, force, error
}
