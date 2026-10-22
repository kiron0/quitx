import AppKit
import Foundation

final class RestartService {
    static let shared = RestartService()
    private init() {}

    static func relaunchArguments(from arguments: [String]) -> [String] {
        Array(arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
    }

    static func relaunchPlan(pids: [pid_t], arguments: (pid_t) -> [String]?) -> [[String]?] {
        guard pids.count > 1 else { return [nil] }
        return pids.map { pid in arguments(pid).map(relaunchArguments(from:)) }
    }

    func restart(app: AppInfo, force: Bool = false) async -> Bool {
        let candidateUrl = app.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL }
            ?? (app.bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        guard let url = candidateUrl else { return false }

        let instancePids = app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids
        let launches = Self.relaunchPlan(
            pids: instancePids,
            arguments: { ProcessArguments.read(pid: $0) }
        )

        let results = await QuitService.shared.quit(apps: [app], force: force)
        guard results.first?.success == true else { return false }

        let livePids = instancePids.filter(QuitService.processIsRunning)
        if !livePids.isEmpty {
            let deadline = Date().addingTimeInterval(2.0)
            while livePids.contains(where: QuitService.processIsRunning), Date() < deadline, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard !livePids.contains(where: QuitService.processIsRunning) else { return false }
        } else {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        var launchedAny = false
        for (index, arguments) in launches.enumerated() {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = index == 0
            if let arguments {
                config.arguments = arguments
            }
            config.createsNewApplicationInstance = index > 0
            if (try? await NSWorkspace.shared.openApplication(at: url, configuration: config)) != nil {
                launchedAny = true
            }
        }
        return launchedAny
    }
}
