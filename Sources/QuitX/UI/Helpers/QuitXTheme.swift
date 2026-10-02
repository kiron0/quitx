import SwiftUI
import AppKit

enum QuitXTheme {
    static let accent = Color(red: 254/255, green: 188/255, blue: 51/255)
    static let accentNSColor = NSColor(red: 254/255, green: 188/255, blue: 51/255, alpha: 1.0)
    static let windowBackgroundColor = Color(NSColor.windowBackgroundColor)
    static let windowBackgroundNSColor = NSColor.windowBackgroundColor
    static let toolbarBackground = Color(NSColor.windowBackgroundColor)
    static let toolbarBackgroundNSColor = NSColor.windowBackgroundColor

    static var popoverBackground: some View {
        VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
    }

    static var windowBackground: some View {
        Color(NSColor.windowBackgroundColor)
    }
}
