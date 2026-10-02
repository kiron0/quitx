import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var activeTab: SettingsTab = .general
    private let tabModel = SettingsTabViewModel()
    private var hostingController: NSHostingController<AnyView>?

    func show(tab: SettingsTab? = nil) {
        StatusItemController.shared?.closePopover()

        let initialTab = tab ?? .general

        if let win = window {
            if let tab = tab {
                switchToTab(tab)
            }
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        activeTab = initialTab
        tabModel.activeTab = initialTab
        let totalHeight = initialTab.totalHeight
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: totalHeight)
        let win = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = initialTab.rawValue
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.titlebarSeparatorStyle = .none
        win.isOpaque = true
        win.backgroundColor = QuitXTheme.windowBackgroundNSColor
        win.isMovableByWindowBackground = true
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.delegate = self

        let container = SettingsContainerView(tabModel: tabModel) { [weak self] selectedTab in
            self?.switchToTab(selectedTab)
        }
        .environmentObject(ConfigStore.shared)
        .ignoresSafeArea()

        let hosting = NSHostingController(rootView: AnyView(container))
        self.hostingController = hosting
        win.contentViewController = hosting
        self.window = win

        NSApp.setActivationPolicy(.regular)

        let targetFrame = targetFrameFor(win, totalHeight: totalHeight)
        showAnimated(win: win, targetFrame: targetFrame)
    }

    private func targetFrameFor(_ win: NSWindow, totalHeight: CGFloat) -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return win.frame
        }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - 400) / 2

        let y = screenFrame.origin.y + screenFrame.height - totalHeight - 110
        return NSRect(x: x, y: y, width: 400, height: totalHeight)
    }

    private func showAnimated(win: NSWindow, targetFrame: NSRect) {
        win.setFrame(targetFrame, display: false)
        win.alphaValue = 0.0
        win.layoutIfNeeded()
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

    func windowWillClose(_ notification: Notification) {
        window = nil
        hostingController = nil
        NSApp.setActivationPolicy(.accessory)
    }

    func switchToTab(_ tab: SettingsTab) {
        guard let win = window else { return }
        if activeTab == tab { return }
        activeTab = tab

        tabModel.activeTab = tab
        win.title = tab.rawValue

        let targetHeight = tab.totalHeight
        let currentFrame = win.frame
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: 400, height: targetHeight)

        win.setFrame(newFrame, display: true)
    }
}
