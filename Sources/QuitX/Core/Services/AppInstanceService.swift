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

    static func uniqueLabels(pids: [pid_t], label: (pid_t) -> String?) -> [pid_t: String] {
        var raw: [pid_t: String] = [:]
        for pid in pids {
            if let value = label(pid) { raw[pid] = value }
        }
        var counts: [String: Int] = [:]
        for value in raw.values { counts[value.lowercased(), default: 0] += 1 }
        var result: [pid_t: String] = [:]
        for pid in pids {
            if let base = raw[pid] {
                result[pid] = counts[base.lowercased()] == 1 ? base : "\(base) · PID \(pid)"
            } else {
                result[pid] = "PID \(pid)"
            }
        }
        return result
    }
}

enum AppInstanceGrouping {
    static func key(_ app: AppInfo) -> String? {
        guard !app.isBackground, app.pid != nil,
              let bundleId = app.bundleId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !bundleId.isEmpty else { return nil }
        return bundleId
    }

    static func merge(_ apps: [AppInfo]) -> [AppInfo] {
        var groups: [String: [AppInfo]] = [:]
        for app in apps {
            guard let key = key(app) else { continue }
            groups[key, default: []].append(app)
        }
        var emitted = Set<String>()
        var result: [AppInfo] = []
        result.reserveCapacity(apps.count)
        for app in apps {
            guard let key = key(app) else {
                result.append(app)
                continue
            }
            guard emitted.insert(key).inserted, let members = groups[key], let first = members.first else { continue }
            var seen = Set<pid_t>()
            let pids = members.flatMap(\.pids).filter { seen.insert($0).inserted }
            result.append(AppInfo(
                id: "app:\(key)",
                name: first.name,
                bundleId: first.bundleId,
                pid: first.pid,
                pids: pids,
                isBackground: false,
                windowCount: members.reduce(0) { $0 + $1.windowCount },
                memoryBytes: members.reduce(0) { $0 &+ $1.memoryBytes },
                cpuUsage: members.reduce(0) { $0 + $1.cpuUsage },
                isUnresponsive: members.contains(where: \.isUnresponsive),
                isCpuHog: members.contains(where: \.isCpuHog)
            ))
        }
        return result
    }
}

enum WindowGrouping {
    static func displayTitle(_ title: String, maxLength: Int = 60) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { text = "Untitled Window" }
        if text.count > maxLength { text = String(text.prefix(max(1, maxLength - 1))) + "…" }
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
