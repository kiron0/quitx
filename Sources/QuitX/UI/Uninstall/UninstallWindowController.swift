import AppKit
import SwiftUI

@MainActor
final class UninstallWindowController: NSObject, NSWindowDelegate {
    static let shared = UninstallWindowController()

    static let defaultSize = NSSize(width: 620, height: 600)

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
        let model = prepare()
        if model.phase != .removing, !(model.screen == .review && model.targets == [target]) {
            model.startReview([target], fromPicker: false)
        }
        present()
    }

    func showPicker() {
        let model = prepare()
        if model.phase != .removing, model.screen != .picker || model.pickerApps.isEmpty {
            model.showPicker()
        }
        present()
    }

    private func prepare() -> UninstallViewModel {
        StatusItemController.shared?.closePopover()
        if let model { return model }
        let model = UninstallViewModel()
        self.model = model
        return model
    }

    private func present() {
        guard let model else { return }
        if let window {
            if !Self.isRunningTests { WindowAnimator.activateExisting(window) }
            return
        }

        let rootView = UninstallView(model: model, onDismiss: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: rootView)
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
        guard model?.phase != .removing else { return }
        window?.close()
        teardown()
    }

    private func teardown() {
        model?.cancelWork()
        window = nil
        model = nil
        WindowActivationCoordinator.update()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model?.phase != .removing
    }

    func windowWillClose(_ notification: Notification) {
        teardown()
    }
}
