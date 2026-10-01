import AppKit
import SwiftUI

/// Owns the NSStatusItem and NSPopover. Single source of truth for menubar presence.
final class StatusItemController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

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

        button.action = #selector(togglePopover)
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
        // Diagonal 1: top-left to bottom-right
        path.move(to: NSPoint(x: 3, y: 15))
        path.line(to: NSPoint(x: 15, y: 3))
        // Diagonal 2: top-right to bottom-left
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

    // MARK: - Toggle

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
