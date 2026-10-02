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
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }

        if app.bundleId == "com.apple.finder" || app.name.lowercased() == "finder" {
            let script = """
            tell application "Finder"
                close every window
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            return QuitResult(app: app, success: error == nil, forced: false, error: error?.description)
        }

        let pidsToKill = app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids
        guard !pidsToKill.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var anySuccess = false
        for pid in pidsToKill {
            guard let running = NSRunningApplication(processIdentifier: pid) else { continue }
            if force {
                let ok = running.forceTerminate()
                if ok { anySuccess = true }
            } else {
                let ok = running.terminate()
                if ok {
                    for _ in 0..<50 {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if running.isTerminated { break }
                    }
                    if running.isTerminated || ok { anySuccess = true }
                }
            }
        }

        return QuitResult(
            app: app,
            success: anySuccess,
            forced: force,
            error: anySuccess ? nil : (force ? "forceTerminate failed" : "terminate failed")
        )
    }
}
