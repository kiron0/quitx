import AppKit
import QuartzCore

@MainActor
enum WindowAnimator {
    static func present(
        _ window: NSWindow,
        targetFrame: NSRect,
        duration: TimeInterval = 0.28
    ) {
        window.animationBehavior = .documentWindow
        window.setFrame(targetFrame, display: true)
        window.alphaValue = 1.0

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        guard let view = window.contentView?.superview ?? window.contentView else { return }
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, bounds.midX, bounds.midY, 0)
        t = CATransform3DScale(t, 0.88, 0.88, 1.0)
        t = CATransform3DTranslate(t, -bounds.midX, -bounds.midY, 0)

        let scaleAnim = CABasicAnimation(keyPath: "transform")
        scaleAnim.fromValue = NSValue(caTransform3D: t)
        scaleAnim.toValue = NSValue(caTransform3D: CATransform3DIdentity)

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0.0
        opacityAnim.toValue = 1.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, opacityAnim]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        group.fillMode = .both
        group.isRemovedOnCompletion = true

        layer.removeAnimation(forKey: "quitxWindowOpenAnimation")
        layer.add(group, forKey: "quitxWindowOpenAnimation")
    }

    static func activateExisting(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        guard let view = window.contentView?.superview ?? window.contentView else { return }
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, bounds.midX, bounds.midY, 0)
        t = CATransform3DScale(t, 1.025, 1.025, 1.0)
        t = CATransform3DTranslate(t, -bounds.midX, -bounds.midY, 0)

        let pulseAnim = CAKeyframeAnimation(keyPath: "transform")
        pulseAnim.values = [
            NSValue(caTransform3D: CATransform3DIdentity),
            NSValue(caTransform3D: t),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        pulseAnim.keyTimes = [0.0, 0.45, 1.0]
        pulseAnim.duration = 0.22
        pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.removeAnimation(forKey: "quitxWindowPulseAnimation")
        layer.add(pulseAnim, forKey: "quitxWindowPulseAnimation")
    }
}
