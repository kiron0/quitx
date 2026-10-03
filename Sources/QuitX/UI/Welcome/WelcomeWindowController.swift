import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindowController()
    private let windowWidth: CGFloat = 390
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func showIfFirstLaunch() {
        let key = "quitx_first_launch_seen_v1"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            show()
        }
    }

    func show() {
        StatusItemController.shared?.closePopover()

        if let win = window {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                win.setFrameOrigin(windowOrigin(for: win.frame.size, on: screen))
            }
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
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        let fittingSize = hosting.sizeThatFits(
            in: NSSize(width: windowWidth, height: .greatestFiniteMagnitude)
        )
        win.setContentSize(NSSize(width: windowWidth, height: ceil(fittingSize.height)))
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win
        WindowActivationCoordinator.update()

        let targetFrame: NSRect
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            targetFrame = NSRect(
                origin: windowOrigin(for: win.frame.size, on: screen),
                size: win.frame.size
            )
        } else {
            win.center()
            targetFrame = win.frame
        }

        win.setFrame(targetFrame, display: false)
        win.alphaValue = 0.0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 1.0
        }
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }

    private func windowOrigin(for size: NSSize, on screen: NSScreen) -> NSPoint {
        let visibleFrame = screen.visibleFrame
        return NSPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 110
        )
    }
}
