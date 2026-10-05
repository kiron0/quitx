import AppKit
import Foundation

final class RestartService {
    static let shared = RestartService()
    private init() {}

    func restart(app: AppInfo, force: Bool = false) async -> Bool {
        let candidateUrl = (app.bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
            ?? (app.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL })
        guard let url = candidateUrl else { return false }

        let results = await QuitService.shared.quit(apps: [app], force: force)
        guard results.first?.success == true else { return false }

        if let pid = app.pid, let runningApp = NSRunningApplication(processIdentifier: pid) {
            let deadline = Date().addingTimeInterval(2.0)
            while !runningApp.isTerminated, Date() < deadline, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        } else {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            return true
        } catch {
            return false
        }
    }
}
