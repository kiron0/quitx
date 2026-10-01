import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()
    private var window: NSWindow?

    func showIfFirstLaunch() {
        let key = "quitx_first_launch_seen_v1"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            show()
        }
    }

    func show() {
        if let win = window {
            positionTopCenter(win)
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = WelcomeView(
            onDismiss: { [weak self] in
                self?.close()
            },
            onOpenSettings: { [weak self] in
                self?.close()
                SettingsWindowController.shared.show()
            }
        ).environmentObject(ConfigStore.shared)

        let hosting = NSHostingController(rootView: rootView)
        let win = NSPanel(contentViewController: hosting)
        win.styleMask = [.borderless, .nonactivatingPanel]
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win

        positionTopCenter(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
    }

    private func positionTopCenter(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let winSize = win.frame.size
        let x = screenFrame.origin.x + (screenFrame.width - winSize.width) / 2
        let y = screenFrame.origin.y + screenFrame.height - winSize.height - 160
        win.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
