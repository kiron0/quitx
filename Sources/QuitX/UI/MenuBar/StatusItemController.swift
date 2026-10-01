import AppKit
import SwiftUI

/// Owns the NSStatusItem and NSPopover. Single source of truth for menubar presence.
final class StatusItemController: NSObject {
    static weak var shared: StatusItemController?

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        super.init()
        Self.shared = self

        configureButton()
        configurePopover()
        startEventMonitor()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }

        // Load PNG from bundle Resources or fallback path
        if let iconURL = Bundle.main.url(forResource: "menubar", withExtension: "png"),
           let img = NSImage(contentsOf: iconURL) {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        } else if let img = NSImage(contentsOfFile: "Support/Icons/menubar.png") {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        } else {
            button.image = makeXIcon()
        }

        // Support both left and right click
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    /// Draws a simple X icon programmatically — zero-dependency fallback.
    private func makeXIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.labelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 3, y: 15))
        path.line(to: NSPoint(x: 15, y: 3))
        path.move(to: NSPoint(x: 15, y: 15))
        path.line(to: NSPoint(x: 3, y: 3))
        path.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func configurePopover() {
        let rootView = MainPopoverView()
            .environmentObject(ConfigStore.shared)
        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.contentSize = NSSize(width: 330, height: 470)
    }

    // MARK: - Click Handling

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover Actions

    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Context Menu on Right Click

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let stashItem = NSMenuItem(title: "Stash Session", action: #selector(stashSession), keyEquivalent: "")
        stashItem.target = self
        menu.addItem(stashItem)

        let restoreItem = NSMenuItem(title: "Restore Session", action: #selector(restoreSession), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.isEnabled = StashService.shared.hasStash
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About QuitX", action: #selector(openPreferences), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit QuitX", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func openPreferences() {
        SettingsWindowController.shared.show()
    }

    @objc private func stashSession() {
        let cfg = ConfigStore.shared.config
        let apps = AppListService.shared.fetchApps(config: cfg)
        Task {
            _ = await StashService.shared.stash(apps: apps)
        }
    }

    @objc private func restoreSession() {
        Task {
            _ = await StashService.shared.restore()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Outside-click dismissal

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }
    }
}
