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
        StatusItemController.shared?.closePopover()

        if let win = window {
            win.center()
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
        win.title = "Welcome to QuitX"
        win.styleMask = [.titled, .closable]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .visible
        win.setContentSize(NSSize(width: 440, height: 600))
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isEnabled = true
        win.standardWindowButton(.closeButton)?.isHidden = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.delegate = self
        self.window = win

        let targetFrame: NSRect
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.origin.x + (screenFrame.width - 440) / 2
            let y = screenFrame.origin.y + (screenFrame.height - 600) / 2
            targetFrame = NSRect(x: x, y: y, width: 440, height: 600)
        } else {
            win.center()
            targetFrame = win.frame
        }

        win.setFrame(targetFrame, display: false)
        win.alphaValue = 0.0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        guard let sup = win.contentView?.superview else {
            win.alphaValue = 1.0
            return
        }
        sup.wantsLayer = true
        guard let layer = sup.layer else {
            win.alphaValue = 1.0
            return
        }

        layer.removeAllAnimations()

        let midX = sup.bounds.midX
        let midY = sup.bounds.midY

        func makeTransform(scale: CGFloat) -> CATransform3D {
            var t = CATransform3DIdentity
            t = CATransform3DTranslate(t, midX, midY, 0)
            t = CATransform3DScale(t, scale, scale, 1.0)
            t = CATransform3DTranslate(t, -midX, -midY, 0)
            return t
        }

        let scaleAnim = CAKeyframeAnimation(keyPath: "transform")
        scaleAnim.values = [
            NSValue(caTransform3D: makeTransform(scale: 0.88)),
            NSValue(caTransform3D: makeTransform(scale: 1.0)),
            NSValue(caTransform3D: makeTransform(scale: 0.988)),
            NSValue(caTransform3D: makeTransform(scale: 1.0))
        ]
        scaleAnim.keyTimes = [0.0, 0.60, 0.82, 1.0]
        scaleAnim.duration = 0.28
        scaleAnim.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.0
        opacityAnim.toValue = 1.0
        opacityAnim.duration = 0.16
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        layer.add(scaleAnim, forKey: "windowBounce")
        layer.add(opacityAnim, forKey: "windowFade")
        CATransaction.commit()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
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
    }
}
