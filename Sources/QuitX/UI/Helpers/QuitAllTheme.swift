import SwiftUI
import AppKit

enum QuitAllTheme {
    // QuitAll 1.3.6 AccentColor from its compiled asset catalog: #FEBC33.
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)
    static let windowBackgroundColor = Color(red: 0.145, green: 0.137, blue: 0.129)
    static let windowBackgroundNSColor = NSColor(
        calibratedRed: 0.145,
        green: 0.137,
        blue: 0.129,
        alpha: 1
    )

    static var popoverBackground: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            LinearGradient(
                colors: [Color.white.opacity(0.055), Color.black.opacity(0.09)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static var windowBackground: some View {
        windowBackgroundColor
    }
}
