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
        guard let pid = app.pid,
              let running = NSRunningApplication(processIdentifier: pid) else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        if force {
            let ok = running.forceTerminate()
            return QuitResult(app: app, success: ok, forced: true, error: ok ? nil : "forceTerminate failed")
        }

        let ok = running.terminate()
        if ok {

            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if running.isTerminated { break }
            }
        }
        return QuitResult(app: app, success: ok || running.isTerminated, forced: false, error: ok ? nil : "terminate failed")
    }
}
