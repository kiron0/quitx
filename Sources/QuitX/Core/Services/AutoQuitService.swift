import AppKit

final class AutoQuitService {
    static let shared = AutoQuitService()
    private var timer: Timer?
    private var lastActiveTimestamps: [pid_t: Date] = [:]

    private init() {
        startTracking()
    }

    func startTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkInactiveApps()
        }
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        lastActiveTimestamps[app.processIdentifier] = Date()
    }

    private func checkInactiveApps() {
        let config = ConfigStore.shared.config
        guard config.quitInactiveAfterMinutes > 0 else { return }

        let threshold = Date().addingTimeInterval(-Double(config.quitInactiveAfterMinutes * 60))
        let running = NSWorkspace.shared.runningApplications

        for app in running {
            guard app.activationPolicy == .regular,
                  let pid = app.processIdentifier as pid_t?,
                  let lastActive = lastActiveTimestamps[pid],
                  lastActive < threshold else { continue }

            // Check exclusions
            if let bid = app.bundleIdentifier, config.exclude.contains(bid) { continue }
            if let name = app.localizedName, config.exclude.contains(name) { continue }
            if app.bundleIdentifier == "com.apple.finder" { continue }

            // Quit inactive app
            app.terminate()
        }
    }
}
