import AppKit
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

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        let targetTab = tab ?? .general

        if let win = window {
            if let tab = tab {
                switchToTab(tab)
            }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
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

        NSApp.setActivationPolicy(.regular)

        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
        toolbar = nil
        NSApp.setActivationPolicy(.accessory)
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

        win.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - NSToolbarDelegate

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
