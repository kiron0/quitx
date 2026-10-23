import Foundation

enum DockCleaner {
    struct App: Sendable, Equatable {
        let bundleIdentifier: String
        let bundlePaths: [String]
    }

    static let domain = "com.apple.dock"
    static let tileKeys = ["persistent-apps", "recent-apps"]

    static func normalizedPath(_ value: String) -> String {
        var path = value
        if let url = URL(string: value), url.isFileURL {
            path = url.path
        }
        path = (path as NSString).standardizingPath
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static func tileMatches(_ tile: [String: Any], apps: [App]) -> Bool {
        guard let data = tile["tile-data"] as? [String: Any] else { return false }
        let bundleIdentifier = (data["bundle-identifier"] as? String)?.lowercased()
        let fileData = data["file-data"] as? [String: Any]
        let tilePath = (fileData?["_CFURLString"] as? String).map(normalizedPath)
        return apps.contains { app in
            if let bundleIdentifier, bundleIdentifier == app.bundleIdentifier.lowercased() { return true }
            guard let tilePath else { return false }
            return app.bundlePaths.contains { normalizedPath($0) == tilePath }
        }
    }

    static func removing(_ apps: [App], from tiles: [[String: Any]]) -> [[String: Any]]? {
        let kept = tiles.filter { !tileMatches($0, apps: apps) }
        return kept.count == tiles.count ? nil : kept
    }

    @discardableResult
    static func remove(_ apps: [App]) -> Bool {
        guard !apps.isEmpty else { return false }
        let domainRef = domain as CFString
        var changed = false
        for key in tileKeys {
            let value = CFPreferencesCopyValue(key as CFString, domainRef, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            guard let tiles = value as? [[String: Any]], let kept = removing(apps, from: tiles) else { continue }
            CFPreferencesSetValue(key as CFString, kept as NSArray as CFArray, domainRef, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            changed = true
        }
        guard changed else { return false }
        CFPreferencesSynchronize(domainRef, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return true
        }
        return true
    }
}
