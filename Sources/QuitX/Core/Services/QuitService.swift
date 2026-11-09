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
                        set previousWarn to warns before emptying of trash
                        try
                            set warns before emptying of trash to false
                            empty the trash
                        end try
                        set warns before emptying of trash to previousWarn
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

        let knownPids = Self.targetPids(for: app)
        let rootURL = Self.rootBundleURL(pids: knownPids)
        let ownPid = getpid()
        let reapsOutsideBundle = force || !Self.keepsDetachedChildren(bundleId: app.bundleId)

        var siblingInstances = Set<pid_t>()
        if let bundleId = app.bundleId, let rootURL {
            siblingInstances = Set(NSWorkspace.shared.runningApplications.compactMap { running -> pid_t? in
                guard !running.isTerminated,
                      running.bundleIdentifier == bundleId,
                      running.activationPolicy == .regular,
                      !knownPids.contains(running.processIdentifier),
                      Self.processIsRunning(running.processIdentifier),
                      let url = running.bundleURL?.standardizedFileURL,
                      url == rootURL else { return nil }
                return running.processIdentifier
            })
        }

        var helperPaths: [pid_t: String] = [:]
        func collectHelpers() {
            guard app.bundleId != nil, let rootURL else { return }
            let snapshot = ProcessSnapshot.capture()
            let descendants = snapshot.descendants(of: knownPids)
            let found = Self.helperProcesses(
                targetPids: knownPids,
                siblingInstancePids: siblingInstances,
                rootURL: rootURL,
                processPaths: snapshot.paths,
                includeOutsideBundle: reapsOutsideBundle,
                ownPid: ownPid,
                isDescendant: { pid, _ in descendants.contains(pid) }
            )
            for (pid, path) in found where helperPaths[pid] == nil {
                if !force,
                   !Self.isExecutablePath(path, insideContentsOf: rootURL),
                   NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular {
                    continue
                }
                helperPaths[pid] = path
            }
        }
        collectHelpers()

        guard !knownPids.isEmpty || !helperPaths.isEmpty else {
            return QuitResult(app: app, success: false, forced: false, error: "App not found")
        }

        var allSucceeded = true
        var firstError: String?

        var pendingApps: [(pid: pid_t, isHelper: Bool)] = []
        var pendingRawPids: [(pid: pid_t, isHelper: Bool)] = []
        var signaledHelpers = Set<pid_t>()

        func helperIdentityMatches(_ pid: pid_t) -> Bool {
            guard let expected = helperPaths[pid], let path = Self.executablePath(pid: pid) else { return false }
            return path == expected
        }

        func targetIsRunning(_ pid: pid_t, isHelper: Bool) -> Bool {
            guard Self.processIsRunning(pid) else { return false }
            if isHelper {
                return helperIdentityMatches(pid)
            }
            if let running = NSRunningApplication(processIdentifier: pid) {
                return Self.matches(running: running, app: app)
            }
            guard let rootURL, let path = Self.executablePath(pid: pid) else { return false }
            return Self.isExecutablePath(path, insideContentsOf: rootURL)
        }

        func terminatePid(_ pid: pid_t, isHelper: Bool) {
            if isHelper {
                signaledHelpers.insert(pid)
            }
            if let running = NSRunningApplication(processIdentifier: pid) {
                if !isHelper {
                    guard Self.matches(running: running, app: app) else {
                        allSucceeded = false
                        firstError = firstError ?? "Process identity changed"
                        return
                    }
                } else {
                    guard helperIdentityMatches(pid) else { return }
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
                        Darwin.kill(pid, force ? SIGKILL : SIGTERM)
                    }
                    pendingRawPids.append((pid, isHelper))
                }
            } else if Self.processIsRunning(pid) {
                let identityMatches: Bool
                if isHelper {
                    identityMatches = helperIdentityMatches(pid)
                } else if let rootURL, let path = Self.executablePath(pid: pid) {
                    identityMatches = Self.isExecutablePath(path, insideContentsOf: rootURL)
                } else {
                    identityMatches = false
                }
                if identityMatches {
                    Darwin.kill(pid, force ? SIGKILL : SIGTERM)
                    pendingRawPids.append((pid, isHelper))
                } else if !isHelper {
                    allSucceeded = false
                    firstError = firstError ?? "Process identity could not be verified"
                }
            }
        }

        func mainProcessesAlive() -> Bool {
            knownPids.contains { targetIsRunning($0, isHelper: false) }
        }

        for pid in knownPids { terminatePid(pid, isHelper: false) }
        if force {
            for pid in Array(helperPaths.keys) { terminatePid(pid, isHelper: true) }
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
            if attempt % Self.helperRescanInterval == Self.helperRescanInterval - 1, mainProcessesAlive() {
                collectHelpers()
                if force {
                    for pid in Array(helperPaths.keys) where !signaledHelpers.contains(pid) {
                        terminatePid(pid, isHelper: true)
                    }
                }
            }
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
                collectHelpers()
                let remaining = helperPaths.keys.filter { targetIsRunning($0, isHelper: true) }
                for pid in remaining { terminatePid(pid, isHelper: true) }
                if !remaining.isEmpty {
                    for _ in 0..<20 where !Task.isCancelled {
                        if remaining.allSatisfy({ !targetIsRunning($0, isHelper: true) }) { break }
                        try? await Task.sleep(nanoseconds: pollNs)
                    }
                    let stubborn = remaining.filter { targetIsRunning($0, isHelper: true) }
                    for pid in stubborn { Darwin.kill(pid, SIGKILL) }
                    if !stubborn.isEmpty {
                        for _ in 0..<10 where !Task.isCancelled {
                            if stubborn.allSatisfy({ !targetIsRunning($0, isHelper: true) }) { break }
                            try? await Task.sleep(nanoseconds: pollNs)
                        }
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

        collectHelpers()
        for pid in Array(helperPaths.keys) where !signaledHelpers.contains(pid) {
            terminatePid(pid, isHelper: true)
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

    static let helperRescanInterval = 5

    static let detachedChildrenOwners: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "dev.warp.warp-stable",
        "dev.warp.warp",
        "com.mitchellh.ghostty",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "org.tabby",
        "com.raphaelamorim.rio"
    ]

    static func keepsDetachedChildren(bundleId: String?) -> Bool {
        guard let bundleId else { return false }
        return detachedChildrenOwners.contains(bundleId.lowercased())
    }

    static func targetPids(for app: AppInfo) -> Set<pid_t> {
        var pids = Set((app.pids.isEmpty ? (app.pid.map { [$0] } ?? []) : app.pids).filter { $0 > 0 })
        guard let bundleId = app.bundleId?.lowercased(), !bundleId.isEmpty else { return pids }
        let isGroupedForeground = app.id.hasPrefix("app:")
        let isGroupedBackground = app.id.hasPrefix("background:")
        guard isGroupedForeground || isGroupedBackground else { return pids }
        let ownPid = getpid()
        for running in NSWorkspace.shared.runningApplications {
            let pid = running.processIdentifier
            guard pid > 0, pid != ownPid, !running.isTerminated,
                  running.bundleIdentifier?.lowercased() == bundleId else { continue }
            let policyMatches = isGroupedForeground
                ? running.activationPolicy == .regular
                : running.activationPolicy == .accessory
            if policyMatches && processIsRunning(pid) {
                pids.insert(pid)
            }
        }
        return pids
    }

    static let backgroundRetryAttempts: Set<Int> = [15, 30]

    static func helperProcesses(
        targetPids: Set<pid_t>,
        siblingInstancePids: Set<pid_t>,
        rootURL: URL,
        processPaths: [pid_t: String],
        includeOutsideBundle: Bool,
        ownPid: pid_t,
        isDescendant: (pid_t, Set<pid_t>) -> Bool = { ProcessTree.isDescendant($0, ofAny: $1) }
    ) -> [pid_t: String] {
        guard !targetPids.isEmpty else { return [:] }
        var helpers: [pid_t: String] = [:]
        for (pid, path) in processPaths where pid > 1 && pid != ownPid {
            guard !targetPids.contains(pid), !siblingInstancePids.contains(pid) else { continue }
            let insideBundle = isExecutablePath(path, insideContentsOf: rootURL)
            if isDescendant(pid, targetPids) {
                guard insideBundle || includeOutsideBundle else { continue }
                helpers[pid] = path
            } else if insideBundle,
                      helperBelongsToTarget(pid: pid, targetPids: targetPids, siblingInstancePids: siblingInstancePids, isDescendant: isDescendant) {
                helpers[pid] = path
            }
        }
        return helpers
    }

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

    private static func rootBundleURL(pids: Set<pid_t>) -> URL? {
        for pid in pids.sorted() {
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
