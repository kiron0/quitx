import AppKit
import SwiftUI

@MainActor
final class HelpWindowController: NSObject, NSWindowDelegate {
    static let shared = HelpWindowController()

    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        StatusItemController.shared?.closePopover()

        if let window {
            WindowAnimator.activateExisting(window)
            return
        }

        let hosting = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 740, height: 520))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.fullScreenNone]
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = QuitXTheme.windowBackgroundNSColor
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.animationBehavior = .documentWindow
        window.delegate = self

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let sf = screen.visibleFrame
            let origin = NSPoint(
                x: sf.midX - window.frame.width / 2,
                y: sf.maxY - window.frame.height - 110
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: window.frame)
    }

    func close() {
        window?.close()
        window = nil
        WindowActivationCoordinator.update()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}
