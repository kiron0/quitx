import AppKit
import Foundation

final class StashService {
    static let shared = StashService()
    private init() {}

    private static let stashKey = "QuitXStashData"

    func stash(apps: [AppInfo]) async -> Bool {
        let entries = apps.map { StashEntry(name: $0.name, bundleId: $0.bundleId) }
        let data = StashData(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            apps: entries
        )
        guard let json = try? JSONEncoder().encode(data) else { return false }
        UserDefaults.standard.set(json, forKey: Self.stashKey)

        let results = await QuitService.shared.quit(apps: apps, force: false)
        return results.allSatisfy { $0.success }
    }

    func restore() async -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.stashKey),
              let stash = try? JSONDecoder().decode(StashData.self, from: data) else {
            return false
        }
        UserDefaults.standard.removeObject(forKey: Self.stashKey)

        var allOk = true
        for entry in stash.apps {
            guard let bundleId = entry.bundleId,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                allOk = false
                continue
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
        return allOk
    }

    var hasStash: Bool {
        UserDefaults.standard.data(forKey: Self.stashKey) != nil
    }
}
