import AppKit
import SwiftUI

@MainActor
final class AppUpdateWindowController: NSWindowController, NSWindowDelegate {
    static let shared = AppUpdateWindowController()

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isOpen: Bool { window?.isVisible ?? false }

    func showUpdateWindow(targetVersion: String, downloadURL: URL, releaseWebURL: URL? = nil) {
        let updateWindow: NSWindow

        let isExisting = window != nil
        if let existing = window {
            updateWindow = existing
        } else {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 240),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.title = "QuitX Update"
            win.isMovableByWindowBackground = true
            win.isReleasedWhenClosed = false
            win.animationBehavior = .documentWindow
            win.delegate = self
            win.center()

            self.window = win
            updateWindow = win
        }

        let contentView = AppUpdateView(
            service: UpdateDownloadService.shared,
            onDismiss: { [weak self] in
                self?.closeWindow()
            }
        )
        updateWindow.contentView = NSHostingView(rootView: contentView)

        UpdateDownloadService.shared.startDownload(
            from: downloadURL,
            version: targetVersion,
            releaseWebURL: releaseWebURL
        )

        updateWindow.center()
        let targetFrame = updateWindow.frame
        if isExisting {
            WindowAnimator.activateExisting(updateWindow)
        } else {
            WindowAnimator.present(updateWindow, targetFrame: targetFrame)
        }
    }

    func closeWindow() {
        if let win = window, win.isVisible {
            win.orderOut(nil)
        }
        UpdateDownloadService.shared.cancelDownload()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            UpdateDownloadService.shared.cancelDownload()
        }
    }
}
