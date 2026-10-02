import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController()
        AutoQuitService.shared.startTracking()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard ConfigStore.shared.config.autoUpdate else { return }
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: false)
        }

        let handleShowSettings: (Notification) -> Void = { notif in
            Task { @MainActor in
                let tab = (notif.userInfo?["tab"] as? String).flatMap { SettingsTab(rawValue: $0) }
                SettingsWindowController.shared.show(tab: tab)
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.quitx.showSettings"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        )
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.quitx.showPreferences"),
            object: nil,
            queue: .main,
            using: handleShowSettings
        )

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.quitx.showPopover"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.statusItemController?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController = nil
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc func showPreferencesWindow(_ sender: Any?) {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }
}
