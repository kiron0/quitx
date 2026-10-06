import Foundation

@MainActor
final class SettingsResetService {
    static let shared = SettingsResetService()

    private init() {}

    func resetAllSettings() {
        ConfigStore.shared.reset()

        ShortcutManager.shared.resetToDefaults()

        if LaunchAtLoginService.shared.isEnabled {
            LaunchAtLoginService.shared.isEnabled = false
        }

        let viewModel = AppListViewModel.shared
        viewModel.showBackgroundApps = ConfigStore.shared.config.includeBackground
        viewModel.applyDefaultSelection()
    }
}
