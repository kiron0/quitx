import AppKit
import SwiftUI

final class ArrowPopoverWindow: NSPanel {
    init(level: NSWindow.Level = .statusBar) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

let arrowPopoverShape = PopoverContainerShape(centeredArrow: true, cornerRadius: 14)

struct ArrowPopoverChrome: ViewModifier {
    var classicBackground: AnyView = AnyView(
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
    )

    func body(content: Content) -> some View {
        content
            .background {
                if LiquidGlass.enabled {
                    LiquidGlassFill(shape: arrowPopoverShape)
                } else {
                    classicBackground.clipShape(arrowPopoverShape)
                }
            }
            .overlay {
                if !LiquidGlass.enabled {
                    arrowPopoverShape
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
            }
            .clipShape(arrowPopoverShape)
    }
}

extension View {
    func arrowPopoverChrome(
        classicBackground: AnyView = AnyView(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
    ) -> some View {
        modifier(ArrowPopoverChrome(classicBackground: classicBackground))
    }
}
