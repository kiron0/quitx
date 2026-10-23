import AppKit
import Foundation

struct GitHubRelease: Decodable, Equatable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadUrl: String
        let size: Int64?
        let digest: String?
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String?
    let publishedAt: String?
    let draft: Bool?
    let prerelease: Bool?
    let assets: [Asset]

    var version: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV ").union(.whitespacesAndNewlines))
    }

    var installerAsset: Asset? {
        let dmgs = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }
        return dmgs.first { $0.name.hasPrefix(QuitXConstants.appName) } ?? dmgs.first
    }

    static func decode(_ data: Data) throws -> GitHubRelease {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }
}

struct AvailableUpdate: Equatable {
    let version: String
    let downloadURL: URL
    let digest: String?
    let notes: String?
    let releasePage: URL?
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case available(version: String, downloadURL: URL?, digest: String?)
    case upToDate(version: String)
    case failed(message: String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    nonisolated static let automaticCheckInterval: TimeInterval = 6 * 60 * 60
    private static let disabledPollInterval: TimeInterval = 60 * 60
    private static let initialCheckDelay: TimeInterval = 20
    private static let failureRetryInterval: TimeInterval = 30 * 60
    private static let etagKey = "quitx_update_release_etag"
    private static let cachedReleaseKey = "quitx_update_release_cache"

    @Published var isChecking = false
    @Published var checkState: UpdateCheckState = .idle
    @Published private(set) var availableUpdate: AvailableUpdate?
    private var automaticCheckTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    var currentVersion: String {
        QuitXConstants.appVersion
    }

    var releaseNotes: String? { availableUpdate?.notes }

    func resetState() {
        checkState = .idle
    }

    nonisolated static func automaticCheckDelay(
        lastCheck: Date?,
        now: Date,
        interval: TimeInterval = automaticCheckInterval
    ) -> TimeInterval {
        guard let lastCheck, lastCheck <= now else { return 0 }
        return max(0, interval - now.timeIntervalSince(lastCheck))
    }

    nonisolated static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(QuitXConstants.githubRepository)/releases/latest")!
    }

    func startAutomaticChecks() {
        stopAutomaticChecks()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startAutomaticChecks()
            }
        }
        automaticCheckTask = Task { @MainActor [weak self] in
            guard await Self.sleep(seconds: Self.initialCheckDelay) else { return }
            while !Task.isCancelled, let self {
                guard ConfigStore.shared.config.autoUpdate else {
                    guard await Self.sleep(seconds: Self.disabledPollInterval) else { return }
                    continue
                }

                let now = Date()
                let defaults = UserDefaults.standard
                let lastCheck = defaults.object(forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheck) as? Date
                var delay = Self.automaticCheckDelay(lastCheck: lastCheck, now: now)
                if let failedAt = defaults.object(forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed) as? Date {
                    delay = min(delay, max(0, Self.failureRetryInterval - now.timeIntervalSince(failedAt)))
                }
                if delay > 0 {
                    guard await Self.sleep(seconds: delay) else { return }
                    continue
                }
                if self.isChecking {
                    guard await Self.sleep(seconds: 60) else { return }
                    continue
                }

                defaults.set(now, forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheck)
                let succeeded = await self.checkForUpdates(isUserInitiated: false)
                if succeeded {
                    defaults.removeObject(forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed)
                } else {
                    defaults.set(Date(), forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed)
                }
            }
        }
    }

    func stopAutomaticChecks() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
    }

    private nonisolated static func sleep(seconds: TimeInterval) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    @discardableResult
    func checkForUpdates(isUserInitiated: Bool = true) async -> Bool {
        if isUserInitiated {
            AppUpdateWindowController.shared.showCheckWindow()
        }
        guard !isChecking else { return false }
        isChecking = true
        checkState = .checking
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            let result = Self.evaluate(release: release, currentVersion: currentVersion)
            switch result {
            case .success(let update?):
                availableUpdate = update
                checkState = .available(version: update.version, downloadURL: update.downloadURL, digest: update.digest)
                if !isUserInitiated {
                    handleBackgroundUpdate(update)
                }
            case .success(nil):
                availableUpdate = nil
                checkState = .upToDate(version: currentVersion)
            case .failure(let error):
                checkState = .failed(message: error.localizedDescription)
                return false
            }
            return true
        } catch let error as UpdateCheckError {
            checkState = .failed(message: error.localizedDescription)
            return false
        } catch {
            checkState = .failed(message: UpdateCheckError.network.localizedDescription)
            return false
        }
    }

    nonisolated static func evaluate(release: GitHubRelease, currentVersion: String) -> Result<AvailableUpdate?, UpdateCheckError> {
        guard release.draft != true, release.prerelease != true else { return .success(nil) }
        let latest = release.version
        guard !latest.isEmpty, VersionComparator.isGreaterThan(latest, currentVersion) else { return .success(nil) }
        guard let asset = release.installerAsset,
              let url = secureDownloadURL(from: asset.browserDownloadUrl) else {
            return .failure(.missingInstaller)
        }
        return .success(AvailableUpdate(
            version: latest,
            downloadURL: url,
            digest: asset.digest,
            notes: release.body,
            releasePage: release.htmlUrl.flatMap(secureDownloadURL(from:))
        ))
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("QuitX/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let defaults = UserDefaults.standard
        let cached = defaults.data(forKey: Self.cachedReleaseKey)
        if cached != nil, let etag = defaults.string(forKey: Self.etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateCheckError.network
        }
        guard let http = response as? HTTPURLResponse else { throw UpdateCheckError.network }

        switch http.statusCode {
        case 200:
            let release: GitHubRelease
            do {
                release = try GitHubRelease.decode(data)
            } catch {
                throw UpdateCheckError.invalidResponse
            }
            defaults.set(data, forKey: Self.cachedReleaseKey)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(etag, forKey: Self.etagKey)
            } else {
                defaults.removeObject(forKey: Self.etagKey)
            }
            return release
        case 304:
            guard let cached, let release = try? GitHubRelease.decode(cached) else {
                defaults.removeObject(forKey: Self.etagKey)
                throw UpdateCheckError.invalidResponse
            }
            return release
        case 404:
            throw UpdateCheckError.noRelease
        case 403, 429:
            throw UpdateCheckError.rateLimited
        default:
            throw UpdateCheckError.server(http.statusCode)
        }
    }

    func presentAvailableUpdate() {
        let service = UpdateDownloadService.shared
        switch service.state {
        case .downloading, .extracting, .ready:
            AppUpdateWindowController.shared.showCheckWindow()
            return
        default:
            break
        }
        guard let update = availableUpdate else {
            Task { await checkForUpdates(isUserInitiated: true) }
            return
        }
        checkState = .available(version: update.version, downloadURL: update.downloadURL, digest: update.digest)
        AppUpdateWindowController.shared.showCheckWindow()
    }

    func restartToUpdate() {
        let service = UpdateDownloadService.shared
        guard case .ready(let stagedURL, _) = service.state else {
            presentAvailableUpdate()
            return
        }
        service.installAndRelaunch(stagedURL: stagedURL)
    }

    private func handleBackgroundUpdate(_ update: AvailableUpdate) {
        guard ConfigStore.shared.config.autoInstallUpdates else {
            UpdateNotifier.notifyAvailable(version: update.version)
            return
        }
        let service = UpdateDownloadService.shared
        switch service.state {
        case .downloading, .extracting:
            return
        case .ready(_, let version) where version == update.version:
            return
        default:
            service.startDownload(from: update.downloadURL, version: update.version, digest: update.digest, installWhenReady: true)
        }
    }

    nonisolated static func secureDownloadURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        VersionComparator.isGreaterThan(v1, v2)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(availableUpdate?.releasePage ?? QuitXConstants.releasesPageURL)
    }
}

enum UpdateCheckError: LocalizedError, Equatable {
    case network
    case invalidResponse
    case noRelease
    case rateLimited
    case missingInstaller
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Could not reach GitHub. Check your internet connection and try again."
        case .invalidResponse:
            return "GitHub returned release information QuitX could not read."
        case .noRelease:
            return "No published QuitX release was found on GitHub."
        case .rateLimited:
            return "GitHub is limiting update checks right now. Try again in a little while."
        case .missingInstaller:
            return "The latest release has no installer attached. Download it from the releases page instead."
        case .server(let code):
            return "GitHub returned status \(code). Try again later."
        }
    }
}
