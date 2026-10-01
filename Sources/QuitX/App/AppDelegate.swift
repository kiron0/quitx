import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app does not appear in Dock or Cmd-Tab switcher
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController()
        AutoQuitService.shared.startTracking()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("io.coreify.quitx.showPreferences"),
            object: nil,
            queue: .main
        ) { notif in
            Task { @MainActor in
                let tab = (notif.userInfo?["tab"] as? String).flatMap { SettingsTab(rawValue: $0) }
                SettingsWindowController.shared.show(tab: tab)
            }
        }

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
}
