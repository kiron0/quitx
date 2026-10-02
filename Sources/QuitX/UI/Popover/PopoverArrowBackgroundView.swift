import AppKit

final class PopoverArrowBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        autoresizingMask = [.width, .height]
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let superview = self.superview else { return }

        typealias MaskFn = @convention(c) (AnyObject, Selector, NSRect) -> CGPath?
        let sel = NSSelectorFromString("_copyFrameMaskPathInRect:")
        let cgPath: CGPath?

        if superview.responds(to: sel) {
            let imp = class_getMethodImplementation(type(of: superview), sel)
            let fn = unsafeBitCast(imp, to: MaskFn.self)
            cgPath = fn(superview, sel, bounds)
        } else {
            cgPath = nil
        }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        effectiveAppearance.performAsCurrentDrawingAppearance {
            ctx.saveGState()
            if let path = cgPath {
                ctx.addPath(path)
            } else {
                let rounded = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
                ctx.addPath(rounded.cgPath)
            }
            ctx.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.88).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
    }
}
