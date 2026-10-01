import AppKit
import SwiftUI

extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier("General")
    static let shortcuts = NSToolbarItem.Identifier("Shortcuts")
    static let support = NSToolbarItem.Identifier("Support")
    static let about = NSToolbarItem.Identifier("About")
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var activeTab: SettingsTab = .general
    private var hostingController: NSHostingController<AnyView>?

    func show() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            positionTopCenter(win)
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: SettingsTab.general.contentHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "General"
        win.toolbarStyle = .preference
        win.isOpaque = true
        win.backgroundColor = QuitAllTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.delegate = self

        let toolbar = NSToolbar(identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = .general
        win.toolbar = toolbar

        let hosting = NSHostingController(rootView: viewForTab(.general))
        self.hostingController = hosting
        win.contentViewController = hosting
        self.window = win

        positionTopCenter(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
    }

    func switchToTab(_ tab: SettingsTab) {
        guard let win = window, activeTab != tab else { return }
        activeTab = tab
        win.title = tab.rawValue
        win.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(tab.rawValue)

        let targetHeight = tab.contentHeight
        let currentFrame = win.frame
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 400, height: targetHeight)

        hostingController?.rootView = viewForTab(tab)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().setFrame(newFrame, display: true)
        }
    }

    private func viewForTab(_ tab: SettingsTab) -> AnyView {
        switch tab {
        case .general:
            return AnyView(
                GeneralTabCloneView()
                    .environmentObject(ConfigStore.shared)
                    .background(QuitAllTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .shortcuts:
            return AnyView(
                ShortcutsTabCloneView()
                    .background(QuitAllTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .support:
            return AnyView(
                SupportTabCloneView()
                    .background(QuitAllTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .about:
            return AnyView(
                AboutTabCloneView()
                    .background(QuitAllTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        }
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) else { return }
        switchToTab(tab)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.paletteLabel = tab.rawValue
        item.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: tab.rawValue)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .shortcuts, .support, .about]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .shortcuts, .support, .about]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .shortcuts, .support, .about]
    }

    private func positionTopCenter(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let winSize = win.frame.size
        let x = screenFrame.origin.x + (screenFrame.width - winSize.width) / 2
        let y = screenFrame.origin.y + screenFrame.height - winSize.height - 105
        win.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
