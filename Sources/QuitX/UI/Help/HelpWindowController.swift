import AppKit
import SwiftUI

@MainActor
final class HelpWindowController: NSObject, NSWindowDelegate {
    static let shared = HelpWindowController()

    private let frameAutosaveName = "QuitXHelpWindow"
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        StatusItemController.shared?.closePopover()

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.appearance = NSApp.effectiveAppearance
        window.isMovableByWindowBackground = true
        window.tabbingMode = .disallowed
        window.delegate = self

        if !window.setFrameUsingName(frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(frameAutosaveName)

        self.window = window
        WindowActivationCoordinator.update()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}
