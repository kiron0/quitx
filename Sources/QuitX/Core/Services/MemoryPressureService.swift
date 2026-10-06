import AppKit
import Foundation

/// Selects regular apps to terminate gracefully on memory pressure.
///
/// Conservative by design: background processes are never touched here,
/// and excluded, music-protected, per-app Never, Finder, Trash, and QuitX
/// itself are always skipped. Termination is graceful only, never forced.
enum MemoryPressureTargets {
    static func select(apps: [AppInfo], config: QuitXConfig) -> [AppInfo] {
        let thresholdBytes = UInt64(max(1, config.memoryPressureThresholdMB)) * 1024 * 1024
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let musicNames = config.musicApps.map { $0.lowercased() }
        return apps.filter { app in
            guard !app.isBackground else { return false }
            guard app.memoryBytes >= thresholdBytes else { return false }
            if let bid = app.bundleId,
               QuitXIdentity.supportedBundleIdentifiers.contains(bid) { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.finder { return false }
            if app.bundleId == QuitXConstants.SystemBundleIds.trash { return false }
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
        await AppListViewModel.shared.refresh()
        let targets = MemoryPressureTargets.select(
            apps: AppListViewModel.shared.apps,
            config: config
        )
        guard !targets.isEmpty else { return }
        await AppListViewModel.shared.quitSilently(targets: targets, force: false)
    }
}
