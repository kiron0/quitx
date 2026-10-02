import AppKit
import Foundation

final class StashService {
    static let shared = StashService()
    private init() {}

    private static let stashKey = "QuitXStashData"

    func stash(apps: [AppInfo]) async -> Bool {
        let restorableApps = apps.filter { $0.bundleId != nil }
        guard !restorableApps.isEmpty else { return false }

        let entries = restorableApps.map { StashEntry(name: $0.name, bundleId: $0.bundleId) }
        let data = StashData(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            apps: entries
        )
        guard let json = try? JSONEncoder().encode(data) else { return false }
        UserDefaults.standard.set(json, forKey: Self.stashKey)

        let results = await QuitService.shared.quit(apps: restorableApps, force: false)
        let successfulIds = Set(results.filter(\.success).map { $0.app.id })
        let successfulEntries = restorableApps
            .filter { successfulIds.contains($0.id) }
            .map { StashEntry(name: $0.name, bundleId: $0.bundleId) }

        guard !successfulEntries.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.stashKey)
            return false
        }

        if successfulEntries.count != entries.count {
            let partialStash = StashData(timestamp: data.timestamp, apps: successfulEntries)
            guard let partialJSON = try? JSONEncoder().encode(partialStash) else { return false }
            UserDefaults.standard.set(partialJSON, forKey: Self.stashKey)
        }
        return successfulEntries.count == entries.count
    }

    func restore() async -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.stashKey),
              let stash = try? JSONDecoder().decode(StashData.self, from: data) else {
            return false
        }
        var allOk = true
        for entry in stash.apps {
            guard let bundleId = entry.bundleId,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                allOk = false
                continue
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            } catch {
                allOk = false
            }
        }
        if allOk {
            UserDefaults.standard.removeObject(forKey: Self.stashKey)
        }
        return allOk
    }

    var hasStash: Bool {
        UserDefaults.standard.data(forKey: Self.stashKey) != nil
    }
}
