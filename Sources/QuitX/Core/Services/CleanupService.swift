import Darwin
import Foundation

enum CleanupCategory: String, CaseIterable, Identifiable, Sendable {
    case systemJunk = "System Junk"
    case userCache = "User Cache"
    case mailFiles = "Mail Files"
    case trashBins = "Trash Bins"
    case largeOldFiles = "Large & Old Files"
    case aiApps = "AI Apps"
    case xcodeJunk = "Xcode Junk"
    case brewCache = "Brew Cache"
    case nodeCache = "Node Cache"
    case dockerCache = "Docker Cache"

    var id: String { rawValue }
}

struct CleanupItem: Identifiable, Hashable, Sendable {
    let url: URL
    let category: CleanupCategory
    let bytes: Int64
    let fileCount: Int
    let isDirectory: Bool
    let lastModified: Date?
    let isSelectedByDefault: Bool

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
}

enum CleanupService {
    private struct Target: Sendable {
        let path: String
        let selected: Bool
        let minimumBytes: Int64

        init(_ path: String, selected: Bool = true, minimumBytes: Int64 = 1) {
            self.path = path
            self.selected = selected
            self.minimumBytes = minimumBytes
        }
    }

    static func scan(
        _ category: CleanupCategory,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date()
    ) async -> [CleanupItem] {
        await detachedCancellable(priority: .userInitiated) {
            scanSynchronously(category, home: home.standardizedFileURL, now: now)
        }
    }

    static func scanSynchronously(_ category: CleanupCategory, home: URL, now: Date) -> [CleanupItem] {
        let items: [CleanupItem]
        switch category {
        case .systemJunk:
            items = topLevelItems(
                roots: [home.appendingPathComponent("Library/Logs")],
                category: category
            ) + topLevelItems(
                roots: [
                    URL(fileURLWithPath: "/Library/Caches"),
                    URL(fileURLWithPath: "/Library/Logs")
                ],
                category: category,
                ownedByCurrentUserOnly: true
            )
        case .userCache:
            let excluded = [
                "Homebrew", "npm", "Yarn", "ollama", "com.electron.ollama", "com.docker.docker",
                "com.apple.dt.Xcode", "org.swift.swiftpm",
                "com.apple.bird", "CloudKit", "com.apple.cloudd", "com.apple.homed", "FamilyCircle",
                Bundle.main.bundleIdentifier ?? "com.quitx.app"
            ]
            items = topLevelItems(
                roots: [home.appendingPathComponent("Library/Caches")],
                category: category,
                excludingNames: Set(excluded.map { $0.lowercased() })
            )
        case .mailFiles:
            items = topLevelItems(
                roots: [
                    home.appendingPathComponent("Library/Mail Downloads"),
                    home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
                ],
                category: category
            )
        case .trashBins:
            items = topLevelItems(roots: [home.appendingPathComponent(".Trash")], category: category)
        case .largeOldFiles:
            items = largeAndOldFiles(home: home, now: now)
        case .aiApps:
            items = targetedItems([
                Target(home.appendingPathComponent(".ollama/logs").path),
                Target(home.appendingPathComponent("Library/Caches/ollama").path),
                Target(home.appendingPathComponent("Library/Caches/com.electron.ollama").path),
                Target(home.appendingPathComponent("Library/WebKit/com.electron.ollama").path),
                Target(home.appendingPathComponent("Library/Saved Application State/com.electron.ollama.savedState").path),
                Target(home.appendingPathComponent(".ollama/history").path, selected: false),
                Target(home.appendingPathComponent(".lmstudio/server-logs").path),
                Target(home.appendingPathComponent(".lmstudio/conversations").path, selected: false)
            ], category: category)
        case .xcodeJunk:
            items = targetedItems([
                Target(home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path),
                Target(home.appendingPathComponent("Library/Developer/Xcode/Archives").path, selected: false),
                Target(home.appendingPathComponent("Library/Developer/CoreSimulator/Caches").path),
                Target(home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode").path),
                Target(home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport").path),
                Target(home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport").path),
                Target(home.appendingPathComponent("Library/Developer/Xcode/tvOS DeviceSupport").path),
                Target(home.appendingPathComponent("Library/Developer/XCTestDevices").path),
                Target(home.appendingPathComponent("Library/Developer/Xcode/UserData/Previews").path),
                Target(home.appendingPathComponent("Library/Caches/org.swift.swiftpm").path)
            ], category: category)
        case .brewCache:
            items = targetedItems([
                Target(home.appendingPathComponent("Library/Caches/Homebrew").path),
                Target(home.appendingPathComponent("Library/Logs/Homebrew").path)
            ], category: category)
        case .nodeCache:
            items = targetedItems([
                Target(home.appendingPathComponent(".npm/_cacache").path),
                Target(home.appendingPathComponent("Library/Caches/npm").path),
                Target(home.appendingPathComponent("Library/Caches/Yarn").path),
                Target(home.appendingPathComponent("Library/pnpm/store").path),
                Target(home.appendingPathComponent(".pnpm-store").path),
                Target(home.appendingPathComponent(".cache/yarn").path)
            ], category: category)
        case .dockerCache:
            items = targetedItems([
                Target(home.appendingPathComponent("Library/Caches/com.docker.docker").path),
                Target(home.appendingPathComponent("Library/Containers/com.docker.docker/Data/log").path),
                Target(home.appendingPathComponent(".docker/buildx/activity").path)
            ], category: category)
        }
        var seen = Set<String>()
        return items
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func topLevelItems(
        roots: [URL],
        category: CleanupCategory,
        excludingNames: Set<String> = [],
        ownedByCurrentUserOnly: Bool = false
    ) -> [CleanupItem] {
        let fileManager = FileManager.default
        var items: [CleanupItem] = []
        for root in roots {
            if Task.isCancelled { break }
            guard let children = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children where !excludingNames.contains(child.lastPathComponent.lowercased()) {
                if Task.isCancelled { break }
                if ownedByCurrentUserOnly && !isOwnedByCurrentUser(child) { continue }
                if let item = makeItem(child, category: category, selected: true, minimumBytes: 1) {
                    items.append(item)
                }
            }
        }
        return items
    }

    static func isOwnedByCurrentUser(_ url: URL) -> Bool {
        guard FileManager.default.isDeletableFile(atPath: url.path),
              let owner = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.ownerAccountID] as? NSNumber else { return false }
        return owner.uint32Value == getuid()
    }

    private static func targetedItems(_ targets: [Target], category: CleanupCategory) -> [CleanupItem] {
        targets.compactMap {
            makeItem(URL(fileURLWithPath: $0.path), category: category, selected: $0.selected, minimumBytes: $0.minimumBytes)
        }
    }

    private static func makeItem(
        _ url: URL,
        category: CleanupCategory,
        selected: Bool,
        minimumBytes: Int64
    ) -> CleanupItem? {
        let standardized = url.standardizedFileURL
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: standardized.path) else { return nil }
        let values = try? standardized.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
        let resolved = standardized.resolvingSymlinksInPath().standardizedFileURL
        if values?.isSymbolicLink != true, resolved.path != standardized.path { return nil }
        let measured = AppUninstaller.measure(standardized)
        guard measured.bytes >= minimumBytes else { return nil }
        return CleanupItem(
            url: standardized,
            category: category,
            bytes: measured.bytes,
            fileCount: measured.files,
            isDirectory: values?.isDirectory ?? false,
            lastModified: values?.contentModificationDate,
            isSelectedByDefault: selected
        )
    }

    private static func largeAndOldFiles(home: URL, now: Date) -> [CleanupItem] {
        let fileManager = FileManager.default
        let minimumLargeBytes: Int64 = 100 * 1024 * 1024
        let minimumOldBytes: Int64 = 10 * 1024 * 1024
        let oldDate = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? Date.distantPast
        let roots = ["Desktop", "Documents", "Downloads"].map(home.appendingPathComponent)
        var items: [CleanupItem] = []
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            var finished = false
            while !finished {
                if Task.isCancelled { return items }
                finished = autoreleasepool {
                    guard let url = enumerator.nextObject() as? URL else { return true }
                    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]),
                          values.isRegularFile == true,
                          values.isSymbolicLink != true else { return false }
                    let bytes = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                    let date = values.contentModificationDate
                    guard bytes >= minimumLargeBytes || (bytes >= minimumOldBytes && (date ?? now) < oldDate) else { return false }
                    items.append(CleanupItem(
                        url: url.standardizedFileURL,
                        category: .largeOldFiles,
                        bytes: bytes,
                        fileCount: 1,
                        isDirectory: false,
                        lastModified: date,
                        isSelectedByDefault: false
                    ))
                    return false
                }
            }
        }
        return items
    }
}
