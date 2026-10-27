import AppKit

@MainActor
final class UninstallWindowController {
    static let shared = UninstallWindowController()

    let model = UninstallViewModel()

    func show(app: AppInfo) {
        guard let target = AppUninstaller.target(name: app.name, pid: app.pid, bundleIdentifier: app.bundleId) else { return }
        show(target: target)
    }

    func show(target: UninstallTarget) {
        StatusItemController.shared?.closePopover()
        if model.phase != .removing, !(model.screen == .review && model.targets == [target]) {
            model.startReview([target], fromPicker: false)
        }
        SettingsWindowController.shared.show(tab: .uninstallApps)
    }

    func showPicker() {
        StatusItemController.shared?.closePopover()
        if model.phase != .removing, model.screen != .picker || model.pickerApps.isEmpty {
            model.showPicker()
        }
        SettingsWindowController.shared.show(tab: .uninstallApps)
    }
}
