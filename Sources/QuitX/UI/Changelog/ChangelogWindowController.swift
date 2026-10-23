import AppKit
import SwiftUI

@MainActor
final class ChangelogWindowController: NSObject, NSWindowDelegate {
    static let shared = ChangelogWindowController()

    static let compactSize = NSSize(width: 400, height: 490)
    static let expandedSize = NSSize(width: 740, height: 520)

    private var window: NSWindow?
    private(set) var isExpanded: Bool = false

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

        let targetVersion = version ?? UpdateChecker.shared.currentVersion
        let latestVersion = ChangelogProvider.releases().first?.version ?? targetVersion
        let shouldStartExpanded = (version != nil && version != latestVersion)

        if let window {
            if isExpanded != shouldStartExpanded {
                setExpanded(shouldStartExpanded, animate: false)
            }
            if !Self.isRunningTests {
                if let screen = WindowPositioner.targetScreen {
                    window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
                }
                WindowAnimator.activateExisting(window)
            }
            return
        }

        self.isExpanded = shouldStartExpanded
        let initialSize = shouldStartExpanded ? Self.expandedSize : Self.compactSize

        let rootView = ChangelogView(
            initialVersion: targetVersion,
            onDismiss: { [weak self] in
                self?.close()
            },
            onToggleExpand: { [weak self] expanded in
                self?.setExpanded(expanded)
            }
        )

        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(initialSize)
        window.minSize = initialSize
        window.maxSize = initialSize
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

    func setExpanded(_ expanded: Bool, animate: Bool = true) {
        self.isExpanded = expanded
        guard let window else { return }
        let targetSize = expanded ? Self.expandedSize : Self.compactSize
        guard window.frame.size != targetSize else { return }

        var currentFrame = window.frame
        let widthDelta = targetSize.width - currentFrame.size.width
        let heightDelta = targetSize.height - currentFrame.size.height
        currentFrame.origin.x -= widthDelta / 2
        currentFrame.origin.y -= heightDelta / 2
        currentFrame.size = targetSize
        window.minSize = targetSize
        window.maxSize = targetSize
        window.setFrame(currentFrame, display: true, animate: !Self.isRunningTests && animate)
    }

    func close() {
        window?.close()
        window = nil
        isExpanded = false
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        isExpanded = false
        WindowActivationCoordinator.update()
    }
}
