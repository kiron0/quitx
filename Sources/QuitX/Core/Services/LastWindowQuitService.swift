import AppKit
import ApplicationServices
import Combine
import Foundation

enum LastWindowQuitPolicy {
    static func isEligible(
        bundleId: String?,
        name: String,
        isRegular: Bool,
        bundleURL: URL?,
        executableURL: URL?,
        config: QuitXConfig
    ) -> Bool {
        guard isRegular else { return false }

        let lowerName = name.lowercased()
        let lowerBundleId = bundleId?.lowercased()

        if SystemAppProtection.isSystemProtected(
            bundleIdentifier: bundleId,
            isBackground: false,
            bundleURL: bundleURL,
            executableURL: executableURL
        ) { return false }

        if bundleId == QuitXConstants.SystemBundleIds.finder
            || bundleId == QuitXConstants.SystemBundleIds.trash
            || lowerName == "finder"
            || lowerName == "trash" { return false }

        let excluded = Set(config.exclude.map { $0.lowercased() })
        if excluded.contains(lowerName) { return false }
        if let lowerBundleId, excluded.contains(lowerBundleId) { return false }

        if config.neverQuitMusic {
            let musicNames = config.musicApps.map { $0.lowercased() }
            if musicNames.contains(where: {
                lowerName.contains($0) || lowerBundleId?.contains($0) == true
            }) { return false }
        }

        if PerAppQuitRule.storedMinutes(
            bundleId: bundleId,
            name: name,
            rules: config.perAppQuitRules
        ) == PerAppQuitRule.neverMinutes { return false }

        return true
    }
}

enum LastWindowQuitWindowState {
    static func nextEmptySamples(windowCount: Int?, previous: Int) -> Int {
        guard let windowCount else { return 0 }
        return windowCount == 0 ? previous + 1 : 0
    }
}

enum LastWindowQuitWindowCounter {
    static func windowIDs(from windowInfo: [[String: Any]]) -> [pid_t: Set<CGWindowID>] {
        var ids: [pid_t: Set<CGWindowID>] = [:]
        for window in windowInfo {
            guard let ownerNumber = window[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let pid = pid_t(ownerNumber.int32Value)
            guard pid > 0 else { continue }
            guard let number = window[kCGWindowNumber as String] as? NSNumber else { continue }
            if let layer = window[kCGWindowLayer as String] as? NSNumber, layer.intValue != 0 { continue }
            if let alpha = window[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue <= 0 { continue }

            if let bounds = window[kCGWindowBounds as String] as? [String: Any],
               let width = (bounds["Width"] as? NSNumber)?.doubleValue,
               let height = (bounds["Height"] as? NSNumber)?.doubleValue,
               width <= 0 || height <= 0 { continue }

            ids[pid, default: []].insert(CGWindowID(number.uint32Value))
        }
        return ids
    }

    static func visibleWindowIDs() -> [pid_t: Set<CGWindowID>]? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        return windowIDs(from: list)
    }

    static func hasMinimizedWindow(for pid: pid_t) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return false }
        for window in windows {
            var minVal: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minVal) == .success,
               let minRef = minVal {
                if let boolVal = minRef as? Bool, boolVal { return true }
                if let num = minRef as? NSNumber, num.boolValue { return true }
                if CFGetTypeID(minRef) == CFBooleanGetTypeID(), CFBooleanGetValue((minRef as! CFBoolean)) {
                    return true
                }
            }
        }
        return false
    }

    static func isElectronApp(bundleURL: URL?) -> Bool {
        guard let bundleURL else { return false }
        let electronFramework = bundleURL
            .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        return FileManager.default.fileExists(atPath: electronFramework.path)
    }

    static func accessibilityWindowCount(for pid: pid_t) -> Int? {
        guard AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        )
        guard result == .success, let windows = value as? [AXUIElement] else { return nil }
        return windows.count
    }

    static func windowCount(for pid: pid_t, visible: [pid_t: Set<CGWindowID>]? = nil) -> Int? {
        guard AXIsProcessTrusted() else { return nil }

        let axCount = accessibilityWindowCount(for: pid)
        if let axCount, axCount == 0 {
            return 0
        }

        let visibleMap = visible ?? visibleWindowIDs() ?? [:]
        let visibleCount = visibleMap[pid]?.count ?? 0
        if visibleCount > 0 {
            return visibleCount
        }

        if hasMinimizedWindow(for: pid) {
            return max(1, axCount ?? 1)
        }

        if let running = NSRunningApplication(processIdentifier: pid), running.isHidden {
            let isElectron = isElectronApp(bundleURL: running.bundleURL)
            let lowerBid = running.bundleIdentifier?.lowercased() ?? ""
            let lowerName = (running.localizedName ?? "").lowercased()
            let knownHidingApp = lowerBid.contains("discord") || lowerBid.contains("slack") || lowerBid.contains("spotify") || lowerName.contains("discord") || lowerName.contains("slack")
            if !isElectron && !knownHidingApp {
                return max(1, axCount ?? 1)
            }
        }

        return 0
    }
}

@MainActor
final class LastWindowQuitService: ObservableObject {
    static let shared = LastWindowQuitService()

    @Published private(set) var accessibilityTrusted: Bool

    nonisolated static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    nonisolated static func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    nonisolated static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private struct TrackedApp {
        let pid: pid_t
        let bundleId: String?
        let name: String
        var emptySamples: Int
    }

    private var tracked: [pid_t: TrackedApp] = [:]
    private var pendingQuits: Set<pid_t> = []
    private var configSubscription: AnyCancellable?
    private var spaceObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private let restrictedPID: pid_t?
    private let recordsRecentlyQuit: Bool
    private let requiresAccessibilityTrust: Bool
    private let accessibilityTrust: () -> Bool
    private let windowCount: (pid_t) -> Int?

    private let pollInterval: Duration = .seconds(1)
    private let requiredEmptySamples = 2

    init(
        restrictedToPID: pid_t? = nil,
        recordsRecentlyQuit: Bool = true,
        requiresAccessibilityTrust: Bool = true,
        accessibilityTrust: @escaping () -> Bool = { LastWindowQuitService.isAccessibilityTrusted },
        windowCount: @escaping (pid_t) -> Int? = { pid in LastWindowQuitWindowCounter.windowCount(for: pid) }
    ) {
        self.restrictedPID = restrictedToPID
        self.recordsRecentlyQuit = recordsRecentlyQuit
        self.requiresAccessibilityTrust = requiresAccessibilityTrust
        self.accessibilityTrust = accessibilityTrust
        self.windowCount = windowCount
        self.accessibilityTrusted = !requiresAccessibilityTrust || accessibilityTrust()
    }

    func start() {
        guard configSubscription == nil else { return }
        configSubscription = ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.syncTrackingState() }
            }
        if spaceObserver == nil {
            spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleSpaceChange()
                }
            }
        }
        syncTrackingState()
    }

    func stop() {
        configSubscription = nil
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
        stopPolling()
        tracked.removeAll()
        pendingQuits.removeAll()
    }

    func isTracking(_ pid: pid_t) -> Bool {
        tracked[pid] != nil
    }

    private func handleSpaceChange() {
        for pid in tracked.keys {
            tracked[pid]?.emptySamples = 0
        }
    }

    func refreshAccessibilityTrust() {
        let trusted = !requiresAccessibilityTrust || accessibilityTrust()
        if accessibilityTrusted != trusted {
            accessibilityTrusted = trusted
        }
        if !trusted, ConfigStore.shared.config.quitWhenLastWindowClosed {
            ConfigStore.shared.config.quitWhenLastWindowClosed = false
            ConfigStore.shared.save()
        }
        syncTrackingState()
    }

    private func syncTrackingState() {
        let trusted = !requiresAccessibilityTrust || accessibilityTrust()
        if accessibilityTrusted != trusted {
            accessibilityTrusted = trusted
        }

        if !trusted, ConfigStore.shared.config.quitWhenLastWindowClosed {
            ConfigStore.shared.config.quitWhenLastWindowClosed = false
            ConfigStore.shared.save()
        }

        if ConfigStore.shared.config.quitWhenLastWindowClosed, trusted {
            startPolling()
        } else {
            stopPolling()
            tracked.removeAll()
            pendingQuits.removeAll()
        }
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.poll()
                do {
                    try await Task.sleep(for: self.pollInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func poll() {
        guard ConfigStore.shared.config.quitWhenLastWindowClosed else { return }
        let trusted = !requiresAccessibilityTrust || accessibilityTrust()
        if accessibilityTrusted != trusted {
            accessibilityTrusted = trusted
        }
        guard trusted else {
            ConfigStore.shared.config.quitWhenLastWindowClosed = false
            ConfigStore.shared.save()
            return
        }
        let config = ConfigStore.shared.config
        let ownPid = ProcessInfo.processInfo.processIdentifier

        guard let visible = LastWindowQuitWindowCounter.visibleWindowIDs() else { return }

        var livePids: Set<pid_t> = []
        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            guard pid > 0, pid != ownPid, !app.isTerminated else { continue }
            guard restrictedPID == nil || pid == restrictedPID else { continue }
            livePids.insert(pid)

            guard app.activationPolicy == .regular else { continue }
            guard tracked[pid] == nil, !pendingQuits.contains(pid) else { continue }
            let windowIDs = visible[pid] ?? []
            guard !windowIDs.isEmpty else { continue }
            guard let count = windowCount(pid), count > 0 else { continue }

            let name = Self.resolvedName(for: app)
            guard !name.isEmpty else { continue }
            guard LastWindowQuitPolicy.isEligible(
                bundleId: app.bundleIdentifier,
                name: name,
                isRegular: true,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL,
                config: config
            ) else { continue }

            tracked[pid] = TrackedApp(
                pid: pid,
                bundleId: app.bundleIdentifier,
                name: name,
                emptySamples: 0
            )
        }

        for pid in Array(tracked.keys) where !livePids.contains(pid) {
            tracked.removeValue(forKey: pid)
        }

        for pid in Array(tracked.keys) {
            guard var entry = tracked[pid] else { continue }
            entry.emptySamples = LastWindowQuitWindowState.nextEmptySamples(
                windowCount: windowCount(pid),
                previous: entry.emptySamples
            )
            tracked[pid] = entry
            guard entry.emptySamples >= requiredEmptySamples else { continue }

            tracked.removeValue(forKey: pid)
            guard pendingQuits.insert(pid).inserted else { continue }
            performQuit(entry: entry)
        }
    }

    private func performQuit(entry: TrackedApp) {
        let pid = entry.pid
        guard QuitService.processIsRunning(pid) else {
            pendingQuits.remove(pid)
            return
        }
        guard stillWindowless(entry: entry) else {
            pendingQuits.remove(pid)
            return
        }
        guard let running = NSRunningApplication(processIdentifier: pid), !running.isTerminated else {
            pendingQuits.remove(pid)
            return
        }

        let runningName = Self.resolvedName(for: running)
        guard QuitService.identityMatches(
            expectedBundleId: entry.bundleId,
            expectedName: entry.name,
            runningBundleId: running.bundleIdentifier,
            runningName: runningName
        ) else {
            pendingQuits.remove(pid)
            return
        }

        guard LastWindowQuitPolicy.isEligible(
            bundleId: entry.bundleId,
            name: entry.name,
            isRegular: running.activationPolicy == .regular,
            bundleURL: running.bundleURL,
            executableURL: running.executableURL,
            config: ConfigStore.shared.config
        ) else {
            pendingQuits.remove(pid)
            return
        }

        let app = AppInfo(name: entry.name, bundleId: entry.bundleId, pid: pid)
        Task { @MainActor [weak self] in
            let results = await QuitService.shared.quit(apps: [app], force: false)
            if self?.recordsRecentlyQuit == true, results.first?.success == true {
                RecentlyQuitService.shared.record(app: app)
            }
            self?.pendingQuits.remove(pid)
        }
    }

    private func stillWindowless(entry: TrackedApp) -> Bool {
        windowCount(entry.pid) == 0
    }

    private static func resolvedName(for app: NSRunningApplication) -> String {
        let raw = app.localizedName
            ?? app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? app.executableURL?.lastPathComponent
        guard let raw, !raw.isEmpty else { return "" }
        return SystemAppProtection.cleanAppName(raw)
    }
}
