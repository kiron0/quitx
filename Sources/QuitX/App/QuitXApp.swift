import AppKit
import SwiftUI

@main
struct QuitXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(ConfigStore.shared)
        }
    }
}
