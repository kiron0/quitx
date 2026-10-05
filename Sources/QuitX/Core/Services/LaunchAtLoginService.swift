import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    static let shared = LaunchAtLoginService()
    private var isRevertingChange = false

    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled, !isRevertingChange else { return }
            guard applyRegistration(isEnabled) else {
                isRevertingChange = true
                isEnabled = oldValue
                isRevertingChange = false
                return
            }
            UserDefaults.standard.set(isEnabled, forKey: QuitXConstants.UserDefaultsKeys.launchAtLogin)
        }
    }

    private init() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = status == .enabled || status == .requiresApproval
            UserDefaults.standard.set(self.isEnabled, forKey: QuitXConstants.UserDefaultsKeys.launchAtLogin)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: QuitXConstants.UserDefaultsKeys.launchAtLogin)
        }
    }

    private func applyRegistration(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return true
            } catch {
                NSLog("SMAppService.mainApp registration failed: \(error)")
                return false
            }
        }
        return true
    }
}
