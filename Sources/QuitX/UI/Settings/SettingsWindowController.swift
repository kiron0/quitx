import AppKit
import SwiftUI

extension NSToolbarItem.Identifier {
    static let general = NSToolbarItem.Identifier("General")
    static let shortcuts = NSToolbarItem.Identifier("Shortcuts")
    static let support = NSToolbarItem.Identifier("Support")
    static let about = NSToolbarItem.Identifier("About")
}

final class SettingsTabViewModel: ObservableObject {
    @Published var activeTab: SettingsTab = .general
}

struct SettingsToolbarTabItemView: View {
    let tab: SettingsTab
    @ObservedObject var tabModel: SettingsTabViewModel
    let onSelect: () -> Void

    var isSelected: Bool {
        tabModel.activeTab == tab
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? QuitXTheme.accent : Color.white.opacity(0.65))
                    .frame(height: 18)

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? QuitXTheme.accent : Color.white.opacity(0.65))
            }
            .frame(width: 58, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var activeTab: SettingsTab = .general
    private let tabModel = SettingsTabViewModel()
    private var hostingController: NSHostingController<AnyView>?

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        let initialTab = tab ?? .general

        if let win = window {
            if let tab = tab {
                switchToTab(tab)
            }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        activeTab = initialTab
        tabModel.activeTab = initialTab
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: initialTab.contentHeight)
        let win = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = initialTab.rawValue
        win.titleVisibility = .visible
        win.titlebarAppearsTransparent = false
        win.toolbarStyle = .preference
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.delegate = self

        let toolbar = NSToolbar(identifier: "PreferencesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier(initialTab.rawValue)
        win.toolbar = toolbar

        let hosting = NSHostingController(rootView: viewForTab(initialTab))
        self.hostingController = hosting
        win.contentViewController = hosting
        self.window = win

        centerWindow(win, contentHeight: initialTab.contentHeight)
        win.alphaValue = 0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            win.animator().alphaValue = 1.0
        }
    }

    private func centerWindow(_ win: NSWindow, contentHeight: CGFloat) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let targetContentRect = NSRect(x: 0, y: 0, width: 400, height: contentHeight)
        let targetWindowFrame = win.frameRect(forContentRect: targetContentRect)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - targetWindowFrame.width) / 2
        // Top-center: positioned neatly below the menu bar
        let y = screenFrame.origin.y + screenFrame.height - targetWindowFrame.height - 110
        win.setFrame(NSRect(x: x, y: y, width: targetWindowFrame.width, height: targetWindowFrame.height), display: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
    }

    func switchToTab(_ tab: SettingsTab) {
        guard let win = window else { return }
        if activeTab == tab && hostingController != nil { return }
        activeTab = tab
        tabModel.activeTab = tab
        win.title = tab.rawValue
        win.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(tab.rawValue)

        let contentRect = NSRect(x: 0, y: 0, width: 400, height: tab.contentHeight)
        let targetWindowFrame = win.frameRect(forContentRect: contentRect)
        let currentFrame = win.frame
        let newY = currentFrame.maxY - targetWindowFrame.height
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 400, height: targetWindowFrame.height)

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
                    .background(QuitXTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .shortcuts:
            return AnyView(
                ShortcutsTabCloneView()
                    .background(QuitXTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .support:
            return AnyView(
                SupportTabCloneView()
                    .background(QuitXTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        case .about:
            return AnyView(
                AboutTabCloneView()
                    .background(QuitXTheme.windowBackground)
                    .preferredColorScheme(.dark)
            )
        }
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        return true
    }

    // MARK: - NSToolbarDelegate

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.paletteLabel = tab.rawValue

        let tabView = SettingsToolbarTabItemView(tab: tab, tabModel: tabModel) { [weak self] in
            self?.switchToTab(tab)
        }
        let hosting = NSHostingView(rootView: tabView)
        hosting.frame = NSRect(x: 0, y: 0, width: 58, height: 44)
        item.view = hosting
        item.minSize = NSSize(width: 52, height: 42)
        item.maxSize = NSSize(width: 64, height: 46)
        item.autovalidates = false
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
}
