import Foundation
import ServiceManagement
import Testing
import UserNotifications
@testable import QuitX

@Suite("Permissions")
struct PermissionCenterTests {
    @Test("Every permission explains itself and opens its own System Settings pane")
    func metadata() {
        for kind in PermissionKind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.purpose.isEmpty)
            #expect(!kind.usedBy.isEmpty)
            #expect(kind.settingsURL?.scheme == "x-apple.systempreferences")
        }
        #expect(PermissionKind.accessibility.settingsURL?.absoluteString.hasSuffix("Privacy_Accessibility") == true)
        #expect(PermissionKind.fullDiskAccess.settingsURL?.absoluteString.hasSuffix("Privacy_AllFiles") == true)
        #expect(PermissionKind.finderAutomation.settingsURL?.absoluteString.hasSuffix("Privacy_Automation") == true)
        #expect(PermissionKind.accessibility.tccService == "Accessibility")
        #expect(PermissionKind.finderAutomation.tccService == "AppleEvents")
        #expect(PermissionKind.notifications.tccService == nil)
    }

    @Test("Full Disk Access probes only paths macOS protects without it")
    func fullDiskAccessProbes() throws {
        let probes = FullDiskAccessManager.accessProbePaths(home: "/Users/me")
        #expect(probes.first == "/Users/me/.Trash")
        #expect(probes.allSatisfy { $0.hasPrefix("/Users/me/") })
        #expect(!probes.contains("/Library/Application Support/com.apple.TCC/TCC.db"))

        let readable = FileManager.default.temporaryDirectory.appendingPathComponent("quitx-fda-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: readable, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: readable) }
        #expect(FullDiskAccessManager.canActuallyRead(path: readable.path))
        #expect(!FullDiskAccessManager.canActuallyRead(path: readable.appendingPathComponent("missing").path))
    }

    @Test("System answers map to the right status")
    func statusMapping() {
        #expect(PermissionStatusMapping.accessibility(trusted: true, needsRepair: true) == .granted)
        #expect(PermissionStatusMapping.accessibility(trusted: false, needsRepair: true) == .needsRepair)
        #expect(PermissionStatusMapping.accessibility(trusted: false, needsRepair: false) == .notGranted)
        #expect(PermissionStatusMapping.fullDiskAccess(granted: false) == .notGranted)
        #expect(PermissionStatusMapping.appleEvents(noErr) == .granted)
        #expect(PermissionStatusMapping.appleEvents(-1743) == .denied)
        #expect(PermissionStatusMapping.appleEvents(-1744) == .notGranted)
        #expect(PermissionStatusMapping.appleEvents(-600) == .notGranted)
        #expect(PermissionStatusMapping.notifications(nil) == .unavailable)
        #expect(PermissionStatusMapping.notifications(.authorized) == .granted)
        #expect(PermissionStatusMapping.notifications(.provisional) == .granted)
        #expect(PermissionStatusMapping.notifications(.denied) == .denied)
        #expect(PermissionStatusMapping.notifications(.notDetermined) == .notGranted)
        #expect(PermissionStatusMapping.loginItem(.enabled) == .granted)
        #expect(PermissionStatusMapping.loginItem(.requiresApproval) == .requiresApproval)
        #expect(PermissionStatusMapping.loginItem(.notRegistered) == .notGranted)
    }

    @Test("Each status offers the standard next step")
    func actions() {
        #expect(PermissionAction.primary(for: .accessibility, status: .granted) == .none)
        #expect(PermissionAction.primary(for: .accessibility, status: .notGranted) == .request)
        #expect(PermissionAction.primary(for: .accessibility, status: .needsRepair) == .repair)
        #expect(PermissionAction.primary(for: .fullDiskAccess, status: .notGranted) == .openSettings)
        #expect(PermissionAction.primary(for: .finderAutomation, status: .denied) == .openSettings)
        #expect(PermissionAction.primary(for: .loginItem, status: .requiresApproval) == .openSettings)
        #expect(PermissionAction.primary(for: .notifications, status: .unavailable) == .none)
        #expect(PermissionAction.request.title(for: .loginItem) == "Turn On")
        #expect(PermissionStatus.denied.needsAttention)
        #expect(PermissionStatus.needsRepair.needsAttention)
        #expect(!PermissionStatus.notGranted.needsAttention)
    }

    @Test("Permissions lives in the App section of Settings")
    func settingsTab() {
        #expect(SettingsTab(rawValue: "Permissions") == .permissions)
        #expect(SettingsTab.permissions.category == .app)
        #expect(SettingsTab.permissions.matches("accessibility"))
        #expect(SettingsTab.permissions.matches("full disk"))
    }
}
