import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityPermission: ObservableObject {
    static let shared = AccessibilityPermission()
    static let systemChangeNotification = Notification.Name("com.apple.accessibility.api")
    static let recheckDelays: [Duration] = [.milliseconds(250), .seconds(1), .seconds(3)]

    @Published private(set) var isTrusted: Bool

    private let trustCheck: () -> Bool
    private let defaults: UserDefaults
    private let currentVersion: String
    private var observer: NSObjectProtocol?
    private var rechecks: [Task<Void, Never>] = []

    init(
        trustCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        defaults: UserDefaults = .standard,
        currentVersion: String = QuitXConstants.appVersion
    ) {
        self.trustCheck = trustCheck
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.isTrusted = trustCheck()
    }

    func startObserving() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.systemChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleRechecks()
            }
        }
        refresh()
    }

    func stopObserving() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        rechecks.forEach { $0.cancel() }
        rechecks.removeAll()
    }

    @discardableResult
    func refresh() -> Bool {
        let trusted = trustCheck()
        if isTrusted != trusted {
            isTrusted = trusted
        }
        if trusted {
            let key = QuitXConstants.UserDefaultsKeys.accessibilityTrustedVersion
            if defaults.string(forKey: key) != currentVersion {
                defaults.set(currentVersion, forKey: key)
            }
        }
        return trusted
    }

    var needsRepair: Bool {
        !isTrusted && Self.permissionWasLost(
            trustedVersion: defaults.string(forKey: QuitXConstants.UserDefaultsKeys.accessibilityTrustedVersion),
            currentVersion: currentVersion
        )
    }

    nonisolated static func permissionWasLost(trustedVersion: String?, currentVersion: String) -> Bool {
        guard let trustedVersion, !trustedVersion.isEmpty else { return false }
        return trustedVersion != currentVersion
    }

    func requestAccess() {
        Self.promptForAccess()
        Self.openSystemSettings()
        scheduleRechecks()
    }

    func repair() {
        let bundleId = Bundle.main.bundleIdentifier ?? QuitXConstants.primaryBundleId
        Task { @MainActor [weak self] in
            await Self.resetSystemEntry(bundleId: bundleId)
            self?.requestAccess()
        }
    }

    func scheduleRechecks() {
        rechecks.forEach { $0.cancel() }
        rechecks = Self.recheckDelays.map { delay in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    nonisolated static func promptForAccess() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    nonisolated static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    nonisolated static func resetSystemEntry(bundleId: String) async {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleId]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            process.waitUntilExit()
        }.value
    }
}
