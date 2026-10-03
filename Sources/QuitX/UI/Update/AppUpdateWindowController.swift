import AppKit
import SwiftUI

@MainActor
final class AppUpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = AppUpdateWindowController()
    private let windowWidth: CGFloat = 390
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func showUpdateWindow(targetVersion: String, downloadURL: URL, releaseWebURL: URL? = nil) {
        StatusItemController.shared?.closePopover()

        if let win = window {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                win.setFrameOrigin(windowOrigin(for: win.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(win)
            return
        }

        let contentView = AppUpdateView(
            service: UpdateDownloadService.shared,
            onDismiss: { [weak self] in
                self?.close()
            }
        )
        let hosting = NSHostingController(rootView: contentView)
        hosting.safeAreaRegions = []
        hosting.sizingOptions = [.preferredContentSize]
        let win = NSWindow(contentViewController: hosting)
        win.title = ""
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.titleVisibility = .hidden
        let fittingSize = hosting.sizeThatFits(
            in: NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        win.setContentSize(NSSize(width: windowWidth, height: ceil(fittingSize.height)))
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.animationBehavior = .documentWindow
        win.delegate = self
        self.window = win
        WindowActivationCoordinator.update()

        UpdateDownloadService.shared.startDownload(
            from: downloadURL,
            version: targetVersion,
            releaseWebURL: releaseWebURL
        )

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

        WindowAnimator.present(win, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
        window = nil
        UpdateDownloadService.shared.cancelDownload()
        WindowActivationCoordinator.update()
    }

    func closeWindow() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        UpdateDownloadService.shared.cancelDownload()
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
