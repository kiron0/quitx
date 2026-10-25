import AppKit
import ApplicationServices
import Combine
import Foundation
import os

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

        if let lowerBundleId, QuitXConstants.lastWindowProtectedBundleIds.contains(lowerBundleId) {
            return false
        }

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

    static func remainingWindows(
        axCount: Int?,
        allSpacesIDs: Set<CGWindowID>?,
        seenIDs: Set<CGWindowID>,
        closedIDs: Set<CGWindowID>,
        closedByUser: Bool,
        knownWindows: Int
    ) -> Int? {
        guard let axCount else { return nil }
        guard axCount == 0 else { return axCount }
        guard let allSpacesIDs else { return nil }
        if allSpacesIDs.isEmpty { return 0 }
        if !closedIDs.isEmpty {
            return allSpacesIDs.intersection(seenIDs).subtracting(closedIDs).count
        }
        if closedByUser && knownWindows == 0 { return 0 }
        return allSpacesIDs.count
    }

    static func isCloseButtonRegion(point: CGPoint, windowBounds: CGRect) -> Bool {
        guard windowBounds.contains(point) else { return false }
        return point.x - windowBounds.minX <= 96 && point.y - windowBounds.minY <= 44
    }
}

@MainActor
final class AXWindowCloseObserver {
    let pid: pid_t
    private let observer: AXObserver
    private let application: AXUIElement
    private(set) var windows: [AXUIElement] = []
    var onClosed: ((pid_t) -> Void)?

    init?(pid: pid_t) {
        var created: AXObserver?
        guard AXObserverCreate(pid, axWindowCloseCallback, &created) == .success, let created else { return nil }
        self.pid = pid
        self.observer = created
        self.application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        AXObserverAddNotification(created, application, kAXWindowCreatedNotification as CFString, refcon)
    }

    private var refcon: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    func invalidate() {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        windows.removeAll()
        onClosed = nil
    }

    func refresh() {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let current = value as? [AXUIElement] else { return }
        for window in current { watch(window) }
    }

    func watch(_ window: AXUIElement) {
        guard !windows.contains(where: { CFEqual($0, window) }) else { return }
        guard AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, refcon) == .success else { return }
        windows.append(window)
    }

    fileprivate func handle(element: AXUIElement, notification: String) {
        if notification == kAXWindowCreatedNotification as String {
            watch(element)
            return
        }
        guard notification == kAXUIElementDestroyedNotification as String else { return }
        guard let index = windows.firstIndex(where: { CFEqual($0, element) }) else { return }
        AXObserverRemoveNotification(observer, windows[index], kAXUIElementDestroyedNotification as CFString)
        windows.remove(at: index)
        onClosed?(pid)
    }
}

private func axWindowCloseCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let box = Unmanaged<AXWindowCloseObserver>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated {
        box.handle(element: element, notification: name)
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

    private static let visibleSnapshotMaxAge: TimeInterval = 0.5
    private static let visibleSnapshot = OSAllocatedUnfairLock<(ids: [pid_t: Set<CGWindowID>], at: TimeInterval)?>(
        initialState: nil
    )

    static func visibleWindowIDs() -> [pid_t: Set<CGWindowID>]? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        let ids = windowIDs(from: list)
        let now = ProcessInfo.processInfo.systemUptime
        visibleSnapshot.withLock { $0 = (ids, now) }
        return ids
    }

    private static let allSpacesSnapshot = OSAllocatedUnfairLock<(ids: [pid_t: Set<CGWindowID>], at: TimeInterval)?>(
        initialState: nil
    )

    static func allSpacesWindowIDs(for pid: pid_t) -> Set<CGWindowID>? {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = allSpacesSnapshot.withLock({ state -> [pid_t: Set<CGWindowID>]? in
            guard let state, now - state.at <= visibleSnapshotMaxAge else { return nil }
            return state.ids
        }) {
            return cached[pid] ?? []
        }
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let ids = windowIDs(from: list)
        allSpacesSnapshot.withLock { $0 = (ids, now) }
        return ids[pid] ?? []
    }

    static func allSpacesWindowCount(for pid: pid_t) -> Int? {
        allSpacesWindowIDs(for: pid)?.count
    }

    struct OnScreenWindow: Equatable {
        let id: CGWindowID
        let pid: pid_t
        let bounds: CGRect
    }

    static func onScreenWindowsFrontToBack() -> [OnScreenWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info -> OnScreenWindow? in
            guard let owner = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let number = info[kCGWindowNumber as String] as? NSNumber,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0 == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 0, bounds.height > 0 else { return nil }
            return OnScreenWindow(id: CGWindowID(number.uint32Value), pid: pid_t(owner.int32Value), bounds: bounds)
        }
    }

    static func isCloseButton(at point: CGPoint) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.25)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element else { return false }
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success else { return false }
        return (subrole as? String) == (kAXCloseButtonSubrole as String)
    }

    private static func recentVisibleWindowIDs() -> [pid_t: Set<CGWindowID>]? {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = visibleSnapshot.withLock({ state -> [pid_t: Set<CGWindowID>]? in
            guard let state, now - state.at <= visibleSnapshotMaxAge else { return nil }
            return state.ids
        }) {
            return cached
        }
        return visibleWindowIDs()
    }

    private static let axMessagingTimeout: Float = 0.5

    private static func axApplication(for pid: pid_t) -> AXUIElement {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, axMessagingTimeout)
        return application
    }

    private static func axWindows(for pid: pid_t) -> [AXUIElement]? {
        let application = axApplication(for: pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        return windows
    }

    static func hasMinimizedWindow(for pid: pid_t) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        guard let windows = axWindows(for: pid) else { return false }
        return containsMinimizedWindow(windows)
    }

    private static func containsMinimizedWindow(_ windows: [AXUIElement]) -> Bool {
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

    static func enclosingAppURL(for url: URL?) -> URL? {
        guard let url = url?.standardizedFileURL else { return nil }
        var current = url.deletingLastPathComponent()
        while current.path != "/" && current.pathComponents.count > 1 {
            if current.pathExtension == "app" {
                return current.standardizedFileURL
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    private static let webRuntimeCache = OSAllocatedUnfairLock(initialState: [String: Bool]())

    static func isWebRuntimeApp(bundleURL: URL?) -> Bool {
        guard let bundleURL else { return false }
        let cacheKey = bundleURL.standardizedFileURL.path
        if let cached = webRuntimeCache.withLock({ $0[cacheKey] }) {
            return cached
        }
        let result = detectWebRuntime(bundleURL: bundleURL)
        webRuntimeCache.withLock { cache in
            if cache.count >= 256 { cache.removeAll() }
            cache[cacheKey] = result
        }
        return result
    }

    private static func detectWebRuntime(bundleURL: URL) -> Bool {
        let checkURLs = [bundleURL, enclosingAppURL(for: bundleURL)].compactMap { $0 }
        let runtimeFrameworks = [
            "Contents/Frameworks/Electron Framework.framework",
            "Contents/Frameworks/Chromium Embedded Framework.framework"
        ]
        for url in checkURLs {
            for framework in runtimeFrameworks {
                if FileManager.default.fileExists(atPath: url.appendingPathComponent(framework).path) {
                    return true
                }
            }
        }
        return false
    }

    static func accessibilityWindowCount(for pid: pid_t) -> Int? {
        guard AXIsProcessTrusted() else { return nil }
        return axWindows(for: pid)?.count
    }

    static func windowCount(for pid: pid_t, visible: [pid_t: Set<CGWindowID>]? = nil) -> Int? {
        guard AXIsProcessTrusted() else { return nil }

        let windows = axWindows(for: pid)
        let axCount = windows?.count
        if let axCount, axCount == 0 {
            return 0
        }

        let visibleMap = visible ?? recentVisibleWindowIDs() ?? [:]
        let visibleCount = visibleMap[pid]?.count ?? 0
        if visibleCount > 0 {
            return visibleCount
        }

        if let windows, containsMinimizedWindow(windows) {
            return max(1, axCount ?? 1)
        }

        if let running = NSRunningApplication(processIdentifier: pid), running.isHidden {
            if !isWebRuntimeApp(bundleURL: running.bundleURL) {
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

    private struct TrackedApp {
        let key: String
        let bundleId: String?
        let name: String
        let bundleURL: URL?
        let executableURL: URL?
        var owners: Set<pid_t>
        var emptySamples: Int
        var closedByUser = false
        var seenWindowIDs: Set<CGWindowID> = []
        var closedWindowIDs: [CGWindowID: TimeInterval] = [:]
    }

    private var tracked: [String: TrackedApp] = [:]
    private var pendingQuits: Set<String> = []
    private(set) var quitRequests: [[pid_t]] = []
    private var configSubscription: AnyCancellable?
    private var spaceObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private let restrictedPID: pid_t?
    private let recordsRecentlyQuit: Bool
    private let requiresAccessibilityTrust: Bool
    private let accessibilityTrust: @MainActor () -> Bool
    private let windowCount: (pid_t) -> Int?
    private var permissionSubscription: AnyCancellable?
    private let allSpacesWindowIDs: (pid_t) -> Set<CGWindowID>?
    private var closeIntentMonitors: [Any] = []
    private let reopenGrace: TimeInterval = 1.5
    private var closeObservers: [pid_t: AXWindowCloseObserver] = [:]

    private let pollInterval: Duration = .seconds(1)
    private var cachedIndex: (index: RunningAppIndex, keys: [pid_t: String], builtAt: Date)?
    private var workspaceTokens: [NSObjectProtocol] = []
    private static let indexLifetime: TimeInterval = 60
    private let requiredEmptySamples = 2

    init(
        restrictedToPID: pid_t? = nil,
        recordsRecentlyQuit: Bool = true,
        requiresAccessibilityTrust: Bool = true,
        accessibilityTrust: @escaping @MainActor () -> Bool = { AccessibilityPermission.shared.refresh() },
        windowCount: @escaping (pid_t) -> Int? = { pid in LastWindowQuitWindowCounter.windowCount(for: pid) },
        allSpacesWindowIDs: @escaping (pid_t) -> Set<CGWindowID>? = { pid in LastWindowQuitWindowCounter.allSpacesWindowIDs(for: pid) }
    ) {
        self.restrictedPID = restrictedToPID
        self.recordsRecentlyQuit = recordsRecentlyQuit
        self.requiresAccessibilityTrust = requiresAccessibilityTrust
        self.accessibilityTrust = accessibilityTrust
        self.windowCount = windowCount
        self.allSpacesWindowIDs = allSpacesWindowIDs
        self.accessibilityTrusted = !requiresAccessibilityTrust || accessibilityTrust()
    }

    func start() {
        if requiresAccessibilityTrust, permissionSubscription == nil {
            permissionSubscription = AccessibilityPermission.shared.$isTrusted
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in self?.syncTrackingState() }
                }
        }
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
        permissionSubscription = nil
        configSubscription = nil
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
        stopPolling()
        tracked.removeAll()
        removeCloseObservers()
        pendingQuits.removeAll()
    }

    func isTracking(_ pid: pid_t) -> Bool {
        tracked.values.contains { $0.owners.contains(pid) }
    }

    private func handleSpaceChange() {
        for key in tracked.keys {
            tracked[key]?.emptySamples = 0
        }
    }

    func refreshAccessibilityTrust() {
        syncTrackingState()
    }

    private func updateTrust() -> Bool {
        let trusted = !requiresAccessibilityTrust || accessibilityTrust()
        if accessibilityTrusted != trusted {
            accessibilityTrusted = trusted
        }
        return trusted
    }

    private func syncTrackingState() {
        let trusted = updateTrust()

        if ConfigStore.shared.config.quitWhenLastWindowClosed, trusted {
            startPolling()
        } else {
            stopPolling()
            tracked.removeAll()
            pendingQuits.removeAll()
            removeCloseObservers()
        }
    }

    private func runningIndex() -> (index: RunningAppIndex, keys: [pid_t: String]) {
        if let cachedIndex, Date().timeIntervalSince(cachedIndex.builtAt) < Self.indexLifetime {
            return (cachedIndex.index, cachedIndex.keys)
        }
        let index = RunningAppIndex(NSWorkspace.shared.runningApplications)
        var keys: [pid_t: String] = [:]
        for app in index.apps {
            keys[app.processIdentifier] = Self.appKey(for: app, index: index)
        }
        cachedIndex = (index, keys, Date())
        return (index, keys)
    }

    private func observeWorkspaceChanges() {
        guard workspaceTokens.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cachedIndex = nil }
            })
        }
    }

    private func stopObservingWorkspaceChanges() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach { center.removeObserver($0) }
        workspaceTokens.removeAll()
        cachedIndex = nil
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        observeWorkspaceChanges()
        installCloseIntentMonitors()
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

    private func removeCloseObservers(except keep: Set<pid_t> = []) {
        for (pid, observer) in closeObservers where !keep.contains(pid) {
            observer.invalidate()
            closeObservers.removeValue(forKey: pid)
        }
    }

    private func syncCloseObservers() {
        let owners = tracked.values.reduce(into: Set<pid_t>()) { $0.formUnion($1.owners) }
        removeCloseObservers(except: owners)
        guard requiresAccessibilityTrust, AXIsProcessTrusted() else { return }
        for pid in owners where QuitService.processIsRunning(pid) {
            if let observer = closeObservers[pid] {
                observer.refresh()
                continue
            }
            guard let observer = AXWindowCloseObserver(pid: pid) else { continue }
            observer.onClosed = { [weak self] closedPid in
                self?.noteWindowClosed(pid: closedPid)
            }
            observer.refresh()
            closeObservers[pid] = observer
        }
    }

    func noteWindowClosed(pid: pid_t) {
        for key in tracked.keys where tracked[key]?.owners.contains(pid) == true {
            tracked[key]?.closedByUser = true
        }
    }

    private func knownWindows(_ owners: Set<pid_t>) -> Int {
        owners.reduce(0) { $0 + (closeObservers[$1]?.windows.count ?? 0) }
    }

    private func allSpacesIDs(_ owners: Set<pid_t>) -> Set<CGWindowID>? {
        var ids = Set<CGWindowID>()
        for pid in owners where QuitService.processIsRunning(pid) {
            guard let windows = allSpacesWindowIDs(pid) else { return nil }
            ids.formUnion(windows)
        }
        return ids
    }

    private func remainingWindows(_ entry: TrackedApp, owners: Set<pid_t>? = nil) -> Int? {
        let scope = owners ?? entry.owners
        return LastWindowQuitWindowState.remainingWindows(
            axCount: totalWindows(scope),
            allSpacesIDs: allSpacesIDs(scope),
            seenIDs: entry.seenWindowIDs,
            closedIDs: Set(entry.closedWindowIDs.keys),
            closedByUser: entry.closedByUser,
            knownWindows: knownWindows(scope)
        )
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        removeCloseIntentMonitors()
        stopObservingWorkspaceChanges()
    }

    private func installCloseIntentMonitors() {
        guard closeIntentMonitors.isEmpty, requiresAccessibilityTrust else { return }
        if let mouse = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            let location = NSEvent.mouseLocation
            MainActor.assumeIsolated { self?.handleMouseDown(cocoaLocation: location) }
        }) {
            closeIntentMonitors.append(mouse)
        }
        if let keys = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers?.lowercased()
            MainActor.assumeIsolated { self?.handleKeyDown(flags: flags, key: key) }
        }) {
            closeIntentMonitors.append(keys)
        }
    }

    private func removeCloseIntentMonitors() {
        closeIntentMonitors.forEach { NSEvent.removeMonitor($0) }
        closeIntentMonitors.removeAll()
    }

    private var trackedOwners: Set<pid_t> {
        tracked.values.reduce(into: Set<pid_t>()) { $0.formUnion($1.owners) }
    }

    private func handleMouseDown(cocoaLocation: CGPoint) {
        guard !tracked.isEmpty, let primary = NSScreen.screens.first else { return }
        let point = CGPoint(x: cocoaLocation.x, y: primary.frame.maxY - cocoaLocation.y)
        let owners = trackedOwners
        guard let window = LastWindowQuitWindowCounter.onScreenWindowsFrontToBack().first(where: { $0.bounds.contains(point) }),
              owners.contains(window.pid),
              LastWindowQuitWindowState.isCloseButtonRegion(point: point, windowBounds: window.bounds),
              LastWindowQuitWindowCounter.isCloseButton(at: point) else { return }
        noteCloseIntent(pid: window.pid, windowIDs: [window.id])
    }

    private func handleKeyDown(flags: NSEvent.ModifierFlags, key: String?) {
        guard key == "w", flags.contains(.command), !flags.contains(.control), !tracked.isEmpty,
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              trackedOwners.contains(pid) else { return }
        let windows = LastWindowQuitWindowCounter.onScreenWindowsFrontToBack().filter { $0.pid == pid }
        let closing = flags.contains(.option) ? windows.map(\.id) : Array(windows.prefix(1).map(\.id))
        noteCloseIntent(pid: pid, windowIDs: Set(closing))
    }

    func noteCloseIntent(pid: pid_t, windowIDs: Set<CGWindowID>) {
        let now = ProcessInfo.processInfo.systemUptime
        for key in tracked.keys where tracked[key]?.owners.contains(pid) == true {
            tracked[key]?.closedByUser = true
            for id in windowIDs {
                tracked[key]?.closedWindowIDs[id] = now
            }
        }
    }

    private func poll() {
        guard ConfigStore.shared.config.quitWhenLastWindowClosed else { return }
        guard updateTrust() else {
            syncTrackingState()
            return
        }
        let config = ConfigStore.shared.config
        guard let visible = LastWindowQuitWindowCounter.visibleWindowIDs() else { return }

        let groups = currentGroups()

        for key in Array(tracked.keys) where groups[key] == nil {
            tracked.removeValue(forKey: key)
        }

        for (key, members) in groups {
            let withWindows = Set(members.filter { !(visible[$0.processIdentifier] ?? []).isEmpty }.map(\.processIdentifier))
            let regular = Set(members.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
            let live = Set(members.map(\.processIdentifier))

            if var entry = tracked[key] {
                entry.owners = entry.owners.union(withWindows).union(regular).intersection(live)
                let onScreen = entry.owners.reduce(into: Set<CGWindowID>()) { $0.formUnion(visible[$1] ?? []) }
                entry.seenWindowIDs.formUnion(onScreen)
                let now = ProcessInfo.processInfo.systemUptime
                entry.closedWindowIDs = entry.closedWindowIDs.filter { id, closedAt in
                    !(onScreen.contains(id) && now - closedAt > reopenGrace)
                }
                tracked[key] = entry
                continue
            }
            guard !pendingQuits.contains(key), !withWindows.isEmpty else { continue }
            let identity = Self.identityApplication(key: key, members: members)
            let name = Self.resolvedName(for: identity)
            guard !name.isEmpty else { continue }
            guard LastWindowQuitPolicy.isEligible(
                bundleId: identity.bundleIdentifier,
                name: name,
                isRegular: !regular.isEmpty,
                bundleURL: identity.bundleURL,
                executableURL: identity.executableURL,
                config: config
            ) else { continue }
            let owners = withWindows.union(regular)
            guard let total = totalWindows(owners), total > 0 else { continue }

            tracked[key] = TrackedApp(
                key: key,
                bundleId: identity.bundleIdentifier,
                name: name,
                bundleURL: identity.bundleURL,
                executableURL: identity.executableURL,
                owners: owners,
                emptySamples: 0,
                seenWindowIDs: owners.reduce(into: Set<CGWindowID>()) { $0.formUnion(visible[$1] ?? []) }
            )
        }

        syncCloseObservers()

        for key in Array(tracked.keys) {
            guard var entry = tracked[key] else { continue }
            let remaining = remainingWindows(entry)
            if let remaining, remaining > 0 { entry.closedByUser = false }
            entry.emptySamples = LastWindowQuitWindowState.nextEmptySamples(
                windowCount: remaining,
                previous: entry.emptySamples
            )
            tracked[key] = entry
            guard entry.emptySamples >= requiredEmptySamples else { continue }

            tracked.removeValue(forKey: key)
            guard pendingQuits.insert(key).inserted else { continue }
            performQuit(entry: entry)
        }
    }

    private func currentGroups() -> [String: [NSRunningApplication]] {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        var groups: [String: [NSRunningApplication]] = [:]
        let (index, keys) = runningIndex()
        for app in index.apps {
            let pid = app.processIdentifier
            guard pid > 0, pid != ownPid, QuitService.processIsRunning(pid) else { continue }
            groups[keys[pid] ?? Self.appKey(for: app, index: index), default: []].append(app)
        }
        if let restrictedPID {
            groups = groups.filter { $0.value.contains { $0.processIdentifier == restrictedPID } }
        }
        return groups
    }

    private func totalWindows(_ owners: Set<pid_t>) -> Int? {
        var total = 0
        for pid in owners where QuitService.processIsRunning(pid) {
            guard let count = windowCount(pid) else { return nil }
            total += count
        }
        return total
    }

    private func performQuit(entry: TrackedApp) {
        let key = entry.key
        let members = currentGroups()[key] ?? []
        guard !members.isEmpty else {
            pendingQuits.remove(key)
            return
        }
        let owners = entry.owners.union(members.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
        guard remainingWindows(entry, owners: owners) == 0 else {
            pendingQuits.remove(key)
            return
        }
        let identity = Self.identityApplication(key: key, members: members)
        guard QuitService.identityMatches(
            expectedBundleId: entry.bundleId,
            expectedName: entry.name,
            runningBundleId: identity.bundleIdentifier,
            runningName: Self.resolvedName(for: identity)
        ), LastWindowQuitPolicy.isEligible(
            bundleId: entry.bundleId,
            name: entry.name,
            isRegular: true,
            bundleURL: entry.bundleURL,
            executableURL: entry.executableURL,
            config: ConfigStore.shared.config
        ) else {
            pendingQuits.remove(key)
            return
        }

        let isOptionPressed = NSEvent.modifierFlags.contains(.option)
        let forceConfig = ConfigStore.shared.config.force == .force
        let force = isOptionPressed ? !forceConfig : forceConfig
        let targets = Self.quitTargets(identity: identity, members: members)
        quitRequests.append(targets.compactMap(\.pid))
        Task { @MainActor [weak self] in
            let results = await QuitService.shared.quit(apps: targets, force: force)
            if self?.recordsRecentlyQuit == true, let primary = targets.first, results.first?.success == true {
                RecentlyQuitService.shared.record(app: primary)
            }
            self?.pendingQuits.remove(key)
        }
    }

    struct RunningAppIndex {
        let apps: [NSRunningApplication]
        let bundlePaths: [pid_t: String]
        let enclosingPaths: [pid_t: String]
        let byBundlePath: [String: [NSRunningApplication]]

        init(_ running: [NSRunningApplication]) {
            var apps: [NSRunningApplication] = []
            var bundlePaths: [pid_t: String] = [:]
            var enclosingPaths: [pid_t: String] = [:]
            var byBundlePath: [String: [NSRunningApplication]] = [:]
            for app in running where app.processIdentifier > 0 && QuitService.processIsRunning(app.processIdentifier) {
                apps.append(app)
                let pid = app.processIdentifier
                guard let url = app.bundleURL?.standardizedFileURL else { continue }
                bundlePaths[pid] = url.path
                byBundlePath[url.path, default: []].append(app)
                if let enclosing = LastWindowQuitWindowCounter.enclosingAppURL(for: url) {
                    enclosingPaths[pid] = enclosing.path
                }
            }
            self.apps = apps
            self.bundlePaths = bundlePaths
            self.enclosingPaths = enclosingPaths
            self.byBundlePath = byBundlePath
        }
    }

    static func appKey(for app: NSRunningApplication) -> String {
        appKey(for: app, index: RunningAppIndex(NSWorkspace.shared.runningApplications))
    }

    static func appKey(for app: NSRunningApplication, index: RunningAppIndex) -> String {
        let root = rootRunningApplication(for: app, index: index)
        if let path = index.bundlePaths[root.processIdentifier] ?? index.bundlePaths[app.processIdentifier] {
            return path
        }
        if let url = (root.bundleURL ?? app.bundleURL)?.standardizedFileURL {
            return url.path
        }
        return "pid:\(app.processIdentifier)"
    }

    private static func identityApplication(key: String, members: [NSRunningApplication]) -> NSRunningApplication {
        members.first { $0.bundleURL?.standardizedFileURL.path == key && $0.activationPolicy == .regular }
            ?? members.first { $0.bundleURL?.standardizedFileURL.path == key }
            ?? members.first { $0.activationPolicy == .regular }
            ?? members[0]
    }

    static func quitTargets(identity: NSRunningApplication, members: [NSRunningApplication]) -> [AppInfo] {
        var seen = Set<pid_t>()
        let ordered = [identity] + members.filter { $0.processIdentifier != identity.processIdentifier }
        return ordered.compactMap { running -> AppInfo? in
            let pid = running.processIdentifier
            guard pid > 0, seen.insert(pid).inserted else { return nil }
            return AppInfo(name: resolvedName(for: running), bundleId: running.bundleIdentifier, pid: pid)
        }
    }

    static func rootRunningApplication(for app: NSRunningApplication) -> NSRunningApplication {
        rootRunningApplication(for: app, index: RunningAppIndex(NSWorkspace.shared.runningApplications))
    }

    static func rootRunningApplication(for app: NSRunningApplication, index: RunningAppIndex) -> NSRunningApplication {
        let enclosingPath = index.enclosingPaths[app.processIdentifier]
            ?? LastWindowQuitWindowCounter.enclosingAppURL(for: app.bundleURL)?.path
        guard let enclosingPath else { return app }
        let parents = index.byBundlePath[enclosingPath] ?? []
        let ancestor = parents.first {
            ProcessTree.isDescendant(app.processIdentifier, ofAny: [$0.processIdentifier])
        }
        return ancestor ?? parents.first ?? app
    }

    private static func resolvedName(for app: NSRunningApplication) -> String {
        let raw = app.localizedName
            ?? app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? app.executableURL?.lastPathComponent
        guard let raw, !raw.isEmpty else { return "" }
        return SystemAppProtection.cleanAppName(raw)
    }
}
