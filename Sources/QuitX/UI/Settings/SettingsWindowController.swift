import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            positionTopCenter(win)
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView()
            .environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: rootView)
        let win = NSWindow(contentViewController: hosting)
        win.title = "General"
        win.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .visible
        win.setContentSize(NSSize(width: 400, height: 555))
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win

        positionTopCenter(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    func updateHeight(for tab: SettingsTab) {
        guard let win = window else { return }
        let newHeight = tab.contentHeight
        let currentFrame = win.frame
        let newY = currentFrame.maxY - newHeight // Anchor top edge so resize animates downwards
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 400, height: newHeight)
        win.setFrame(newFrame, display: true, animate: true)
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
