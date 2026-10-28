import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsNavigationModel: ObservableObject {
    @Published private(set) var selection: SettingsTab = .overview
    @Published var searchText = ""
    @Published var hoveredTab: SettingsTab?
    @Published var hoveredCard: String?

    func select(_ tab: SettingsTab) {
        guard selection != tab else { return }
        HelpPopoverState.closeAll()
        NotificationCenter.default.post(name: QuitXConstants.Notifications.dismissSettingsTooltips, object: nil)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selection = tab
        }
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    let navigation = SettingsNavigationModel()
    private var window: NSWindow?

    var isOpen: Bool { window != nil }
    var activeTab: SettingsTab { navigation.selection }

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        if let window {
            dismissTooltips(for: window)
            if let tab { navigation.select(tab) }
            if let screen = WindowPositioner.targetScreen, !window.frame.intersects(screen.visibleFrame) {
                window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(window)
            return
        }

        navigation.searchText = ""
        navigation.select(tab ?? .overview)

        let root = SettingsRootView(navigation: navigation)
            .environmentObject(ConfigStore.shared)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = "QuitX Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(SettingsTab.windowSize)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.tabbingMode = .disallowed
        window.animationBehavior = .none
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }

        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: targetFrame)
    }

    func switchToTab(_ tab: SettingsTab) {
        if let window { dismissTooltips(for: window) }
        navigation.select(tab)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        HelpPopoverState.closeAll()
        let uninstallModel = UninstallWindowController.shared.model
        if uninstallModel.phase != .removing { uninstallModel.cancelWork() }
        window = nil
        WindowActivationCoordinator.update()
    }

    private func dismissTooltips(for win: NSWindow) {
        HelpPopoverState.closeAll()
        NotificationCenter.default.post(name: QuitXConstants.Notifications.dismissSettingsTooltips, object: nil)
        for child in win.childWindows ?? [] where "\(type(of: child))".contains("Popover") || child.className.contains("Popover") {
            child.orderOut(nil)
            win.removeChildWindow(child)
        }
    }
}
