import AppKit

@MainActor
enum WindowActivationCoordinator {
    static func update() {
        let hasOpenWindow = SettingsWindowController.shared.isOpen
            || WelcomeWindowController.shared.isOpen
            || ExcludeAppPickerWindowController.shared.isOpen
            || HelpWindowController.shared.isOpen
        NSApp.setActivationPolicy(hasOpenWindow ? .regular : .accessory)
    }
}
