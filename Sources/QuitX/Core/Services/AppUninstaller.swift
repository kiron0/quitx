import AppKit
import Darwin
import Foundation

enum LeftoverCategory: String, CaseIterable, Sendable {
    case application
    case applicationSupport
    case caches
    case preferences
    case containers
    case savedState
    case logs
    case launchItems
    case other

    var title: String {
        switch self {
        case .application: return "Application"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .preferences: return "Preferences"
        case .containers: return "Containers"
        case .savedState: return "Saved State"
        case .logs: return "Logs"
        case .launchItems: return "Launch Items"
        case .other: return "Other Files"
        }
    }

    var symbolName: String {
        switch self {
        case .application: return "app.fill"
        case .applicationSupport: return "folder.fill"
        case .caches: return "internaldrive.fill"
        case .preferences: return "gearshape.fill"
        case .containers: return "shippingbox.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .logs: return "doc.text.fill"
        case .launchItems: return "power"
        case .other: return "doc.fill"
        }
    }

    var tint: NSColor {
        switch self {
        case .application: return .systemBlue
        case .applicationSupport: return .systemTeal
        case .caches: return .systemOrange
        case .preferences: return .systemGray
        case .containers: return .systemIndigo
        case .savedState: return .systemPurple
        case .logs: return .systemBrown
        case .launchItems: return .systemRed
        case .other: return .systemGreen
        }
    }
}

struct LeftoverItem: Identifiable, Hashable, Sendable {
    let url: URL
    let category: LeftoverCategory
    let bytes: Int64
    let fileCount: Int
    var isDirectory: Bool = false
    var targetID: String = ""

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

struct LeftoverGroup: Identifiable {
    enum Kind {
        case category(LeftoverCategory)
        case app(UninstallTarget)
    }

    let id: String
    let kind: Kind
    let items: [LeftoverItem]

    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var files: Int { items.reduce(0) { $0 + $1.fileCount } }

    var title: String {
        switch kind {
        case let .category(category): return category.title
        case let .app(target): return target.name
        }
    }

    static func grouped(_ items: [LeftoverItem], targets: [UninstallTarget]) -> [LeftoverGroup] {
        if targets.count > 1 {
            return targets.compactMap { target -> LeftoverGroup? in
                let members = items.filter { $0.targetID == target.id }
                return members.isEmpty ? nil : LeftoverGroup(id: "app." + target.id, kind: .app(target), items: members)
            }
        }
        return LeftoverCategory.allCases.compactMap { category -> LeftoverGroup? in
            let members = items.filter { $0.category == category }
            return members.isEmpty ? nil : LeftoverGroup(id: "category." + category.rawValue, kind: .category(category), items: members)
        }
    }
}

struct UninstallTarget: Sendable, Hashable, Identifiable {
    let name: String
    let bundleIdentifier: String
    let bundleURL: URL
    let executableName: String?

    var id: String { bundleIdentifier.lowercased() }
}

struct LeftoverSearchRoot: Sendable, Equatable {
    enum Rule: Sendable, Equatable {
        case bundleOrName
        case bundleOnly
        case groupContainer
        case diagnosticReport
    }

    let url: URL
    let category: LeftoverCategory
    let rule: Rule
}

enum AppUninstaller {
    static let minimumNameLength = 4

    static let genericNames: Set<String> = [
        "app", "apps", "application", "applications", "cache", "caches", "data", "default", "helper", "helpers",
        "library", "logs", "preferences", "shared", "support", "temp", "tmp", "user", "users", "update", "updater",
        "apple", "google", "microsoft", "adobe", "mozilla", "documents", "desktop", "downloads", "music", "photos",
        "notes", "books", "maps", "mail", "messages", "calendar", "reminders", "safari", "terminal", "finder", "system"
    ]

    static func uninstallBlockReason(bundleIdentifier: String?, bundleURL: URL?) -> String? {
        guard let bundleURL, bundleURL.pathExtension.lowercased() == "app" else {
            return "Only apps with an app bundle can be uninstalled."
        }
        let path = bundleURL.standardizedFileURL.path
        let bid = (bundleIdentifier ?? "").lowercased()
        if bid.isEmpty { return "This app has no bundle identifier." }
        if bid.hasPrefix("com.apple.") { return "Apple apps are part of macOS." }
        if QuitXConstants.supportedBundleIdentifiers.contains(where: { $0.lowercased() == bid }) {
            return "QuitX can't uninstall itself."
        }
        if isTranslocated(bundleURL) { return "Move this app to Applications first." }
        let systemPrefixes = ["/System/", "/Library/Apple/", "/usr/", "/bin/", "/sbin/", "/private/var/", "/Library/Developer/CommandLineTools/"]
        if systemPrefixes.contains(where: { path.hasPrefix($0) }) { return "This app is part of macOS." }
        let components = bundleURL.standardizedFileURL.pathComponents.dropLast()
        if components.contains(where: { $0.lowercased().hasSuffix(".app") }) {
            return "This is a helper inside another app."
        }
        return nil
    }

    static func isTranslocated(_ url: URL) -> Bool {
        url.path.contains("/AppTranslocation/")
    }

    @MainActor
    static func resolvedBundleURL(pid: pid_t?, bundleIdentifier: String?) -> URL? {
        let running = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL }
        let installed = bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        if let running, !isTranslocated(running) { return running.standardizedFileURL }
        return (installed ?? running)?.standardizedFileURL
    }

    @MainActor
    static func target(name: String, pid: pid_t?, bundleIdentifier: String?) -> UninstallTarget? {
        guard let bundleIdentifier,
              let url = resolvedBundleURL(pid: pid, bundleIdentifier: bundleIdentifier) else { return nil }
        return target(name: name, bundleIdentifier: bundleIdentifier, bundleURL: url)
    }

    static func target(name: String, bundleIdentifier: String, bundleURL: URL) -> UninstallTarget? {
        let url = bundleURL.standardizedFileURL
        guard canUninstall(bundleIdentifier: bundleIdentifier, bundleURL: url) else { return nil }
        let executable = Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return UninstallTarget(name: name, bundleIdentifier: bundleIdentifier, bundleURL: url, executableName: executable)
    }

    static func canUninstall(bundleIdentifier: String?, bundleURL: URL?) -> Bool {
        uninstallBlockReason(bundleIdentifier: bundleIdentifier, bundleURL: bundleURL) == nil
    }

    static func normalized(_ value: String) -> String {
        value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    static func matchNames(for target: UninstallTarget) -> Set<String> {
        var names: Set<String> = []
        let candidates = [target.name, target.bundleURL.deletingPathExtension().lastPathComponent, target.executableName ?? ""]
        for candidate in candidates {
            let n = normalized(candidate)
            if n.count >= minimumNameLength, !genericNames.contains(n) {
                names.insert(n)
            }
        }
        return names
    }

    static func stem(of fileName: String) -> String {
        var name = fileName
        let knownExtensions = ["plist", "savedstate", "binarycookies", "log", "ips", "crash", "diag", "lockfile", "db", "sqlite"]
        while let dot = name.lastIndex(of: "."), knownExtensions.contains(String(name[name.index(after: dot)...]).lowercased()) {
            name = String(name[..<dot])
        }
        return name
    }

    static func matches(fileName: String, rule: LeftoverSearchRoot.Rule, bundleIdentifier: String, names: Set<String>) -> Bool {
        let bid = bundleIdentifier.lowercased()
        guard bid.count >= 5, bid.contains(".") else { return false }
        let lower = fileName.lowercased()
        let base = stem(of: lower)

        switch rule {
        case .groupContainer:
            return base == bid || base.hasSuffix("." + bid) || base.hasPrefix("group." + bid)
        case .diagnosticReport:
            guard !names.isEmpty else { return false }
            let prefix = normalized(String(lower.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? ""))
            return names.contains(prefix) && (lower.hasSuffix(".ips") || lower.hasSuffix(".crash") || lower.hasSuffix(".diag") || lower.hasSuffix(".hang"))
        case .bundleOnly, .bundleOrName:
            if base == bid || base.hasPrefix(bid + ".") { return true }
            if rule == .bundleOrName, names.contains(normalized(base)) { return true }
            return false
        }
    }

    static func searchRoots(home: URL, temporaryDirectory: URL) -> [LeftoverSearchRoot] {
        let lib = home.appendingPathComponent("Library")
        func user(_ path: String, _ category: LeftoverCategory, _ rule: LeftoverSearchRoot.Rule) -> LeftoverSearchRoot {
            LeftoverSearchRoot(url: lib.appendingPathComponent(path), category: category, rule: rule)
        }
        func system(_ path: String, _ category: LeftoverCategory, _ rule: LeftoverSearchRoot.Rule) -> LeftoverSearchRoot {
            LeftoverSearchRoot(url: URL(fileURLWithPath: path), category: category, rule: rule)
        }
        return [
            user("Application Support", .applicationSupport, .bundleOrName),
            user("Application Scripts", .containers, .bundleOnly),
            user("Containers", .containers, .bundleOnly),
            user("Group Containers", .containers, .groupContainer),
            user("Caches", .caches, .bundleOrName),
            user("HTTPStorages", .caches, .bundleOnly),
            user("WebKit", .caches, .bundleOnly),
            user("Cookies", .caches, .bundleOnly),
            user("Preferences", .preferences, .bundleOnly),
            user("Preferences/ByHost", .preferences, .bundleOnly),
            user("Saved Application State", .savedState, .bundleOnly),
            user("Logs", .logs, .bundleOrName),
            user("Logs/DiagnosticReports", .logs, .diagnosticReport),
            user("LaunchAgents", .launchItems, .bundleOnly),
            system("/Library/Application Support", .applicationSupport, .bundleOrName),
            system("/Library/Caches", .caches, .bundleOnly),
            system("/Library/Preferences", .preferences, .bundleOnly),
            system("/Library/Logs", .logs, .bundleOnly),
            system("/Library/LaunchAgents", .launchItems, .bundleOnly),
            system("/Library/LaunchDaemons", .launchItems, .bundleOnly),
            system("/Library/PrivilegedHelperTools", .launchItems, .bundleOnly),
            LeftoverSearchRoot(url: temporaryDirectory, category: .other, rule: .bundleOnly),
            system("/private/tmp", .other, .bundleOnly),
        ]
    }

    static func appCopies(for target: UninstallTarget) -> [URL] {
        var urls: [URL] = [target.bundleURL.standardizedFileURL]
        for url in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: target.bundleIdentifier) {
            let standardized = url.standardizedFileURL
            guard canUninstall(bundleIdentifier: target.bundleIdentifier, bundleURL: standardized) else { continue }
            guard !standardized.path.contains("/.Trash/") else { continue }
            guard !standardized.path.hasPrefix("/Volumes/") else { continue }
            if !urls.contains(standardized) { urls.append(standardized) }
        }
        return urls
    }

    static func scan(target: UninstallTarget, home: URL = FileManager.default.homeDirectoryForCurrentUser, temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())) async -> [LeftoverItem] {
        let copies = await MainActor.run { appCopies(for: target) }
        return await Task.detached(priority: .userInitiated) {
            var found: [(URL, LeftoverCategory)] = copies.map { ($0, .application) }
            let names = matchNames(for: target)
            let fm = FileManager.default
            var seen = Set(copies.map(\.path))
            for root in searchRoots(home: home, temporaryDirectory: temporaryDirectory.standardizedFileURL) {
                guard let entries = try? fm.contentsOfDirectory(atPath: root.url.path) else { continue }
                for entry in entries where matches(fileName: entry, rule: root.rule, bundleIdentifier: target.bundleIdentifier, names: names) {
                    let url = root.url.appendingPathComponent(entry).standardizedFileURL
                    guard !seen.contains(url.path) else { continue }
                    seen.insert(url.path)
                    found.append((url, root.category))
                }
            }
            return found.map { entry -> LeftoverItem in
                let (url, category) = entry
                let measured = measure(url)
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return LeftoverItem(url: url, category: category, bytes: measured.bytes, fileCount: measured.files, isDirectory: isDirectory, targetID: target.id)
            }
        }.value
    }

    static func scan(targets: [UninstallTarget]) async -> [LeftoverItem] {
        var collected: [LeftoverItem] = []
        var seen = Set<String>()
        for target in targets {
            if Task.isCancelled { break }
            for item in await scan(target: target) where !seen.contains(item.id) {
                seen.insert(item.id)
                collected.append(item)
            }
        }
        return collected
    }

    static func measure(_ url: URL) -> (bytes: Int64, files: Int) {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        func size(_ values: URLResourceValues?) -> Int64 {
            Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        let rootValues = try? url.resourceValues(forKeys: keys.union([.isDirectoryKey, .isPackageKey]))
        guard rootValues?.isDirectory == true, rootValues?.isSymbolicLink != true else {
            return (size(rootValues), 1)
        }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else {
            return (0, 1)
        }
        var bytes: Int64 = 0
        var files = 0
        for case let child as URL in enumerator {
            if Task.isCancelled { break }
            let values = try? child.resourceValues(forKeys: keys)
            if values?.isRegularFile == true || values?.isSymbolicLink == true {
                bytes += size(values)
                files += 1
            }
        }
        return (bytes, max(files, 1))
    }

    struct RemovalFailure: Sendable, Equatable {
        let url: URL
        let message: String
    }

    struct RemovalResult: Sendable {
        var trashed: [URL] = []
        var failed: [RemovalFailure] = []
    }

    static func isInside(_ path: String?, bundles: [URL]) -> Bool {
        guard let path, !path.isEmpty else { return false }
        return bundles.contains { QuitService.isExecutablePath(path, insideContentsOf: $0) }
    }

    @MainActor
    static func runningApplications(for target: UninstallTarget, bundles: [URL]) -> [NSRunningApplication] {
        let own = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter { app in
            guard !app.isTerminated, app.processIdentifier > 0, app.processIdentifier != own else { return false }
            if app.bundleIdentifier?.lowercased() == target.id { return true }
            return isInside(app.executableURL?.path, bundles: bundles)
        }
    }

    @MainActor
    static func isRunning(_ target: UninstallTarget, bundles: [URL]) -> Bool {
        !runningApplications(for: target, bundles: bundles).isEmpty
    }

    static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, 4096)
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    @MainActor
    static func forceQuit(_ target: UninstallTarget, bundles: [URL], timeout: TimeInterval = 5) async -> Bool {
        let own = ProcessInfo.processInfo.processIdentifier
        for app in runningApplications(for: target, bundles: bundles) {
            app.forceTerminate()
        }
        let processPaths = await Task.detached(priority: .userInitiated) { AppListService.runningProcessPaths() }.value
        for (pid, path) in processPaths where pid > 0 && pid != own && isInside(path, bundles: bundles) {
            guard QuitService.processIsRunning(pid), isInside(executablePath(pid: pid), bundles: bundles) else { continue }
            _ = Darwin.kill(pid, SIGKILL)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isRunning(target, bundles: bundles) { return true }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return !isRunning(target, bundles: bundles)
    }

    static func moveToTrash(_ urls: [URL]) async -> RemovalResult {
        var result = await Task.detached(priority: .userInitiated) { () -> RemovalResult in
            var partial = RemovalResult()
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    partial.trashed.append(url)
                } catch {
                    if FileManager.default.fileExists(atPath: url.path) {
                        partial.failed.append(RemovalFailure(url: url, message: error.localizedDescription))
                    } else {
                        partial.trashed.append(url)
                    }
                }
            }
            return partial
        }.value
        guard !result.failed.isEmpty else { return result }

        let retry = result.failed.map(\.url)
        _ = await recycle(retry)
        let stillThere = retry.filter { FileManager.default.fileExists(atPath: $0.path) }
        result.trashed.append(contentsOf: retry.filter { !stillThere.contains($0) })
        result.failed = []
        guard !stillThere.isEmpty else { return result }

        let adminResult = await Task.detached(priority: .userInitiated) {
            moveToTrashWithAdministrator(stillThere)
        }.value
        result.trashed.append(contentsOf: adminResult.trashed)
        result.failed.append(contentsOf: adminResult.failed)
        return result
    }

    @MainActor
    private static func recycle(_ urls: [URL]) async -> [URL] {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { moved, _ in
                continuation.resume(returning: Array(moved.keys))
            }
        }
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func adminTrashCommand(for urls: [URL], trash: URL, stamp: String) -> String {
        urls.map { url -> String in
            let keepsExtension = ["app", "plist"].contains(url.pathExtension.lowercased())
            let base = keepsExtension ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
            let name = keepsExtension ? "\(base) \(stamp).\(url.pathExtension)" : "\(base) \(stamp)"
            let destination = trash.appendingPathComponent(name)
            return "/bin/mv -f \(shellQuoted(url.path)) \(shellQuoted(destination.path))"
        }.joined(separator: "; ")
    }

    private static func moveToTrashWithAdministrator(_ urls: [URL]) -> RemovalResult {
        var result = RemovalResult()
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm.ss"
        let command = adminTrashCommand(for: urls, trash: trash, stamp: formatter.string(from: Date()))
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)
        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                let message = (error?[NSAppleScript.errorMessage] as? String) ?? "Permission denied"
                result.failed.append(RemovalFailure(url: url, message: message))
            } else {
                result.trashed.append(url)
            }
        }
        return result
    }
}
