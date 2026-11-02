import AppKit
import CoreServices
import Foundation
import ServiceManagement
import UserNotifications

enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case fullDiskAccess
    case finderAutomation
    case notifications
    case loginItem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .fullDiskAccess: "Full Disk Access"
        case .finderAutomation: "Automation: Finder"
        case .notifications: "Notifications"
        case .loginItem: "Open at Login"
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        case .fullDiskAccess: "externaldrive.fill.badge.checkmark"
        case .finderAutomation: "applescript"
        case .notifications: "bell.badge"
        case .loginItem: "power"
        }
    }

    var purpose: String {
        switch self {
        case .accessibility: "Watches app windows so QuitX knows when an app's last window closes."
        case .fullDiskAccess: "Reads and removes protected files such as Mail attachments, system caches and Trash items."
        case .finderAutomation: "Lists and empties the Trash and closes Finder windows through Finder."
        case .notifications: "Alerts you when an app uses too much CPU and when an update is ready."
        case .loginItem: "Starts QuitX when you log in so automations keep running."
        }
    }

    var usedBy: [String] {
        switch self {
        case .accessibility: ["Quit when last window closes"]
        case .fullDiskAccess: ["Mail Files", "System Junk", "Trash Bins", "Leftovers"]
        case .finderAutomation: ["Trash Bins", "Quick Clean", "Quit Finder windows"]
        case .notifications: ["CPU hog alerts", "Update alerts"]
        case .loginItem: ["Open at Login"]
        }
    }

    var isRequired: Bool {
        switch self {
        case .accessibility, .fullDiskAccess, .finderAutomation: true
        case .notifications, .loginItem: false
        }
    }

    var settingsURL: URL? {
        let bundleId = Bundle.main.bundleIdentifier ?? QuitXConstants.primaryBundleId
        let raw: String
        switch self {
        case .accessibility: raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess: raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .finderAutomation: raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications: raw = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)"
        case .loginItem: raw = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        }
        return URL(string: raw)
    }

    var tccService: String? {
        switch self {
        case .accessibility: "Accessibility"
        case .fullDiskAccess: "SystemPolicyAllFiles"
        case .finderAutomation: "AppleEvents"
        case .notifications, .loginItem: nil
        }
    }
}

enum PermissionStatus: Equatable, Sendable {
    case granted
    case notGranted
    case denied
    case needsRepair
    case requiresApproval
    case unavailable

    var label: String {
        switch self {
        case .granted: "Allowed"
        case .notGranted: "Not Allowed"
        case .denied: "Denied"
        case .needsRepair: "Needs Repair"
        case .requiresApproval: "Needs Approval"
        case .unavailable: "Unavailable"
        }
    }

    var needsAttention: Bool {
        switch self {
        case .denied, .needsRepair, .requiresApproval: true
        case .granted, .notGranted, .unavailable: false
        }
    }
}

enum PermissionAction: Equatable, Sendable {
    case request
    case openSettings
    case repair
    case none

    static func primary(for kind: PermissionKind, status: PermissionStatus) -> PermissionAction {
        switch status {
        case .granted, .unavailable: return .none
        case .needsRepair: return .repair
        case .denied, .requiresApproval: return .openSettings
        case .notGranted: return kind == .fullDiskAccess ? .openSettings : .request
        }
    }

    func title(for kind: PermissionKind) -> String {
        switch self {
        case .request: kind == .loginItem ? "Turn On" : "Allow"
        case .openSettings: "Open System Settings"
        case .repair: "Repair"
        case .none: ""
        }
    }
}

enum PermissionStatusMapping {
    static let errAEEventNotPermitted: OSStatus = -1743
    static let errAEEventWouldRequireUserConsent: OSStatus = -1744
    static let procNotFound: OSStatus = -600

    static func accessibility(trusted: Bool, needsRepair: Bool) -> PermissionStatus {
        if trusted { return .granted }
        return needsRepair ? .needsRepair : .notGranted
    }

    static func fullDiskAccess(granted: Bool) -> PermissionStatus {
        granted ? .granted : .notGranted
    }

    static func appleEvents(_ status: OSStatus) -> PermissionStatus {
        switch status {
        case noErr: return .granted
        case errAEEventNotPermitted: return .denied
        case errAEEventWouldRequireUserConsent, procNotFound: return .notGranted
        default: return .notGranted
        }
    }

    static func notifications(_ status: UNAuthorizationStatus?) -> PermissionStatus {
        guard let status else { return .unavailable }
        switch status {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notGranted
        @unknown default: return .notGranted
        }
    }

    static func loginItem(_ status: SMAppService.Status) -> PermissionStatus {
        switch status {
        case .enabled: return .granted
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .notGranted
        @unknown default: return .notGranted
        }
    }
}

@MainActor
final class PermissionCenter: ObservableObject {
    static let shared = PermissionCenter()
    nonisolated static let finderBundleId = "com.apple.finder"

    @Published private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    @Published private(set) var busy: Set<PermissionKind> = []

    private var activeObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?

    private init() {
        refreshSynchronousStatuses()
    }

    func status(of kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .notGranted
    }

    var grantedCount: Int {
        PermissionKind.allCases.filter { status(of: $0) == .granted }.count
    }

    var attentionCount: Int {
        PermissionKind.allCases.filter { status(of: $0).needsAttention }.count
    }

    func startObserving() {
        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
        }
        refresh()
    }

    func stopObserving() {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
        activeObserver = nil
    }

    func refresh() {
        refreshSynchronousStatuses()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            async let finder = Self.finderAutomationStatus(askIfNeeded: false)
            async let notifications = Self.notificationStatus()
            let (finderStatus, notificationStatus) = await (finder, notifications)
            guard !Task.isCancelled, let self else { return }
            self.set(.finderAutomation, finderStatus)
            self.set(.notifications, notificationStatus)
        }
    }

    func perform(_ action: PermissionAction, for kind: PermissionKind) {
        switch action {
        case .request: request(kind)
        case .openSettings: openSettings(kind)
        case .repair: repair(kind)
        case .none: break
        }
    }

    func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:
            AccessibilityPermission.shared.requestAccess()
            refreshSoon()
        case .fullDiskAccess:
            FullDiskAccessManager.shared.openFullDiskAccessSettings()
            refreshSoon()
        case .finderAutomation:
            runBusy(kind) {
                let status = await Self.finderAutomationStatus(askIfNeeded: true)
                if status == .denied { self.openSettings(kind) }
            }
        case .notifications:
            runBusy(kind) {
                guard Self.canUseNotifications else { return }
                let center = UNUserNotificationCenter.current()
                let current = (await center.notificationSettings()).authorizationStatus
                if current == .notDetermined {
                    _ = try? await center.requestAuthorization(options: [.alert, .sound])
                } else if current == .denied {
                    self.openSettings(kind)
                }
            }
        case .loginItem:
            let service = LaunchAtLoginService.shared
            service.isEnabled = true
            service.refresh()
            if service.requiresApproval { openSettings(kind) }
            refreshSoon()
        }
    }

    func openSettings(_ kind: PermissionKind) {
        switch kind {
        case .fullDiskAccess:
            FullDiskAccessManager.shared.openFullDiskAccessSettings()
        case .loginItem:
            LaunchAtLoginService.shared.openLoginItemsSettings()
        default:
            if let url = kind.settingsURL { NSWorkspace.shared.open(url) }
        }
        refreshSoon()
    }

    func repair(_ kind: PermissionKind) {
        guard let service = kind.tccService else {
            openSettings(kind)
            return
        }
        let bundleId = Bundle.main.bundleIdentifier ?? QuitXConstants.primaryBundleId
        runBusy(kind) {
            await Self.resetTCC(service: service, bundleId: bundleId)
            self.request(kind)
        }
    }

    func revealAppInFinder() {
        FullDiskAccessManager.shared.revealAppInFinder()
    }

    private func refreshSynchronousStatuses() {
        let accessibility = AccessibilityPermission.shared
        accessibility.refresh()
        set(.accessibility, PermissionStatusMapping.accessibility(trusted: accessibility.isTrusted, needsRepair: accessibility.needsRepair))
        set(.fullDiskAccess, PermissionStatusMapping.fullDiskAccess(granted: FullDiskAccessManager.shared.refresh()))
        if Self.isRunningAsApp {
            set(.loginItem, PermissionStatusMapping.loginItem(SMAppService.mainApp.status))
        } else {
            set(.loginItem, .unavailable)
        }
    }

    private func set(_ kind: PermissionKind, _ status: PermissionStatus) {
        if statuses[kind] != status { statuses[kind] = status }
    }

    private func runBusy(_ kind: PermissionKind, _ work: @escaping @MainActor () async -> Void) {
        guard !busy.contains(kind) else { return }
        busy.insert(kind)
        Task { [weak self] in
            await work()
            guard let self else { return }
            self.busy.remove(kind)
            self.refresh()
        }
    }

    private func refreshSoon() {
        Task { [weak self] in
            for delay in AccessibilityPermission.recheckDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    nonisolated static var isRunningAsApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    nonisolated static var canUseNotifications: Bool { isRunningAsApp }

    nonisolated static func notificationStatus() async -> PermissionStatus {
        guard canUseNotifications else { return .unavailable }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionStatusMapping.notifications(settings.authorizationStatus)
    }

    nonisolated static func finderAutomationStatus(askIfNeeded: Bool) async -> PermissionStatus {
        await Task.detached(priority: .userInitiated) {
            PermissionStatusMapping.appleEvents(appleEventPermission(bundleId: finderBundleId, askIfNeeded: askIfNeeded))
        }.value
    }

    nonisolated static func appleEventPermission(bundleId: String, askIfNeeded: Bool) -> OSStatus {
        var target = AEAddressDesc()
        let created = bundleId.withCString { pointer in
            AECreateDesc(DescType(typeApplicationBundleID), pointer, strlen(pointer), &target)
        }
        guard created == noErr else { return PermissionStatusMapping.procNotFound }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), askIfNeeded)
    }

    nonisolated static func resetTCC(service: String, bundleId: String) async {
        _ = await ProcessRunner.run(
            executable: "/usr/bin/tccutil",
            arguments: ["reset", service, bundleId],
            timeout: 10
        )
    }
}
