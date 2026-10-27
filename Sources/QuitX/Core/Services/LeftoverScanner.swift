import Foundation

enum LeftoverScanner {
    static func candidateBundleIdentifier(from fileName: String, rule: LeftoverSearchRoot.Rule) -> String? {
        var value = fileName.lowercased()
        let removableExtensions = ["plist", "savedstate", "binarycookies", "log", "db", "sqlite"]
        while let dot = value.lastIndex(of: ".") {
            let suffix = String(value[value.index(after: dot)...])
            guard removableExtensions.contains(suffix) else { break }
            value = String(value[..<dot])
        }
        if value.hasPrefix("group.") { value.removeFirst("group.".count) }
        if rule == .groupContainer {
            let parts = value.split(separator: ".")
            if parts.count > 3, parts[0].count == 10, parts[0].allSatisfy({ $0.isLetter || $0.isNumber }) {
                value = parts.dropFirst().joined(separator: ".")
            }
        }
        guard value.contains("."), value.split(separator: ".").count >= 3 else { return nil }
        let deniedPrefixes = ["com.apple.", "group.com.apple.", "systemgroup.com.apple."]
        guard !deniedPrefixes.contains(where: value.hasPrefix) else { return nil }
        return value
    }

    static func belongsToInstalledApp(_ identifier: String, installed: Set<String>) -> Bool {
        installed.contains { appIdentifier in
            identifier == appIdentifier
                || identifier.hasPrefix(appIdentifier + ".")
                || appIdentifier.hasPrefix(identifier + ".")
        }
    }

    static func scan(
        installedBundleIdentifiers: Set<String>,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) async -> [LeftoverItem] {
        await Task.detached(priority: .userInitiated) {
            let normalizedInstalled = Set(installedBundleIdentifiers.map { $0.lowercased() })
            let library = home.standardizedFileURL.appendingPathComponent("Library").path + "/"
            let roots = AppUninstaller.searchRoots(
                home: home,
                temporaryDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
            ).filter {
                $0.url.standardizedFileURL.path.hasPrefix(library)
                    && $0.rule != .bundleOrName
                    && $0.rule != .diagnosticReport
            }
            let fileManager = FileManager.default
            var items: [LeftoverItem] = []
            var seen = Set<String>()
            for root in roots {
                if Task.isCancelled { break }
                guard let names = try? fileManager.contentsOfDirectory(atPath: root.url.path) else { continue }
                for name in names {
                    if Task.isCancelled { break }
                    guard let identifier = candidateBundleIdentifier(from: name, rule: root.rule),
                          !belongsToInstalledApp(identifier, installed: normalizedInstalled) else { continue }
                    let url = root.url.appendingPathComponent(name).standardizedFileURL
                    guard seen.insert(url.path).inserted else { continue }
                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    guard values?.isSymbolicLink != true else { continue }
                    let measured = AppUninstaller.measure(url)
                    items.append(LeftoverItem(
                        url: url,
                        category: root.category,
                        bytes: measured.bytes,
                        fileCount: measured.files,
                        isDirectory: values?.isDirectory ?? false,
                        targetID: identifier
                    ))
                }
            }
            return items.sorted {
                if $0.bytes != $1.bytes { return $0.bytes > $1.bytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }.value
    }
}
