import AppKit
import SwiftUI

@main
struct QuitXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — menubar-only agent
        Settings {
            SettingsView()
        }
    }
}
