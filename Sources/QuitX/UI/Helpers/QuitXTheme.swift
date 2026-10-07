import SwiftUI
import AppKit

enum QuitXTheme {
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)
    static let accentNSColor = NSColor(srgbRed: 254/255, green: 188/255, blue: 51/255, alpha: 1.0)
    static let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
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
    static let toolbarBackground = cardBackground
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

