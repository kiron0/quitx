import SwiftUI

enum QuitAllTheme {
    // QuitAll 1.3.6 AccentColor from its compiled asset catalog: #FEBC33.
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)

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
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
