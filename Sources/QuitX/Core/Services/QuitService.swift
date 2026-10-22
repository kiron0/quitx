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
            with timeout of 15 seconds
                ignoring application responses
                    tell application "Finder"
                        set previousWarn to warns before emptying
                        try
                            set warns before emptying to false
                            empty the trash
                        end try
                        set warns before emptying to previousWarn
                    end tell
                end ignoring
            end timeout
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

        let knownPids: Set<pid_t> = Set(
            (app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids)
                .filter { $0 > 0 }
        )
        let rootURL = Self.rootBundleURL(for: app)

        var helperPids: Set<pid_t> = []
        if let bundleId = app.bundleId, let rootURL {
            let workspaceApps = NSWorkspace.shared.runningApplications
            let siblingInstances = Set(workspaceApps.compactMap { running -> pid_t? in
                guard !running.isTerminated,
                      running.bundleIdentifier == bundleId,
                      running.activationPolicy == .regular,
                      !knownPids.contains(running.processIdentifier),
                      Self.processIsRunning(running.processIdentifier),
                      let url = running.bundleURL?.standardizedFileURL,
                      url == rootURL else { return nil }
                return running.processIdentifier
            })
            for running in workspaceApps {
                guard !running.isTerminated else { continue }
                guard let path = running.executableURL?.path ?? running.bundleURL?.path,
                      Self.isExecutablePath(path, insideContentsOf: rootURL) else { continue }
                let pid = running.processIdentifier
                guard Self.processIsRunning(pid) else { continue }
                guard !knownPids.contains(pid) else { continue }
                guard Self.helperBelongsToTarget(
                    pid: pid,
                    targetPids: knownPids,
                    siblingInstancePids: siblingInstances
                ) else { continue }
                helperPids.insert(pid)
            }
            for (pid, path) in AppListService.runningProcessPaths() where pid > 0 {
                guard !knownPids.contains(pid), !helperPids.contains(pid), !siblingInstances.contains(pid) else { continue }
                guard Self.isExecutablePath(path, insideContentsOf: rootURL) else { continue }
                guard ProcessTree.isDescendant(pid, ofAny: knownPids) else { continue }
                helperPids.insert(pid)
            }
        }

        guard !knownPids.isEmpty || !helperPids.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var allSucceeded = true
        var firstError: String?

        var pendingApps: [(pid: pid_t, isHelper: Bool)] = []
        var pendingRawPids: [(pid: pid_t, isHelper: Bool)] = []

        func targetIsRunning(_ pid: pid_t, isHelper: Bool) -> Bool {
            guard Self.processIsRunning(pid) else { return false }
            if isHelper {
                guard let rootURL, let path = Self.executablePath(pid: pid) else { return false }
                return Self.isExecutablePath(path, insideContentsOf: rootURL)
            }
            if let running = NSRunningApplication(processIdentifier: pid) {
                return Self.matches(running: running, app: app)
            }
            guard let rootURL, let path = Self.executablePath(pid: pid) else { return false }
            return Self.isExecutablePath(path, insideContentsOf: rootURL)
        }

        func terminatePid(_ pid: pid_t, isHelper: Bool) {
            if let running = NSRunningApplication(processIdentifier: pid) {
                if !isHelper {
                    guard Self.matches(running: running, app: app) else {
                        allSucceeded = false
                        firstError = firstError ?? "Process identity changed"
                        return
                    }
                } else {
                    guard let rootURL,
                          let path = running.executableURL?.path ?? running.bundleURL?.path,
                          Self.isExecutablePath(path, insideContentsOf: rootURL) else { return }
                }
                guard Self.processIsRunning(pid) else { return }
                let accepted = force ? running.forceTerminate() : running.terminate()
                if accepted {
                    if running.processIdentifier > 0 {
                        pendingApps.append((pid, isHelper))
                    } else {
                        pendingRawPids.append((pid, isHelper))
                    }
                } else {
                    if targetIsRunning(pid, isHelper: isHelper) {
                        if force {
                            Darwin.kill(pid, SIGKILL)
                        } else {
                            Darwin.kill(pid, SIGTERM)
                        }
                    }
                    pendingRawPids.append((pid, isHelper))
                }
            } else if Self.processIsRunning(pid) {
                if let rootURL, let path = Self.executablePath(pid: pid),
                   Self.isExecutablePath(path, insideContentsOf: rootURL) {
                    if force {
                        Darwin.kill(pid, SIGKILL)
                    } else {
                        Darwin.kill(pid, SIGTERM)
                    }
                    pendingRawPids.append((pid, isHelper))
                } else if !isHelper {
                    allSucceeded = false
                    firstError = firstError ?? "Process identity could not be verified"
                }
            }
        }

        for pid in knownPids { terminatePid(pid, isHelper: false) }
        if force {
            for pid in helperPids { terminatePid(pid, isHelper: true) }
        }

        let pollNs: UInt64 = 100_000_000
        let gracefulAttempts = force ? 20 : 50

        for attempt in 0..<gracefulAttempts {
            if Task.isCancelled {
                return QuitResult(app: app, success: false, forced: false, error: "Cancelled")
            }
            let appsDone = pendingApps.allSatisfy { !targetIsRunning($0.pid, isHelper: $0.isHelper) }
            let pidsDone = pendingRawPids.allSatisfy { !targetIsRunning($0.pid, isHelper: $0.isHelper) }
            if appsDone && pidsDone { break }
            if !force, Self.backgroundRetryAttempts.contains(attempt) {
                let visible = LastWindowQuitWindowCounter.visibleWindowIDs() ?? [:]
                for pid in knownPids where targetIsRunning(pid, isHelper: false) && (visible[pid] ?? []).isEmpty {
                    guard let running = NSRunningApplication(processIdentifier: pid),
                          Self.matches(running: running, app: app) else { continue }
                    _ = running.terminate()
                }
            }
            try? await Task.sleep(nanoseconds: pollNs)
        }

        if Task.isCancelled {
            return QuitResult(app: app, success: false, forced: false, error: "Cancelled")
        }

        if !force {
            for entry in pendingApps where targetIsRunning(entry.pid, isHelper: entry.isHelper) && !entry.isHelper {
                allSucceeded = false
                firstError = firstError ?? "App did not quit gracefully"
            }
            for entry in pendingRawPids where targetIsRunning(entry.pid, isHelper: entry.isHelper) && !entry.isHelper {
                allSucceeded = false
                firstError = firstError ?? "Process did not quit gracefully"
            }
            if allSucceeded {
                let remaining = helperPids.filter { targetIsRunning($0, isHelper: true) }
                for pid in remaining { terminatePid(pid, isHelper: true) }
                if !remaining.isEmpty {
                    for _ in 0..<20 where !Task.isCancelled {
                        if remaining.allSatisfy({ !targetIsRunning($0, isHelper: true) }) { break }
                        try? await Task.sleep(nanoseconds: pollNs)
                    }
                }
            }
            return QuitResult(
                app: app,
                success: allSucceeded,
                forced: false,
                error: firstError
            )
        }

        var forceApps: [(pid: pid_t, isHelper: Bool)] = []
        for entry in pendingApps where targetIsRunning(entry.pid, isHelper: entry.isHelper) {
            _ = NSRunningApplication(processIdentifier: entry.pid)?.forceTerminate()
            if targetIsRunning(entry.pid, isHelper: entry.isHelper) {
                Darwin.kill(entry.pid, SIGKILL)
            }
            forceApps.append((entry.pid, entry.isHelper))
        }

        var forceRawPids: [(pid: pid_t, isHelper: Bool)] = []
        for entry in pendingRawPids where targetIsRunning(entry.pid, isHelper: entry.isHelper) {
            Darwin.kill(entry.pid, SIGKILL)
            forceRawPids.append((entry.pid, entry.isHelper))
        }

        if !forceApps.isEmpty || !forceRawPids.isEmpty {
            for _ in 0..<20 where !Task.isCancelled {
                let appsDone = forceApps.allSatisfy { !targetIsRunning($0.pid, isHelper: $0.isHelper) }
                let pidsDone = forceRawPids.allSatisfy { !targetIsRunning($0.pid, isHelper: $0.isHelper) }
                if appsDone && pidsDone { break }
                try? await Task.sleep(nanoseconds: pollNs)
            }
        }

        for entry in pendingApps where targetIsRunning(entry.pid, isHelper: entry.isHelper) {
            Darwin.kill(entry.pid, SIGKILL)
            if !entry.isHelper && targetIsRunning(entry.pid, isHelper: entry.isHelper) {
                allSucceeded = false
                firstError = firstError ?? "App did not terminate"
            }
        }

        for entry in pendingRawPids where targetIsRunning(entry.pid, isHelper: entry.isHelper) {
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

    static let backgroundRetryAttempts: Set<Int> = [15, 30]

    static func helperBelongsToTarget(
        pid: pid_t,
        targetPids: Set<pid_t>,
        siblingInstancePids: Set<pid_t>,
        isDescendant: (pid_t, Set<pid_t>) -> Bool = { ProcessTree.isDescendant($0, ofAny: $1) }
    ) -> Bool {
        guard !siblingInstancePids.contains(pid) else { return false }
        guard !siblingInstancePids.isEmpty else { return true }
        return isDescendant(pid, targetPids)
    }

    private static func rootBundleURL(for app: AppInfo) -> URL? {
        let pids = (app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids)
            .filter { $0 > 0 }
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

    static func isExecutablePath(_ path: String, insideContentsOf rootURL: URL) -> Bool {
        let candidate = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL.path
        let contents = rootURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .appendingPathComponent("Contents", isDirectory: true).path
        return candidate.hasPrefix(contents + "/")
    }

    static func processIsRunning(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        errno = 0
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private static let scriptQueue = DispatchQueue(label: "quitx.applescript", qos: .userInitiated)

    static func closeFinderWindowsSynchronously() {
        let script = """
        with timeout of 1 seconds
            tell application "Finder"
                close every window
            end tell
        end timeout
        """
        _ = runAppleScriptSynchronously(script)
    }

    static func emptyTrashSynchronously() {
        let script = """
        with timeout of 10 seconds
            ignoring application responses
                tell application "Finder"
                    set previousWarn to warns before emptying
                    try
                        set warns before emptying to false
                        empty the trash
                    end try
                    set warns before emptying to previousWarn
                end tell
            end ignoring
        end timeout
        """
        _ = runAppleScriptSynchronously(script)
    }

    private static func runAppleScriptSynchronously(_ source: String) -> (success: Bool, error: String?) {
        scriptQueue.sync {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: source) else {
                return (false, "Could not create AppleScript")
            }
            appleScript.executeAndReturnError(&error)
            return (error == nil, error?.description)
        }
    }

    private static func runAppleScript(_ source: String, app: AppInfo, label: String) async -> QuitResult {
        await withCheckedContinuation { continuation in
            scriptQueue.async {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: source) else {
                    continuation.resume(returning: QuitResult(
                        app: app,
                        success: false,
                        forced: false,
                        error: "Could not create \(label) AppleScript"
                    ))
                    return
                }
                appleScript.executeAndReturnError(&error)
                continuation.resume(returning: QuitResult(
                    app: app,
                    success: error == nil,
                    forced: false,
                    error: error?.description
                ))
            }
        }
    }

    static func matches(running: NSRunningApplication, app: AppInfo) -> Bool {
        let runningName = running.localizedName
            ?? running.bundleURL?.deletingPathExtension().lastPathComponent
            ?? running.executableURL?.lastPathComponent
        return identityMatches(
            expectedBundleId: app.bundleId,
            expectedName: app.name,
            runningBundleId: running.bundleIdentifier,
            runningName: runningName
        )
    }

    static func identityMatches(
        expectedBundleId: String?,
        expectedName: String,
        runningBundleId: String?,
        runningName: String?
    ) -> Bool {
        if let expectedBundleId {
            guard let runningBundleId else { return false }
            let expected = expectedBundleId.lowercased()
            let actual = runningBundleId.lowercased()
            return actual == expected
        }
        guard let runningName else { return false }
        let cleanRunningName = SystemAppProtection.cleanGroupedName(SystemAppProtection.cleanAppName(runningName))
        let cleanAppName = SystemAppProtection.cleanGroupedName(SystemAppProtection.cleanAppName(expectedName))
        return cleanRunningName.caseInsensitiveCompare(cleanAppName) == .orderedSame
    }
}
