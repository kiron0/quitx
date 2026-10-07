import AppKit
import Combine
import SwiftUI

private final class SettingsWindow: NSWindow {
    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        0.18
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var activeTab: SettingsTab = .general
    private let tabModel = SettingsTabViewModel()
    private var hostingController: NSHostingController<AnyView>?
    private var toolbar: NSToolbar?
    private var chromeObserver: AnyCancellable?
    private var appliedGlass: Bool?

    private override init() {
        super.init()
        chromeObserver = ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyWindowChrome() }
            }
    }

    private func applyWindowChrome() {
        guard let win = window else { return }
        let enabled = LiquidGlass.enabled
        guard appliedGlass != enabled else { return }
        appliedGlass = enabled
        let savedFrame = win.frame
        if enabled {
            if !win.styleMask.contains(.fullSizeContentView) {
                win.styleMask.insert(.fullSizeContentView)
            }
            win.isOpaque = false
            win.backgroundColor = .clear
            let inset = win.frame.height - win.contentRect(forFrameRect: win.frame).height
            if inset > 0 {
                tabModel.glassTopInset = inset
            }
        } else {
            if win.styleMask.contains(.fullSizeContentView) {
                win.styleMask.remove(.fullSizeContentView)
            }
            win.isOpaque = true
            win.backgroundColor = QuitXTheme.toolbarBackgroundNSColor
            tabModel.glassTopInset = 0
        }
        win.titlebarAppearsTransparent = true
        if win.frame != savedFrame {
            win.setFrame(savedFrame, display: true, animate: false)
        }
    }

    var isOpen: Bool { window != nil }

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        let targetTab = tab ?? .general

        if let win = window {
            if let tab = tab {
                switchToTab(tab)
            }
            if let screen = WindowPositioner.targetScreen {
                let targetFrame = targetFrameFor(win, tab: activeTab, screen: screen)
                win.setFrame(targetFrame, display: true)
            }
            WindowAnimator.activateExisting(win)
            return
        }

        activeTab = targetTab
        tabModel.activeTab = targetTab

        let initialContentRect = NSRect(x: 0, y: 0, width: 400, height: targetTab.contentHeight)

        let win = SettingsWindow(
            contentRect: initialContentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = targetTab.rawValue
        if LiquidGlass.enabled {
            win.styleMask.insert(.fullSizeContentView)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.titlebarAppearsTransparent = true
        } else {
            win.styleMask.remove(.fullSizeContentView)
            win.isOpaque = true
            win.backgroundColor = QuitXTheme.toolbarBackgroundNSColor
            win.titlebarAppearsTransparent = true
        }
        appliedGlass = LiquidGlass.enabled
        win.titlebarSeparatorStyle = .line
        win.isMovableByWindowBackground = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.animationBehavior = .documentWindow
        win.delegate = self

        let tb = NSToolbar(identifier: "QuitXSettingsToolbar")
        tb.allowsUserCustomization = false
        tb.autosavesConfiguration = false
        tb.displayMode = .iconAndLabel
        tb.delegate = self
        tb.selectedItemIdentifier = targetTab.toolbarItemIdentifier
        self.toolbar = tb
        win.toolbar = tb
        win.toolbarStyle = .preference

        let container = SettingsContainerView(tabModel: tabModel)
            .environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: AnyView(container))
        self.hostingController = hosting
        win.contentViewController = hosting
        self.window = win

        WindowActivationCoordinator.update()

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = targetFrameFor(win, tab: targetTab, screen: screen)
        } else {
            win.center()
            targetFrame = win.frame
        }
        WindowAnimator.present(win, targetFrame: targetFrame)

        if LiquidGlass.enabled {
            let inset = win.frame.height - win.contentRect(forFrameRect: win.frame).height
            if inset > 0 {
                tabModel.glassTopInset = inset
            }
        }
    }

    private func targetFrameFor(_ win: NSWindow, tab: SettingsTab, screen: NSScreen) -> NSRect {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: tab.contentHeight)
        let frameRect = win.frameRect(forContentRect: contentRect)
        return WindowPositioner.topBiasedFrame(for: frameRect.size, on: screen)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
        toolbar = nil
        WindowActivationCoordinator.update()
    }

    func switchToTab(_ tab: SettingsTab) {
        guard let win = window else { return }
        if activeTab == tab { return }
        activeTab = tab

        toolbar?.selectedItemIdentifier = tab.toolbarItemIdentifier
        win.title = tab.rawValue

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tabModel.activeTab = tab
        }

        let targetContentRect = NSRect(x: 0, y: 0, width: 400, height: tab.contentHeight)
        let targetFrameRect = win.frameRect(forContentRect: targetContentRect)
        let targetHeight = targetFrameRect.height

        let currentFrame = win.frame
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 400, height: targetHeight)

        win.setFrame(newFrame, display: true, animate: false)
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map { $0.toolbarItemIdentifier }
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    nonisolated func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    @objc func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.paletteLabel = tab.rawValue
        item.image = tab.toolbarImage
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) else { return }
        switchToTab(tab)
    }
}
