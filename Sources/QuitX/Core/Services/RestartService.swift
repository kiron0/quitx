import AppKit
import Foundation

/// Quits an app then reopens it — mirrors `quitx restart`.
final class RestartService {
    static let shared = RestartService()
    private init() {}

    func restart(app: AppInfo, force: Bool = false) async -> Bool {
        guard let bundleId = app.bundleId else { return false }

        // Quit first
        let results = await QuitService.shared.quit(apps: [app], force: force)
        guard results.first?.success == true else { return false }

        // Brief pause before reopen
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Reopen via bundle ID
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return false
        }

        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            return true
        } catch {
            return false
        }
    }
}
