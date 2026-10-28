import Foundation

enum QuickCleanSafety: String, Sendable {
    case safe = "Safe"
    case caution = "Caution"
}

struct QuickCleanGroup: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case userCaches
        case userLogs
        case developerCaches
        case trash
    }

    let kind: Kind
    let items: [CleanupItem]

    var id: Kind { kind }
    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

    var title: String {
        switch kind {
        case .userCaches: "User Caches"
        case .userLogs: "User Logs"
        case .developerCaches: "Developer Caches"
        case .trash: "Trash"
        }
    }

    var detail: String {
        switch kind {
        case .userCaches: "App and browser caches in ~/Library/Caches. Apps rebuild them as needed."
        case .userLogs: "Old log files in ~/Library/Logs. Apps start fresh logs."
        case .developerCaches: "npm, Yarn, pnpm, Homebrew, SwiftPM and Xcode build caches. Rebuilt on the next install or build."
        case .trash: "Files already in your Trash. They can't be recovered afterwards."
        }
    }

    var safety: QuickCleanSafety {
        kind == .trash ? .caution : .safe
    }

    var isSelectedByDefault: Bool {
        safety == .safe
    }
}

enum QuickCleanService {
    static func scan(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date()
    ) async -> [QuickCleanGroup] {
        await detachedCancellable(priority: .utility) {
            scanSynchronously(home: home.standardizedFileURL, now: now)
        }
    }

    static func scanSynchronously(home: URL, now: Date) -> [QuickCleanGroup] {
        var seen = Set<String>()
        var groups: [QuickCleanGroup] = []
        for kind in QuickCleanGroup.Kind.allCases {
            if Task.isCancelled { break }
            let unique = items(for: kind, home: home, now: now).filter { seen.insert($0.id).inserted }
            guard !unique.isEmpty else { continue }
            groups.append(QuickCleanGroup(kind: kind, items: unique.sorted { $0.bytes > $1.bytes }))
        }
        return groups
    }

    static func items(for kind: QuickCleanGroup.Kind, home: URL, now: Date) -> [CleanupItem] {
        switch kind {
        case .userCaches:
            return CleanupService.scanSynchronously(.userCache, home: home, now: now)
        case .userLogs:
            return CleanupService.topLevelItems(
                roots: [home.appendingPathComponent("Library/Logs")],
                category: .systemJunk
            )
        case .developerCaches:
            let xcode = CleanupService.scanSynchronously(.xcodeJunk, home: home, now: now).filter { item in
                item.isSelectedByDefault && isRebuildableXcodeCache(item.url)
            }
            return CleanupService.scanSynchronously(.nodeCache, home: home, now: now)
                + CleanupService.scanSynchronously(.brewCache, home: home, now: now)
                + xcode
        case .trash:
            return CleanupService.scanSynchronously(.trashBins, home: home, now: now)
        }
    }

    static func isRebuildableXcodeCache(_ url: URL) -> Bool {
        let path = url.path
        return path.hasSuffix("/DerivedData")
            || path.hasSuffix("/CoreSimulator/Caches")
            || path.hasSuffix("/Caches/com.apple.dt.Xcode")
            || path.hasSuffix("/Caches/org.swift.swiftpm")
            || path.hasSuffix("/UserData/Previews")
    }

    static func defaultSelection(for groups: [QuickCleanGroup]) -> Set<QuickCleanGroup.Kind> {
        Set(groups.filter(\.isSelectedByDefault).map(\.kind))
    }

    static func bytes(of groups: [QuickCleanGroup], selected: Set<QuickCleanGroup.Kind>) -> Int64 {
        groups.filter { selected.contains($0.kind) }.reduce(0) { $0 + $1.bytes }
    }

    static func urls(of groups: [QuickCleanGroup], selected: Set<QuickCleanGroup.Kind>) -> [URL] {
        groups.filter { selected.contains($0.kind) }.flatMap { $0.items.map(\.url) }
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }
}
