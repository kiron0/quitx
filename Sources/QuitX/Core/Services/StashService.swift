import AppKit
import Foundation

final class StashService {
    static let shared = StashService()
    private init() {}

    private var stashURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent(".local/share/quitx", isDirectory: true)
            .appendingPathComponent("stash.json")
    }

    func stash(apps: [AppInfo]) async -> Bool {
        let entries = apps.map { StashEntry(name: $0.name, bundleId: $0.bundleId) }
        let data = StashData(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            apps: entries
        )
        guard let json = try? JSONEncoder().encode(data) else { return false }

        do {
            let dir = stashURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try json.write(to: stashURL, options: .atomic)
        } catch { return false }

        let results = await QuitService.shared.quit(apps: apps, force: false)
        return results.allSatisfy(\.success)
    }

    func restore() async -> Bool {
        guard let json = try? Data(contentsOf: stashURL),
              let stash = try? JSONDecoder().decode(StashData.self, from: json) else {
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
            _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
        return allOk
    }

    var hasStash: Bool {
        FileManager.default.fileExists(atPath: stashURL.path)
    }
}
