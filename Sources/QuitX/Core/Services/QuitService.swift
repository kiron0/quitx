import AppKit
import Foundation

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

        if app.name.lowercased() == "trash" || app.bundleId == "com.apple.trash" {
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

        if app.bundleId == "com.apple.finder" || app.name.lowercased() == "finder" {
            let script = """
            tell application "Finder"
                close every window
            end tell
            """
            return await Self.runAppleScript(script, app: app, label: "Finder")
        }

        let knownPids: Set<pid_t> = Set(app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids)

        var helperPids: Set<pid_t> = []
        if let bundleId = app.bundleId {
            let prefix = bundleId + "."
            for running in NSWorkspace.shared.runningApplications {
                guard !running.isTerminated else { continue }
                guard let bid = running.bundleIdentifier else { continue }
                let pid = running.processIdentifier
                guard !knownPids.contains(pid) else { continue }
                if bid == bundleId || bid.hasPrefix(prefix) {
                    helperPids.insert(pid)
                }
            }
        }

        guard !knownPids.isEmpty || !helperPids.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var allSucceeded = true
        var firstError: String?

        var pendingApps: [(app: NSRunningApplication, wasForced: Bool, isHelper: Bool)] = []

        func terminatePid(_ pid: pid_t, isHelper: Bool) {
            guard let running = NSRunningApplication(processIdentifier: pid) else { return }
            if !isHelper {
                guard Self.matches(running: running, app: app) else {
                    allSucceeded = false
                    firstError = firstError ?? "Process identity changed"
                    return
                }
            }
            guard !running.isTerminated else { return }
            let accepted = force ? running.forceTerminate() : running.terminate()
            if accepted {
                pendingApps.append((running, force, isHelper))
            } else if !isHelper {
                allSucceeded = false
                firstError = firstError ?? (force ? "forceTerminate failed" : "terminate failed")
            }
        }

        for pid in knownPids { terminatePid(pid, isHelper: false) }
        for pid in helperPids { terminatePid(pid, isHelper: true) }

        let pollNs: UInt64 = 100_000_000
        let gracefulAttempts = force ? 20 : 50
        let forceAttempts    = 20

        for _ in 0..<gracefulAttempts where !Task.isCancelled {
            if pendingApps.allSatisfy({ $0.app.isTerminated }) { break }
            try? await Task.sleep(nanoseconds: pollNs)
        }

        var forceEntries: [(app: NSRunningApplication, isHelper: Bool)] = []
        for entry in pendingApps where !entry.app.isTerminated && !entry.wasForced {
            _ = entry.app.forceTerminate()
            forceEntries.append((entry.app, entry.isHelper))
        }

        if !forceEntries.isEmpty {
            for _ in 0..<forceAttempts where !Task.isCancelled {
                if forceEntries.allSatisfy({ $0.app.isTerminated }) { break }
                try? await Task.sleep(nanoseconds: pollNs)
            }
        }

        for entry in pendingApps where !entry.app.isTerminated && !entry.isHelper {
            allSucceeded = false
            firstError = firstError ?? "App did not terminate"
        }

        return QuitResult(
            app: app,
            success: allSucceeded,
            forced: force,
            error: firstError
        )
    }

    private static func runAppleScript(_ source: String, app: AppInfo, label: String) async -> QuitResult {
        await Task.detached {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: source) else {
                return QuitResult(app: app, success: false, forced: false, error: "Could not create \(label) AppleScript")
            }
            appleScript.executeAndReturnError(&error)
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }.value
    }

    static func matches(running: NSRunningApplication, app: AppInfo) -> Bool {
        if let expectedBundleId = app.bundleId {
            return running.bundleIdentifier == expectedBundleId
        }
        let runningName = running.localizedName
            ?? running.bundleURL?.deletingPathExtension().lastPathComponent
            ?? running.executableURL?.lastPathComponent
        guard let runningName else { return false }
        let cleanRunningName = SystemAppProtection.cleanAppName(runningName)
        return cleanRunningName.caseInsensitiveCompare(app.name) == .orderedSame
    }
}
