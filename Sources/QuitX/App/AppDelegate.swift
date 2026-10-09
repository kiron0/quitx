import AppKit
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerDistributedObservers()

        Task { @MainActor [weak self] in
            guard await SingleInstanceService.shared.prepareForLaunch() else {
                NSApp.terminate(nil)
                return
            }
            self?.finishLaunching()
        }
    }

    private func registerDistributedObservers() {
        let handleShowSettings: @Sendable (Notification) -> Void = { notification in
            let rawTab = notification.userInfo?["tab"] as? String
            Task { @MainActor in
                let tab = rawTab.flatMap { SettingsTab(rawValue: $0) }
                SettingsWindowController.shared.show(tab: tab)
            }
        }
        let obs1 = DistributedNotificationCenter.default().addObserver(
            forName: QuitXConstants.Notifications.showSettings,
            object: nil,
            queue: .main,
            using: handleShowSettings
        )
        let obs2 = DistributedNotificationCenter.default().addObserver(
            forName: QuitXConstants.Notifications.showPreferences,
            object: nil,
            queue: .main,
            using: handleShowSettings
        )
        let obs3 = DistributedNotificationCenter.default().addObserver(
            forName: QuitXConstants.Notifications.showPopover,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.statusItemController?.showPopover()
            }
        }
        distributedNotificationObservers = [obs1, obs2, obs3]
    }

    private func finishLaunching() {
        statusItemController = StatusItemController()
        UNUserNotificationCenter.current().delegate = HogNotificationDelegate.shared
        SingleInstanceService.shared.startMonitoring()
        AutoQuitService.shared.startTracking()
        SleepService.shared.start()
        MemoryPressureService.shared.start()
        BatteryTriggerService.shared.start()
        QuitTimerService.shared.start()
        HogMonitor.shared.startBackgroundMonitoring()
        statusItemController?.startMenuBarStats()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard ConfigStore.shared.config.autoUpdate else { return }
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: false)
        }
    }

    private var distributedNotificationObservers: [NSObjectProtocol] = []

    func applicationWillTerminate(_ notification: Notification) {
        for obs in distributedNotificationObservers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        distributedNotificationObservers.removeAll()
        AutoQuitService.shared.stopTracking()
        SleepService.shared.stop()
        MemoryPressureService.shared.stop()
        BatteryTriggerService.shared.stop()
        QuitTimerService.shared.stop()
        HogMonitor.shared.stopBackgroundMonitoring()
        SingleInstanceService.shared.stopMonitoring()
        statusItemController = nil
        ConfigStore.shared.flush()
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc func showPreferencesWindow(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }
}
