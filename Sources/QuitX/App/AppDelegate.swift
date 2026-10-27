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
        CpuUsageSampler.start()
        UNUserNotificationCenter.current().delegate = HogNotificationDelegate.shared
        SingleInstanceService.shared.startMonitoring()
        AutoQuitService.shared.startTracking()
        SleepService.shared.start()
        AccessibilityPermission.shared.startObserving()
        FullDiskAccessManager.shared.triggerRegistration()
        LastWindowQuitService.shared.start()
        MemoryPressureService.shared.start()
        QuitTimerService.shared.start()
        HogMonitor.shared.startBackgroundMonitoring()
        statusItemController?.startMenuBarStats()
        UpdateChecker.shared.startAutomaticChecks()
        _ = ShortcutManager.shared
        WelcomeWindowController.shared.showIfFirstLaunch()
        ChangelogWindowController.shared.showIfUpdated()
    }

    private var distributedNotificationObservers: [NSObjectProtocol] = []

    func applicationWillTerminate(_ notification: Notification) {
        for obs in distributedNotificationObservers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        distributedNotificationObservers.removeAll()
        AutoQuitService.shared.stopTracking()
        SleepService.shared.stop()
        LastWindowQuitService.shared.stop()
        AccessibilityPermission.shared.stopObserving()
        MemoryPressureService.shared.stop()
        QuitTimerService.shared.stop()
        HogMonitor.shared.stopBackgroundMonitoring()
        UpdateChecker.shared.stopAutomaticChecks()
        SingleInstanceService.shared.stopMonitoring()
        CpuUsageSampler.stop()
        statusItemController = nil
        ConfigStore.shared.flush()
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc func showPreferencesWindow(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    @objc func showChangelogWindow(_ sender: Any?) {
        ChangelogWindowController.shared.show()
    }
}
