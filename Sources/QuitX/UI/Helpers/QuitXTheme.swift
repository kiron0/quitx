import SwiftUI
import AppKit

enum QuitXTheme {
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)
    static let accentNSColor = NSColor(red: 254/255, green: 188/255, blue: 51/255, alpha: 1.0)
    static let windowBackgroundColor = Color(red: 0.14, green: 0.14, blue: 0.14)
    static let windowBackgroundNSColor = NSColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.0)

    static var popoverBackground: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static var windowBackground: some View {
        Color(red: 0.14, green: 0.14, blue: 0.14)
    }
}
