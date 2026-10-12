import AppKit
import Foundation

enum AppURLCache {
    private static var storage: [String: URL?] = [:]
    private static let lock = NSLock()

    static func url(bundleId: String) -> URL? {
        lock.lock()
        if let cached = storage[bundleId] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        lock.lock()
        storage[bundleId] = .some(url)
        lock.unlock()
        return url
    }
}

enum InactiveRescueTargets {
    static func select(
        apps: [AppInfo],
        config: QuitXConfig,
        frontmostPid: pid_t?,
        ownPid: pid_t
    ) -> [AppInfo] {
        let excluded = Set(config.exclude.map { $0.lowercased() })
        let musicNames = config.musicApps.map { $0.lowercased() }
        return apps.filter { app in
            guard !app.isBackground else { return false }
            guard app.windowCount > 0 else { return false }
            guard !app.pids.isEmpty else { return false }
            if app.pids.contains(ownPid) { return false }
            if let frontmostPid, app.pids.contains(frontmostPid) { return false }
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
