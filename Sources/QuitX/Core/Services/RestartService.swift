import AppKit
import Foundation

final class RestartService {
    static let shared = RestartService()
    private init() {}

    static func relaunchArguments(from arguments: [String]) -> [String] {
        Array(arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
    }

    func restart(app: AppInfo, force: Bool = false) async -> Bool {
        let candidateUrl = app.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL }
            ?? (app.bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        guard let url = candidateUrl else { return false }

        let relaunchArguments: [String]? = app.instanceLabel == nil
            ? nil
            : app.pid.flatMap { ProcessArguments.read(pid: $0) }.map(Self.relaunchArguments(from:))

        let results = await QuitService.shared.quit(apps: [app], force: force)
        guard results.first?.success == true else { return false }

        if let pid = app.pid, QuitService.processIsRunning(pid) {
            let deadline = Date().addingTimeInterval(2.0)
            while QuitService.processIsRunning(pid), Date() < deadline, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard !QuitService.processIsRunning(pid) else { return false }
        } else {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        if let relaunchArguments {
            config.arguments = relaunchArguments
            config.createsNewApplicationInstance = true
        }

        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            return true
        } catch {
            return false
        }
    }
}
