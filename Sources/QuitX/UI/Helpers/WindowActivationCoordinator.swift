import AppKit

@MainActor
enum WindowActivationCoordinator {
    static func update() {
        let hasOpenWindow = SettingsWindowController.shared.isOpen
            || WelcomeWindowController.shared.isOpen
            || ExcludeAppPickerWindowController.shared.isOpen
            || HelpWindowController.shared.isOpen
            || AppUpdateWindowController.shared.isOpen
            || ChangelogWindowController.shared.isOpen
            || PortDetailsWindowController.shared.isOpen
            || ProcessTraceWindowController.shared.isOpen
            || ExcludePortPickerWindowController.shared.isOpen
        guard let application = NSApp else { return }
        let policy: NSApplication.ActivationPolicy = hasOpenWindow ? .regular : .accessory
        guard application.activationPolicy() != policy else { return }
        application.setActivationPolicy(policy)
    }
}
