import AppKit
import ApplicationServices
import Darwin
import Foundation
import os

enum ProcessArguments {
    static func read(pid: pid_t) -> [String]? {
        guard pid > 0 else { return nil }
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }
        return parse(procargs: Array(buffer.prefix(size)))
    }

    static func parse(procargs buffer: [UInt8]) -> [String]? {
        let headerSize = MemoryLayout<Int32>.size
        guard buffer.count > headerSize else { return nil }
        let argc = buffer.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        guard argc > 0, argc <= 4096 else { return nil }
        var index = headerSize
        while index < buffer.count, buffer[index] != 0 { index += 1 }
        while index < buffer.count, buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        arguments.reserveCapacity(argc)
        while arguments.count < argc, index < buffer.count {
            let start = index
            while index < buffer.count, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments.isEmpty ? nil : arguments
    }
}

enum ProcessTree {
    private static func bsdInfo(pid: pid_t) -> proc_bsdinfo? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    static func parentPid(of pid: pid_t) -> pid_t? {
        bsdInfo(pid: pid).map { pid_t(truncatingIfNeeded: $0.pbi_ppid) }
    }

    static func startTime(of pid: pid_t) -> UInt64? {
        bsdInfo(pid: pid).map { $0.pbi_start_tvsec &* 1_000_000 &+ $0.pbi_start_tvusec }
    }

    static func isDescendant(
        _ pid: pid_t,
        ofAny roots: Set<pid_t>,
        parent: (pid_t) -> pid_t? = { ProcessTree.parentPid(of: $0) }
    ) -> Bool {
        guard pid > 1, !roots.isEmpty else { return false }
        var current = pid
        for _ in 0..<32 {
            guard let next = parent(current), next != current else { return false }
            if roots.contains(next) { return true }
            guard next > 1 else { return false }
            current = next
        }
        return false
    }
}

enum OpenFiles {
    static func paths(pid: pid_t, limit: Int = 1024) -> [String] {
        guard pid > 0 else { return [] }
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        let capacity = Int(bufferSize) / stride + 16
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(capacity * stride))
        guard bytes > 0 else { return [] }
        let count = min(Int(bytes) / stride, capacity)
        var paths: [String] = []
        for fd in fds.prefix(count) where fd.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) {
            var info = vnode_fdinfowithpath()
            let size = Int32(MemoryLayout<vnode_fdinfowithpath>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, size) == size else { continue }
            let path = withUnsafeBytes(of: &info.pvip.vip_path) { raw in
                String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            if !path.isEmpty { paths.append(path) }
            if paths.count >= limit { break }
        }
        return paths
    }
}

enum AppInstanceLabel {
    static func flagValue(_ arguments: [String], names: [String]) -> String? {
        for (index, argument) in arguments.enumerated() {
            for name in names {
                if argument.hasPrefix(name + "=") {
                    return cleaned(String(argument.dropFirst(name.count + 1)))
                }
                if argument == name, index + 1 < arguments.count, !arguments[index + 1].hasPrefix("-") {
                    return cleaned(arguments[index + 1])
                }
            }
        }
        return nil
    }

    static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'").union(.whitespacesAndNewlines))
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func lastPathComponent(_ path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        let component = URL(fileURLWithPath: expanded).standardizedFileURL.lastPathComponent
        return component.isEmpty || component == "/" ? nil : component
    }

    static func label(
        arguments: [String],
        resolveChromiumProfile: (_ userDataDir: String?, _ profileDirectory: String?) -> String? = { _, _ in nil }
    ) -> String? {
        let args = Array(arguments.dropFirst())
        let profileDirectory = flagValue(args, names: ["--profile-directory"])
        let userDataDir = flagValue(args, names: ["--user-data-dir"])
        if profileDirectory != nil || userDataDir != nil {
            if let resolved = resolveChromiumProfile(userDataDir, profileDirectory) { return resolved }
            if let profileDirectory { return profileDirectory }
            if let userDataDir { return lastPathComponent(userDataDir) }
        }
        if let named = flagValue(args, names: ["-P", "-p", "--P"]) { return named }
        if let path = flagValue(args, names: ["-profile", "--profile"]) { return lastPathComponent(path) }
        return nil
    }

    static func groupKey(_ app: AppInfo) -> String {
        (app.bundleId ?? app.name).lowercased()
    }

    static func assign(_ apps: [AppInfo], label: (pid_t) -> String?) -> [AppInfo] {
        var groups: [String: [Int]] = [:]
        for (index, app) in apps.enumerated() where !app.isBackground && app.pid != nil {
            groups[groupKey(app), default: []].append(index)
        }
        var result = apps
        for indices in groups.values where indices.count > 1 {
            var labels: [Int: String] = [:]
            for index in indices {
                if let pid = apps[index].pid, let value = label(pid) { labels[index] = value }
            }
            var counts: [String: Int] = [:]
            for value in labels.values { counts[value.lowercased(), default: 0] += 1 }
            for index in indices {
                guard let pid = apps[index].pid else { continue }
                let finalLabel: String
                if let base = labels[index] {
                    finalLabel = counts[base.lowercased()] == 1 ? base : "\(base) · PID \(pid)"
                } else {
                    finalLabel = "PID \(pid)"
                }
                result[index] = apps[index].settingInstanceLabel(finalLabel)
            }
        }
        return result
    }
}

enum ChromiumProfiles {
    struct Profile: Equatable, Sendable {
        let directory: String
        let name: String
    }

    static func parseLocalState(_ data: Data) -> [Profile] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: Any] else { return [] }
        return cache.compactMap { directory, value -> Profile? in
            guard let entry = value as? [String: Any] else { return nil }
            let name = (entry["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Profile(directory: directory, name: name.isEmpty ? directory : name)
        }
        .sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }

    private struct CacheEntry {
        let modified: Date
        let profiles: [Profile]
    }

    private static let profileCache = OSAllocatedUnfairLock(uncheckedState: [String: CacheEntry]())
    private static let directoryCache = OSAllocatedUnfairLock(uncheckedState: [pid_t: (start: UInt64, dir: URL?)]())

    static func profiles(userDataDir: URL) -> [Profile] {
        let localState = userDataDir.appendingPathComponent("Local State")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: localState.path),
              let modified = attributes[.modificationDate] as? Date else { return [] }
        let key = localState.standardizedFileURL.path
        if let cached = profileCache.withLockUnchecked({ $0[key] }), cached.modified == modified {
            return cached.profiles
        }
        guard let data = try? Data(contentsOf: localState), data.count < 32 * 1024 * 1024 else { return [] }
        let parsed = parseLocalState(data)
        profileCache.withLockUnchecked { cache in
            if cache.count >= 32 { cache.removeAll() }
            cache[key] = CacheEntry(modified: modified, profiles: parsed)
        }
        return parsed
    }

    static func userDataDirectory(pid: pid_t, arguments: [String]?) -> URL? {
        let start = ProcessTree.startTime(of: pid) ?? 0
        if let cached = directoryCache.withLockUnchecked({ $0[pid] }), cached.start == start {
            return cached.dir
        }
        let resolved = resolveUserDataDirectory(pid: pid, arguments: arguments)
        directoryCache.withLockUnchecked { cache in
            if cache.count >= 64 { cache.removeAll() }
            cache[pid] = (start, resolved)
        }
        return resolved
    }

    private static func resolveUserDataDirectory(pid: pid_t, arguments: [String]?) -> URL? {
        if let arguments,
           let value = AppInstanceLabel.flagValue(Array(arguments.dropFirst()), names: ["--user-data-dir"]) {
            let url = URL(fileURLWithPath: (value as NSString).expandingTildeInPath).standardizedFileURL
            return hasLocalState(url) ? url : nil
        }
        var checked = Set<String>()
        for path in OpenFiles.paths(pid: pid) {
            var directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            for _ in 0..<4 {
                let key = directory.path
                if key == "/" || key.isEmpty { break }
                if checked.insert(key).inserted, hasLocalState(directory) { return directory }
                directory = directory.deletingLastPathComponent()
            }
        }
        return nil
    }

    private static func hasLocalState(_ directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent("Local State").path)
    }

    static func profileNames(pid: pid_t) -> [String] {
        let arguments = ProcessArguments.read(pid: pid)
        guard let directory = userDataDirectory(pid: pid, arguments: arguments) else { return [] }
        return profiles(userDataDir: directory).map(\.name)
    }

    static func resolveLabel(userDataDir: String?, profileDirectory: String?) -> String? {
        guard let userDataDir else { return nil }
        let url = URL(fileURLWithPath: (userDataDir as NSString).expandingTildeInPath).standardizedFileURL
        let known = profiles(userDataDir: url)
        if let profileDirectory {
            return known.first(where: { $0.directory == profileDirectory })?.name
        }
        return known.count == 1 ? known[0].name : nil
    }
}

enum WindowGrouping {
    struct Group: Equatable {
        let name: String
        let indices: [Int]
    }

    static let otherGroupName = "Other Windows"
    private static let separators = [" - ", " – ", " — "]

    static func profileName(forTitle title: String, profileNames: [String]) -> String? {
        for name in profileNames.sorted(by: { $0.count > $1.count }) where !name.isEmpty {
            if title == name { return name }
            for separator in separators where title.hasSuffix(separator + name) { return name }
        }
        return nil
    }

    static func groups(titles: [String], profileNames: [String]) -> [Group]? {
        var seen = Set<String>()
        let names = profileNames.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard names.count >= 2 else { return nil }
        var members: [String: [Int]] = [:]
        var order: [String] = []
        var other: [Int] = []
        for (index, title) in titles.enumerated() {
            if let name = profileName(forTitle: title, profileNames: names) {
                if members[name] == nil { order.append(name) }
                members[name, default: []].append(index)
            } else {
                other.append(index)
            }
        }
        guard !members.isEmpty else { return nil }
        var result = order.map { Group(name: $0, indices: members[$0] ?? []) }
        if !other.isEmpty { result.append(Group(name: otherGroupName, indices: other)) }
        return result
    }

    static func displayTitle(_ title: String, profile: String?, maxLength: Int = 60) -> String {
        var text = title
        if let profile, profile != otherGroupName {
            for separator in separators where text.hasSuffix(separator + profile) {
                text = String(text.dropLast(separator.count + profile.count))
                break
            }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { text = "Untitled Window" }
        if text.count > maxLength { text = String(text.prefix(maxLength - 1)) + "…" }
        return text
    }
}

@MainActor
enum AppWindowControl {
    struct Window {
        let element: AXUIElement
        let title: String
        let isMinimized: Bool
    }

    private static let messagingTimeout: Float = 0.5

    static var isTrusted: Bool { AXIsProcessTrusted() }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool {
        guard let value = attribute(element, name) else { return false }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }

    static func windows(pid: pid_t) -> [Window] {
        guard pid > 0, isTrusted else { return [] }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, messagingTimeout)
        guard let list = attribute(application, kAXWindowsAttribute as String) as? [AXUIElement] else { return [] }
        return list.compactMap { window -> Window? in
            let subrole = attribute(window, kAXSubroleAttribute as String) as? String
            if let subrole,
               subrole != kAXStandardWindowSubrole as String,
               subrole != kAXDialogSubrole as String {
                return nil
            }
            let title = (attribute(window, kAXTitleAttribute as String) as? String) ?? ""
            return Window(
                element: window,
                title: title,
                isMinimized: boolAttribute(window, kAXMinimizedAttribute as String)
            )
        }
    }

    @discardableResult
    static func close(_ windows: [Window]) -> Int {
        var closed = 0
        for window in windows {
            guard let button = element(attribute(window.element, kAXCloseButtonAttribute as String)) else { continue }
            if AXUIElementPerformAction(button, kAXPressAction as CFString) == .success {
                closed += 1
            }
        }
        return closed
    }

    static func show(_ window: Window, pid: pid_t) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        _ = NSRunningApplication(processIdentifier: pid)?.activate()
    }
}
