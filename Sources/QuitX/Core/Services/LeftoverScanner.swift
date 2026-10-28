import AppKit
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
        let parts = value.split(separator: ".")
        if parts.count > 3, parts[0].count == 10, parts[0].allSatisfy({ $0.isLetter || $0.isNumber }),
           parts[0].contains(where: \.isNumber) || rule == .groupContainer {
            value = parts.dropFirst().joined(separator: ".")
        }
        if value.hasPrefix("group.") { value.removeFirst("group.".count) }
        guard value.contains("."), value.split(separator: ".").count >= 3 else { return nil }
        let deniedPrefixes = ["com.apple.", "group.com.apple.", "systemgroup.com.apple.", "homebrew.", "org.macports."]
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

    static func vendor(of identifier: String) -> String {
        identifier.split(separator: ".").prefix(2).joined(separator: ".")
    }

    static func isSelectedByDefault(identifier: String, category: LeftoverCategory, installedVendors: Set<String>) -> Bool {
        switch category {
        case .containers, .launchItems, .applicationSupport:
            return false
        default:
            return !installedVendors.contains(vendor(of: identifier))
        }
    }

    static func scan(
        installedBundleIdentifiers: Set<String>,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) async -> [LeftoverItem] {
        let normalizedInstalled = Set(installedBundleIdentifiers.map { $0.lowercased() })
        let candidates = await detachedCancellable(priority: .userInitiated) { () -> [(url: URL, identifier: String, category: LeftoverCategory)] in
            let library = home.standardizedFileURL.appendingPathComponent("Library").path + "/"
            let roots = AppUninstaller.searchRoots(
                home: home,
                temporaryDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
            ).filter {
                $0.url.standardizedFileURL.path.hasPrefix(library)
                    && $0.rule != .bundleOrName
                    && $0.rule != .diagnosticReport
            }
            var found: [(url: URL, identifier: String, category: LeftoverCategory)] = []
            var seen = Set<String>()
            for root in roots {
                if Task.isCancelled { break }
                guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.url.path) else { continue }
                for name in names {
                    guard let identifier = candidateBundleIdentifier(from: name, rule: root.rule),
                          !belongsToInstalledApp(identifier, installed: normalizedInstalled) else { continue }
                    let url = root.url.appendingPathComponent(name).standardizedFileURL
                    guard seen.insert(url.path).inserted else { continue }
                    found.append((url, identifier, root.category))
                }
            }
            return found
        }
        guard !Task.isCancelled, !candidates.isEmpty else { return [] }

        let registered = await MainActor.run { () -> Set<String> in
            var known = Set<String>()
            for identifier in Set(candidates.map(\.identifier)) {
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil {
                    known.insert(identifier)
                }
            }
            return known
        }
        let vendors = Set(normalizedInstalled.map(vendor(of:)))

        return await detachedCancellable(priority: .userInitiated) { () -> [LeftoverItem] in
            var items: [LeftoverItem] = []
            for candidate in candidates where !registered.contains(candidate.identifier) {
                if Task.isCancelled { break }
                let values = try? candidate.url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
                guard values?.isSymbolicLink != true else { continue }
                let measured = AppUninstaller.measure(candidate.url)
                items.append(LeftoverItem(
                    url: candidate.url,
                    category: candidate.category,
                    bytes: measured.bytes,
                    fileCount: measured.files,
                    isDirectory: values?.isDirectory ?? false,
                    targetID: candidate.identifier,
                    lastModified: values?.contentModificationDate,
                    selectedByDefault: isSelectedByDefault(identifier: candidate.identifier, category: candidate.category, installedVendors: vendors)
                ))
            }
            return items.sorted {
                if $0.bytes != $1.bytes { return $0.bytes > $1.bytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}
