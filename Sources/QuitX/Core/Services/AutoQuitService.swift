import AppKit

@MainActor
final class AutoQuitService {
    static let shared = AutoQuitService()
    private var timer: Timer?
    private var lastActiveTimestamps: [pid_t: Date] = [:]
    private var quittingPids: Set<pid_t> = []

    private init() {}

    func startTracking() {
        guard timer == nil else { return }

        let now = Date()
        for (app, pid) in runningApplicationsWithResolvedPids()
        where app.activationPolicy == .regular {
            lastActiveTimestamps[pid] = now
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        let newTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkInactiveApps()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        lastActiveTimestamps.removeAll()
        quittingPids.removeAll()
    }

    deinit {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.processIdentifier > 0 {
            guard let pid = resolvedPid(for: app) else { return }
            lastActiveTimestamps[pid] = Date()
            return
        }
        recordActivationOffMainThread(for: app)
    }

    private func recordActivationOffMainThread(for app: NSRunningApplication) {
        let reportedPid = app.processIdentifier
        let executablePath = app.executableURL?.path
        Task.detached(priority: .userInitiated) {
            let index = AppListService.pidsByNormalizedPath(AppListService.runningProcessPaths())
            guard let pid = AppListService.resolvedProcessIdentifier(
                reportedPid: reportedPid,
                executablePath: executablePath,
                pidsByNormalizedPath: index
            ), QuitService.processIsRunning(pid) else { return }
            await MainActor.run { [weak self] in
                self?.lastActiveTimestamps[pid] = Date()
            }
        }
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        appDidActivate(notification)
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        lastActiveTimestamps.removeValue(forKey: pid)
        quittingPids.remove(pid)
    }

    private var cachedExcludeList: [String] = []
    private var cachedExcludeSet: Set<String> = []

    private func getExcludedSet(from list: [String]) -> Set<String> {
        if list == cachedExcludeList { return cachedExcludeSet }
        cachedExcludeList = list
        cachedExcludeSet = Set(list.map { $0.lowercased() })
        return cachedExcludeSet
    }

    private func resolvedPid(
        for app: NSRunningApplication,
        pidsByPath: [String: pid_t]? = nil
    ) -> pid_t? {
        let index: [String: pid_t]
        if let pidsByPath {
            index = pidsByPath
        } else if app.processIdentifier <= 0 {
            index = AppListService.pidsByNormalizedPath(AppListService.runningProcessPaths())
        } else {
            index = [:]
        }
        guard let pid = AppListService.resolvedProcessIdentifier(
            reportedPid: app.processIdentifier,
            executablePath: app.executableURL?.path,
            pidsByNormalizedPath: index
        ), QuitService.processIsRunning(pid) else { return nil }
        return pid
    }

    private func runningApplicationsWithResolvedPids() -> [(NSRunningApplication, pid_t)] {
        let applications = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        let needsRecovery = applications.contains {
            $0.processIdentifier <= 0 && $0.executableURL != nil
        }
        let index = needsRecovery
            ? AppListService.pidsByNormalizedPath(AppListService.runningProcessPaths())
            : [:]
        var seen = Set<pid_t>()
        return applications.compactMap { app in
            guard let pid = resolvedPid(for: app, pidsByPath: index),
                  seen.insert(pid).inserted else { return nil }
            return (app, pid)
        }
    }

    private func checkInactiveApps() async {
        let config = ConfigStore.shared.config
        let globalTimeout = config.quitInactiveAfterMinutes
        guard globalTimeout > 0 || !config.perAppQuitRules.isEmpty else {
            lastActiveTimestamps = lastActiveTimestamps.filter { QuitService.processIsRunning($0.key) }
            quittingPids = quittingPids.filter(QuitService.processIsRunning)
            return
        }

        let running = runningApplicationsWithResolvedPids()
        let runningPids = Set(running.map { $0.1 })
        lastActiveTimestamps = lastActiveTimestamps.filter { runningPids.contains($0.key) }
        quittingPids = quittingPids.intersection(runningPids)
        let saverActive = BatterySaver.isSaverActive(config: config)

        let now = Date()
        let excluded = getExcludedSet(from: config.exclude)
        let protectedMusicApps = config.musicApps.map { $0.lowercased() }
        let frontmostPid = NSWorkspace.shared.frontmostApplication.flatMap { frontmost in
            running.first(where: { $0.0 == frontmost })?.1 ?? resolvedPid(for: frontmost)
        }

        var appsToQuit: [AppInfo] = []

        for (app, pid) in running {
            guard app.activationPolicy == .regular else { continue }

            if pid == ProcessInfo.processInfo.processIdentifier || pid == frontmostPid {
                lastActiveTimestamps[pid] = now
                continue
            }
            if quittingPids.contains(pid) { continue }
            if let rawBid = app.bundleIdentifier, QuitXConstants.supportedBundleIdentifiers.contains(rawBid) {
                continue
            }
            if SystemAppProtection.isSystemProtected(
                bundleIdentifier: app.bundleIdentifier,
                isBackground: false,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL
            ) {
                continue
            }
            guard let lastActive = lastActiveTimestamps[pid] else {
                lastActiveTimestamps[pid] = now
                continue
            }

            let bundleId = app.bundleIdentifier?.lowercased()
            let name = app.localizedName?.lowercased()
            let timeoutMinutes = BatterySaver.effectiveTimeout(
                minutes: PerAppQuitRule.timeoutMinutes(
                    bundleId: app.bundleIdentifier,
                    name: app.localizedName ?? "",
                    rules: config.perAppQuitRules,
                    globalMinutes: globalTimeout
                ),
                saverActive: saverActive
            )
            guard timeoutMinutes > 0 else { continue }
            let threshold = now.addingTimeInterval(-Double(timeoutMinutes) * 60)
            guard lastActive < threshold else { continue }

            if let bundleId, excluded.contains(bundleId) { continue }
            if let name, excluded.contains(name) { continue }
            if app.bundleIdentifier == QuitXConstants.SystemBundleIds.finder { continue }

            if config.neverQuitMusic && protectedMusicApps.contains(where: {
                name?.contains($0) == true || bundleId?.contains($0) == true
            }) {
                continue
            }

            appsToQuit.append(AppInfo(
                name: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "Unknown",
                bundleId: app.bundleIdentifier,
                pid: pid,
                isBackground: false
            ))
        }

        guard !appsToQuit.isEmpty else { return }

        for app in appsToQuit {
            if let pid = app.pid { quittingPids.insert(pid) }
        }
        let results = await QuitService.shared.quit(apps: appsToQuit, force: false)
        let afterQuit = Date()
        let successful = results.filter(\.success).map(\.app)
        RecentlyQuitService.shared.record(apps: successful)

        for result in results {
            guard let pid = result.app.pid else { continue }
            if result.success {
                lastActiveTimestamps.removeValue(forKey: pid)
            } else {
                lastActiveTimestamps[pid] = afterQuit
            }
            quittingPids.remove(pid)
        }
    }
}
