import AppKit
import SwiftUI

@main
struct QuitXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("Help") {
                    HelpWindowController.shared.show()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
