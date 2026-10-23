import AppKit
import SwiftUI

@MainActor
final class UninstallWindowController: NSObject, NSWindowDelegate {
    static let shared = UninstallWindowController()

    static let defaultSize = NSSize(width: 600, height: 580)

    private var window: NSWindow?
    private var model: UninstallViewModel?

    var isOpen: Bool { window != nil }

    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.processName.contains("Tests")
            || ProcessInfo.processInfo.processName == "xctest"
    }

    func show(app: AppInfo) {
        guard let target = AppUninstaller.target(name: app.name, pid: app.pid, bundleIdentifier: app.bundleId) else { return }
        show(target: target)
    }

    func show(target: UninstallTarget) {
        StatusItemController.shared?.closePopover()

        if let window, let model, model.target == target {
            if !Self.isRunningTests { WindowAnimator.activateExisting(window) }
            return
        }

        let model = UninstallViewModel(target: target)
        self.model = model
        let rootView = UninstallView(model: model, onDismiss: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: rootView)

        if let window {
            window.contentViewController = hosting
            if !Self.isRunningTests { WindowAnimator.activateExisting(window) }
            return
        }

        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 560, height: 460)
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.tabbingMode = .disallowed
        window.animationBehavior = .none
        window.delegate = self
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        self.window = window
        guard !Self.isRunningTests else { return }

        WindowActivationCoordinator.update()

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: Self.defaultSize, on: screen)
        } else {
            window.center()
            targetFrame = NSRect(origin: window.frame.origin, size: Self.defaultSize)
        }
        window.setFrame(targetFrame, display: false)
        WindowAnimator.present(window, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
        window = nil
        model = nil
        WindowActivationCoordinator.update()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model?.phase != .removing
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        model = nil
        WindowActivationCoordinator.update()
    }
}
