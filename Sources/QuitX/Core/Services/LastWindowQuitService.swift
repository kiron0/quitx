import AppKit
import Combine
import Foundation

/// Eligibility for the "quit when the last window closes" automation.
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

/// Decides whether a previously windowed app has actually closed its windows.
enum LastWindowQuitWindowState {
    static func mergedTrackedIDs(
        current: Set<CGWindowID> = [],
        visible: Set<CGWindowID>,
        all: Set<CGWindowID>
    ) -> Set<CGWindowID> {
        current.union(visible).union(all)
    }

    static func isClosed(
        tracked: Set<CGWindowID>,
        visible: Set<CGWindowID>,
        all: Set<CGWindowID>
    ) -> Bool {
        visible.isEmpty && tracked.isDisjoint(with: all)
    }
}

/// Reads app-owned window identifiers from window-server metadata.
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

    static func allWindowIDs() -> [pid_t: Set<CGWindowID>]? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        return windowIDs(from: list)
    }
}

/// Force-quits a regular app once its last window closes.
///
/// Closing the red close button or the last window with ⌘W destroys the window,
/// so its window ID disappears from the window server. Minimized windows, hidden
/// apps, and windows on another Space keep their window ID and are preserved.
@MainActor
final class LastWindowQuitService: ObservableObject {
    static let shared = LastWindowQuitService()

    private struct TrackedApp {
        let pid: pid_t
        let bundleId: String?
        let name: String
        var windowIDs: Set<CGWindowID>
        var emptySamples: Int
    }

    private var tracked: [pid_t: TrackedApp] = [:]
    private var pendingQuits: Set<pid_t> = []
    private var configSubscription: AnyCancellable?
    private var pollTask: Task<Void, Never>?

    private let pollInterval: Duration = .seconds(1)
    private let requiredEmptySamples = 2

    private init() {}

    func start() {
        guard configSubscription == nil else { return }
        configSubscription = ConfigStore.shared.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.syncTrackingState() }
            }
        syncTrackingState()
    }

    func stop() {
        configSubscription = nil
        stopPolling()
        tracked.removeAll()
        pendingQuits.removeAll()
    }

    private func syncTrackingState() {
        if ConfigStore.shared.config.quitWhenLastWindowClosed {
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
        let config = ConfigStore.shared.config
        let ownPid = ProcessInfo.processInfo.processIdentifier

        guard let visible = LastWindowQuitWindowCounter.visibleWindowIDs(),
              let allWindows = LastWindowQuitWindowCounter.allWindowIDs() else { return }

        var livePids: Set<pid_t> = []
        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            guard pid > 0, pid != ownPid, !app.isTerminated else { continue }
            livePids.insert(pid)

            guard app.activationPolicy == .regular else { continue }
            guard tracked[pid] == nil, !pendingQuits.contains(pid) else { continue }
            let windowIDs = visible[pid] ?? []
            guard !windowIDs.isEmpty else { continue }

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
                windowIDs: LastWindowQuitWindowState.mergedTrackedIDs(
                    visible: windowIDs,
                    all: allWindows[pid] ?? []
                ),
                emptySamples: 0
            )
        }

        for pid in Array(tracked.keys) where !livePids.contains(pid) {
            tracked.removeValue(forKey: pid)
        }

        for pid in Array(tracked.keys) {
            guard var entry = tracked[pid] else { continue }
            let visibleIDs = visible[pid] ?? []

            if !visibleIDs.isEmpty {
                entry.windowIDs = LastWindowQuitWindowState.mergedTrackedIDs(
                    current: entry.windowIDs,
                    visible: visibleIDs,
                    all: allWindows[pid] ?? []
                )
                entry.emptySamples = 0
                tracked[pid] = entry
                continue
            }

            let isClosed = LastWindowQuitWindowState.isClosed(
                tracked: entry.windowIDs,
                visible: visibleIDs,
                all: allWindows[pid] ?? []
            )
            if !isClosed {
                entry.emptySamples = 0
                tracked[pid] = entry
                continue
            }

            entry.emptySamples += 1
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
            let results = await QuitService.shared.quit(apps: [app], force: true)
            if results.first?.success == true {
                RecentlyQuitService.shared.record(app: app)
            }
            self?.pendingQuits.remove(pid)
        }
    }

    private func stillWindowless(entry: TrackedApp) -> Bool {
        guard let visible = LastWindowQuitWindowCounter.visibleWindowIDs(),
              let allWindows = LastWindowQuitWindowCounter.allWindowIDs() else { return false }
        return LastWindowQuitWindowState.isClosed(
            tracked: entry.windowIDs,
            visible: visible[entry.pid] ?? [],
            all: allWindows[entry.pid] ?? []
        )
    }

    private static func resolvedName(for app: NSRunningApplication) -> String {
        let raw = app.localizedName
            ?? app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? app.executableURL?.lastPathComponent
        guard let raw, !raw.isEmpty else { return "" }
        return SystemAppProtection.cleanAppName(raw)
    }
}
