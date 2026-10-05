import AppKit

@MainActor
final class AutoQuitService {
    static let shared = AutoQuitService()
    private var timer: Timer?
    private var lastActiveTimestamps: [pid_t: Date] = [:]

    private init() {}

    func startTracking() {
        guard timer == nil else { return }

        let now = Date()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            lastActiveTimestamps[app.processIdentifier] = now
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkInactiveApps()
            }
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        lastActiveTimestamps.removeAll()
    }

    deinit {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        lastActiveTimestamps[app.processIdentifier] = Date()
    }

    private var cachedExcludeList: [String] = []
    private var cachedExcludeSet: Set<String> = []

    private func getExcludedSet(from list: [String]) -> Set<String> {
        if list == cachedExcludeList { return cachedExcludeSet }
        cachedExcludeList = list
        cachedExcludeSet = Set(list.map { $0.lowercased() })
        return cachedExcludeSet
    }

    private func checkInactiveApps() {
        let config = ConfigStore.shared.config
        guard config.quitInactiveAfterMinutes > 0 else { return }

        let now = Date()
        let threshold = now.addingTimeInterval(-Double(config.quitInactiveAfterMinutes) * 60)
        let running = NSWorkspace.shared.runningApplications
        let runningPids = Set(running.map(\.processIdentifier))
        lastActiveTimestamps = lastActiveTimestamps.filter { runningPids.contains($0.key) }
        let excluded = getExcludedSet(from: config.exclude)
        let protectedMusicApps = config.musicApps.map { $0.lowercased() }
        let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier

        for app in running {
            guard app.activationPolicy == .regular else { continue }

            let pid = app.processIdentifier
            if pid == ProcessInfo.processInfo.processIdentifier || pid == frontmostPid {
                lastActiveTimestamps[pid] = now
                continue
            }
            if let rawBid = app.bundleIdentifier, QuitXIdentity.supportedBundleIdentifiers.contains(rawBid) {
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
            guard lastActive < threshold else { continue }

            let bundleId = app.bundleIdentifier?.lowercased()
            let name = app.localizedName?.lowercased()
            if let bundleId, excluded.contains(bundleId) { continue }
            if let name, excluded.contains(name) { continue }
            if app.bundleIdentifier == "com.apple.finder" { continue }

            if config.neverQuitMusic && protectedMusicApps.contains(where: {
                name?.contains($0) == true || bundleId?.contains($0) == true
            }) {
                continue
            }

            app.terminate()
        }
    }
}
