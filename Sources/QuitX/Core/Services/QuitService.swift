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
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                return QuitResult(app: app, success: false, forced: false, error: "Could not create Trash AppleScript")
            }
            appleScript.executeAndReturnError(&error)
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }

        if app.bundleId == "com.apple.finder" || app.name.lowercased() == "finder" {
            let script = """
            tell application "Finder"
                close every window
            end tell
            """
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                return QuitResult(app: app, success: false, forced: false, error: "Could not create Finder AppleScript")
            }
            appleScript.executeAndReturnError(&error)
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }

        let pidsToKill = app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids
        guard !pidsToKill.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var allSucceeded = true
        var firstError: String?
        for pid in pidsToKill {
            guard let running = NSRunningApplication(processIdentifier: pid) else { continue }

            guard Self.matches(running: running, app: app) else {
                allSucceeded = false
                firstError = firstError ?? "Process identity changed"
                continue
            }

            let accepted = force ? running.forceTerminate() : running.terminate()
            guard accepted else {
                allSucceeded = false
                firstError = firstError ?? (force ? "forceTerminate failed" : "terminate failed")
                continue
            }

            let attempts = force ? 20 : 50
            for _ in 0..<attempts where !running.isTerminated {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if !running.isTerminated {
                allSucceeded = false
                firstError = firstError ?? (force ? "App did not terminate after force quit" : "App did not terminate")
            }
        }

        return QuitResult(
            app: app,
            success: allSucceeded,
            forced: force,
            error: firstError
        )
    }

    static func matches(running: NSRunningApplication, app: AppInfo) -> Bool {
        if let expectedBundleId = app.bundleId {
            return running.bundleIdentifier == expectedBundleId
        }
        guard let expectedName = running.localizedName else { return false }
        return expectedName.caseInsensitiveCompare(app.name) == .orderedSame
    }
}
