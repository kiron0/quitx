import AppKit
import SwiftUI

@MainActor
final class ChangelogWindowController: NSObject, NSWindowDelegate {
    static let shared = ChangelogWindowController()

    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName == "xctest"
    }

    func showIfUpdated(defaults: UserDefaults = .standard) {
        let currentVersion = UpdateChecker.shared.currentVersion
        guard !currentVersion.isEmpty else { return }

        let firstLaunchSeen = defaults.bool(forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen)
        let lastSeen = defaults.string(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)
        defaults.set(currentVersion, forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)

        guard Self.shouldPresent(
            currentVersion: currentVersion,
            lastSeenVersion: lastSeen,
            firstLaunchSeen: firstLaunchSeen,
            welcomeIsOpen: WelcomeWindowController.shared.isOpen
        ) else { return }
        show(version: currentVersion)
    }

    static func shouldPresent(
        currentVersion: String,
        lastSeenVersion: String?,
        firstLaunchSeen: Bool,
        welcomeIsOpen: Bool
    ) -> Bool {
        guard !currentVersion.isEmpty, firstLaunchSeen, !welcomeIsOpen else { return false }
        guard let lastSeenVersion, !lastSeenVersion.isEmpty else { return true }
        return VersionComparator.isGreaterThan(currentVersion, lastSeenVersion)
    }

    func show(version: String? = nil) {
        StatusItemController.shared?.closePopover()

        if let window {
            if !Self.isRunningTests {
                if let screen = WindowPositioner.targetScreen {
                    window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
                }
                WindowAnimator.activateExisting(window)
            }
            return
        }

        let targetVersion = version ?? UpdateChecker.shared.currentVersion

        let rootView = ChangelogView(
            initialVersion: targetVersion,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 740, height: 520))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.animationBehavior = .none
        window.delegate = self

        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = window
        guard !Self.isRunningTests else { return }

        WindowActivationCoordinator.update()

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }

        WindowAnimator.present(window, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
        window = nil
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}
