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

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        lastActiveTimestamps[app.processIdentifier] = Date()
    }

    private func checkInactiveApps() {
        let config = ConfigStore.shared.config
        guard config.quitInactiveAfterMinutes > 0 else { return }

        let now = Date()
        let threshold = now.addingTimeInterval(-Double(config.quitInactiveAfterMinutes) * 60)
        let running = NSWorkspace.shared.runningApplications
        let runningPids = Set(running.map(\.processIdentifier))
        lastActiveTimestamps = lastActiveTimestamps.filter { runningPids.contains($0.key) }
        let excluded = Set(config.exclude.map { $0.lowercased() })
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
