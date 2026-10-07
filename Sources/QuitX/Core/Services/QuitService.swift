import AppKit
import Foundation
import Darwin

final class QuitService {
    static let shared = QuitService()
    private init() {}

    @discardableResult
    func quit(apps: [AppInfo], force: Bool, dryRun: Bool = false) async -> [QuitResult] {
        await withTaskGroup(of: QuitResult.self) { group in
            for app in apps {
                group.addTask { await self.quitOne(app: app, force: force, dryRun: dryRun) }
            }
            var results: [QuitResult] = []
            for await result in group { results.append(result) }
            return results
        }
    }

    private func quitOne(app: AppInfo, force: Bool, dryRun: Bool) async -> QuitResult {
        guard !dryRun else {
            return QuitResult(app: app, success: true, forced: false, error: nil)
        }

        if app.name.lowercased() == "trash" || app.bundleId == QuitXConstants.SystemBundleIds.trash {
            let script = """
            ignoring application responses
                tell application "Finder"
                    try
                        set warns before emptying to false
                        empty the trash
                    end try
                end tell
            end ignoring
            """
            return await Self.runAppleScript(script, app: app, label: "Trash")
        }

        if app.bundleId == QuitXConstants.SystemBundleIds.finder || app.name.lowercased() == "finder" {
            let script = """
            with timeout of 2 seconds
                tell application "Finder"
                    close every window
                end tell
            end timeout
            """
            return await Self.runAppleScript(script, app: app, label: "Finder")
        }

        let knownPids: Set<pid_t> = Set(app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids)
        let rootURL = Self.rootBundleURL(for: app)

        var helperPids: Set<pid_t> = []
        if let bundleId = app.bundleId, let rootURL {
            let prefix = bundleId + "."
            for running in NSWorkspace.shared.runningApplications {
                guard !running.isTerminated else { continue }
                guard let bid = running.bundleIdentifier else { continue }
                guard bid == bundleId || bid.hasPrefix(prefix) else { continue }
                guard let url = running.bundleURL?.standardizedFileURL else { continue }
                guard url.path.hasPrefix(rootURL.path + "/Contents/") else { continue }
                let pid = running.processIdentifier
                guard !knownPids.contains(pid) else { continue }
                helperPids.insert(pid)
            }
        }

        guard !knownPids.isEmpty || !helperPids.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var allSucceeded = true
        var firstError: String?

        var pendingApps: [(app: NSRunningApplication, wasForced: Bool, isHelper: Bool)] = []
        var pendingRawPids: [(pid: pid_t, wasForced: Bool, isHelper: Bool)] = []

        func terminatePid(_ pid: pid_t, isHelper: Bool) {
            if let running = NSRunningApplication(processIdentifier: pid) {
                if !isHelper {
                    guard Self.matches(running: running, app: app) else {
                        allSucceeded = false
                        firstError = firstError ?? "Process identity changed"
                        return
                    }
                } else if let rootURL {
                    let runningPath = running.bundleURL?.standardizedFileURL.path ?? ""
                    guard running.bundleIdentifier == app.bundleId
                        || runningPath.hasPrefix(rootURL.path + "/Contents/") else {
                        return
                    }
                }
                guard !running.isTerminated else { return }
                let accepted = force ? running.forceTerminate() : running.terminate()
                if accepted {
                    pendingApps.append((running, force, isHelper))
                } else {
                    if force {
                        Darwin.kill(pid, SIGKILL)
                    } else {
                        Darwin.kill(pid, SIGTERM)
                    }
                    pendingRawPids.append((pid, force, isHelper))
                }
            } else if Darwin.kill(pid, 0) == 0 {
                if let rootURL, let path = Self.executablePath(pid: pid),
                   path.hasPrefix(rootURL.path + "/") {
                    if force {
                        Darwin.kill(pid, SIGKILL)
                    } else {
                        Darwin.kill(pid, SIGTERM)
                    }
                    pendingRawPids.append((pid, force, isHelper))
                }
            }
        }

        for pid in knownPids { terminatePid(pid, isHelper: false) }
        for pid in helperPids { terminatePid(pid, isHelper: true) }

        let pollNs: UInt64 = 100_000_000
        let gracefulAttempts = force ? 20 : 50

        for _ in 0..<gracefulAttempts {
            if Task.isCancelled {
                return QuitResult(app: app, success: false, forced: false, error: "Cancelled")
            }
            let appsDone = pendingApps.allSatisfy { $0.app.isTerminated }
            let pidsDone = pendingRawPids.allSatisfy { Darwin.kill($0.pid, 0) != 0 }
            if appsDone && pidsDone { break }
            try? await Task.sleep(nanoseconds: pollNs)
        }

        if Task.isCancelled {
            return QuitResult(app: app, success: false, forced: false, error: "Cancelled")
        }

        if !force {
            for entry in pendingApps where !entry.app.isTerminated && !entry.isHelper {
                allSucceeded = false
                firstError = firstError ?? "App did not quit gracefully"
            }
            for entry in pendingRawPids where Darwin.kill(entry.pid, 0) == 0 && !entry.isHelper {
                allSucceeded = false
                firstError = firstError ?? "Process did not quit gracefully"
            }
            return QuitResult(
                app: app,
                success: allSucceeded,
                forced: false,
                error: firstError
            )
        }

        var forceApps: [(app: NSRunningApplication, isHelper: Bool)] = []
        for entry in pendingApps where !entry.app.isTerminated {
            _ = entry.app.forceTerminate()
            Darwin.kill(entry.app.processIdentifier, SIGKILL)
            forceApps.append((entry.app, entry.isHelper))
        }

        var forceRawPids: [(pid: pid_t, isHelper: Bool)] = []
        for entry in pendingRawPids where Darwin.kill(entry.pid, 0) == 0 {
            Darwin.kill(entry.pid, SIGKILL)
            forceRawPids.append((entry.pid, entry.isHelper))
        }

        if !forceApps.isEmpty || !forceRawPids.isEmpty {
            for _ in 0..<20 where !Task.isCancelled {
                let appsDone = forceApps.allSatisfy { $0.app.isTerminated }
                let pidsDone = forceRawPids.allSatisfy { Darwin.kill($0.pid, 0) != 0 }
                if appsDone && pidsDone { break }
                try? await Task.sleep(nanoseconds: pollNs)
            }
        }

        for entry in pendingApps where !entry.app.isTerminated {
            Darwin.kill(entry.app.processIdentifier, SIGKILL)
            if !entry.isHelper && !entry.app.isTerminated && Darwin.kill(entry.app.processIdentifier, 0) == 0 {
                allSucceeded = false
                firstError = firstError ?? "App did not terminate"
            }
        }

        for entry in pendingRawPids where Darwin.kill(entry.pid, 0) == 0 {
            if !entry.isHelper {
                allSucceeded = false
                firstError = firstError ?? "Process did not terminate"
            }
        }

        return QuitResult(
            app: app,
            success: allSucceeded,
            forced: force,
            error: firstError
        )
    }

    private static func rootBundleURL(for app: AppInfo) -> URL? {
        let pids = app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids
        for pid in pids {
            if let url = NSRunningApplication(processIdentifier: pid)?.bundleURL {
                return url.standardizedFileURL
            }
        }
        return nil
    }

    private static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, 4096)
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func runAppleScript(_ source: String, app: AppInfo, label: String) async -> QuitResult {
        await MainActor.run {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: source) else {
                return QuitResult(app: app, success: false, forced: false, error: "Could not create \(label) AppleScript")
            }
            appleScript.executeAndReturnError(&error)
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }
    }

    static func matches(running: NSRunningApplication, app: AppInfo) -> Bool {
        if app.isBackground && app.pids.contains(running.processIdentifier) {
            return true
        }

        if let expectedBundleId = app.bundleId {
            if running.bundleIdentifier == expectedBundleId {
                return true
            }
            if let runningBid = running.bundleIdentifier, runningBid.hasPrefix(expectedBundleId + ".") {
                return true
            }
        }

        let runningName = running.localizedName
            ?? running.bundleURL?.deletingPathExtension().lastPathComponent
            ?? running.executableURL?.lastPathComponent
        guard let runningName else { return false }
        let cleanRunningName = SystemAppProtection.cleanGroupedName(SystemAppProtection.cleanAppName(runningName))
        let cleanAppName = SystemAppProtection.cleanGroupedName(SystemAppProtection.cleanAppName(app.name))
        return cleanRunningName.caseInsensitiveCompare(cleanAppName) == .orderedSame
    }
}
