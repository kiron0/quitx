import AppKit
import Foundation

enum MemoryPressureTargets {
    static func select(apps: [AppInfo], config: QuitXConfig) -> [AppInfo] {
        let thresholdBytes = UInt64(max(1, config.memoryPressureThresholdMB)) * 1024 * 1024
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let musicNames = config.musicApps.map { $0.lowercased() }
        return apps.filter { app in
            guard !app.isBackground else { return false }
            guard app.memoryBytes >= thresholdBytes else { return false }
            if let bid = app.bundleId,
               QuitXConstants.supportedBundleIdentifiers.contains(bid) { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.finder { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.trash { return false }
            if let bid = app.bundleId,
               let url = AppURLCache.url(bundleId: bid),
               SystemAppProtection.isSystemProtected(
                   bundleIdentifier: bid,
                   isBackground: app.isBackground,
                   bundleURL: url
               ) { return false }
            let lowerBid = app.bundleId?.lowercased()
            let lowerName = app.name.lowercased()
            if let lowerBid, excluded.contains(lowerBid) { return false }
            if excluded.contains(lowerName) { return false }
            if config.neverQuitMusic && musicNames.contains(where: {
                lowerName.contains($0) || lowerBid?.contains($0) == true
            }) { return false }
            let ruleMinutes = PerAppQuitRule.storedMinutes(
                bundleId: app.bundleId,
                name: app.name,
                rules: config.perAppQuitRules
            )
            if ruleMinutes == PerAppQuitRule.neverMinutes { return false }
            return true
        }
    }
}

@MainActor
final class MemoryPressureService {
    static let shared = MemoryPressureService()

    private var source: DispatchSourceMemoryPressure?
    private var lastRescueDate: Date = .distantPast

    private init() {}

    func start() {
        stop()
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handlePressure()
            }
        }
        source.activate()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func handlePressure() async {
        let config = ConfigStore.shared.config
        guard config.memoryPressureQuitEnabled else { return }
        guard Date().timeIntervalSince(lastRescueDate) >= 60 else { return }
        // Stamp before the expensive scan so sustained pressure cannot rescan every event.
        lastRescueDate = Date()
        let vm = AppListViewModel.shared
        if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
            await vm.refresh()
        }
        let trigger = MemoryPressureTargets.select(
            apps: vm.apps,
            config: config
        )
        guard !trigger.isEmpty else { return }
        let targets = InactiveRescueTargets.select(
            apps: vm.apps,
            config: config,
            frontmostPid: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            ownPid: ProcessInfo.processInfo.processIdentifier
        )
        guard !targets.isEmpty else { return }
        RescueConsentController.shared.request(targets: targets, reason: .memory)
    }
}
