import AppKit
import Foundation

struct RecentlyQuitEntry: Codable, Equatable, Sendable {
    let name: String
    let bundleId: String?
    let quitAt: Date
}

enum RecentlyQuitStore {
    static let maxCount = 20

    static func inserting(_ entries: [RecentlyQuitEntry], entry: RecentlyQuitEntry) -> [RecentlyQuitEntry] {
        var rest = entries.filter { !isSameApp($0, entry) }
        rest.insert(entry, at: 0)
        return Array(rest.prefix(maxCount))
    }

    static func isSameApp(_ lhs: RecentlyQuitEntry, _ rhs: RecentlyQuitEntry) -> Bool {
        if let l = lhs.bundleId, let r = rhs.bundleId {
            return l.lowercased() == r.lowercased()
        }
        return lhs.name.lowercased() == rhs.name.lowercased()
    }
}

@MainActor
final class RecentlyQuitService {
    static let shared = RecentlyQuitService()
    private let defaultsKey = QuitXConstants.UserDefaultsKeys.recentlyQuit

    private(set) var entries: [RecentlyQuitEntry] = []

    private init() {
        load()
    }

    func record(app: AppInfo) {
        let entry = RecentlyQuitEntry(name: app.name, bundleId: app.bundleId, quitAt: Date())
        entries = RecentlyQuitStore.inserting(entries, entry: entry)
        save()
    }

    func record(apps: [AppInfo]) {
        guard !apps.isEmpty else { return }
        var current = entries
        for app in apps {
            let entry = RecentlyQuitEntry(name: app.name, bundleId: app.bundleId, quitAt: Date())
            current = RecentlyQuitStore.inserting(current, entry: entry)
        }
        entries = current
        save()
    }

    func clear() {
        entries = []
        save()
    }

    var menuKey: String {
        entries.map { "\($0.bundleId ?? $0.name)@\($0.quitAt.timeIntervalSince1970)" }.joined(separator: "|")
    }

    @discardableResult
    func reopen(_ entry: RecentlyQuitEntry) -> Bool {
        guard let bundleId = entry.bundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else { return false }
        NSWorkspace.shared.open(url)
        return true
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([RecentlyQuitEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = Array(decoded.prefix(RecentlyQuitStore.maxCount))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
