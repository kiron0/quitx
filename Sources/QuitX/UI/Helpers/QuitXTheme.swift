import SwiftUI
import AppKit

enum QuitXTheme {
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)
    static let accentNSColor = NSColor(srgbRed: 254/255, green: 188/255, blue: 51/255, alpha: 1.0)
    static let windowBackgroundNSColor = NSColor.windowBackgroundColor
    static let cardBackground = Color.primary.opacity(0.035)
    static let cardBackgroundNSColor: NSColor = {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            var baseColor: NSColor = .windowBackgroundColor
            appearance.performAsCurrentDrawingAppearance {
                baseColor = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
            }
            let tintColor: NSColor = isDark ? .white : .black
            return baseColor.blended(withFraction: 0.035, of: tintColor) ?? baseColor
        }
    }()
    static let toolbarBackgroundNSColor = cardBackgroundNSColor

    static var popoverBackground: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            Color(NSColor.windowBackgroundColor)
                .opacity(0.88)
        }
    }

    static var windowBackground: some View {
        Color(NSColor.windowBackgroundColor)
    }

    @MainActor
    @ViewBuilder
    static var paneBackground: some View {
        if LiquidGlass.enabled {
            Color.clear
        } else {
            Color(NSColor.windowBackgroundColor)
        }
    }
}

struct SearchFieldGlassBackground: View {
    var isFocused: Bool = false
    var cornerRadius: CGFloat = 7

    var body: some View {
        ZStack {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: RoundedRectangle(cornerRadius: cornerRadius))
                Color.primary.opacity(0.04)
            } else {
                Color.primary.opacity(0.06)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    isFocused
                        ? QuitXTheme.accent.opacity(0.65)
                        : Color.primary.opacity(LiquidGlass.enabled ? 0.16 : 0.09),
                    lineWidth: 0.8
                )
        )
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
