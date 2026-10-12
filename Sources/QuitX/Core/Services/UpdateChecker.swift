import AppKit
import Foundation

struct GatekeeperRelease: Decodable, Equatable {
    let version: String
    let releaseName: String?
    let releaseNotes: String?
    let publishedAt: String?
    let downloadUrl: String
    let sizeBytes: Int64?
    let fileName: String?
    let digest: String?
    let edSignature: String?
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case available(version: String, downloadURL: URL?, digest: String?, edSignature: String?)
    case upToDate(version: String)
    case failed(message: String)
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    nonisolated static let automaticCheckInterval: TimeInterval = 24 * 60 * 60
    private static let disabledPollInterval: TimeInterval = 60 * 60
    private static let initialCheckDelay: TimeInterval = 2
    private static let failureRetryInterval: TimeInterval = 15 * 60

    private var updateWorkerURL: URL {
        QuitXConstants.updateWorkerURL
    }

    @Published var isChecking = false
    @Published var checkState: UpdateCheckState = .idle
    private var automaticCheckTask: Task<Void, Never>?

    var currentVersion: String {
        QuitXConstants.appVersion
    }

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

    func startAutomaticChecks() {
        stopAutomaticChecks()
        automaticCheckTask = Task { @MainActor [weak self] in
            guard await Self.sleep(seconds: Self.initialCheckDelay) else { return }
            while !Task.isCancelled, let self {
                guard ConfigStore.shared.config.autoUpdate else {
                    guard await Self.sleep(seconds: Self.disabledPollInterval) else { return }
                    continue
                }

                let now = Date()
                let lastCheck = UserDefaults.standard.object(
                    forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheck
                ) as? Date
                var delay = Self.automaticCheckDelay(lastCheck: lastCheck, now: now)
                if let failedAt = UserDefaults.standard.object(
                    forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed
                ) as? Date {
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

                UserDefaults.standard.set(
                    now,
                    forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheck
                )
                let succeeded = await self.checkForUpdates(isUserInitiated: false)
                if succeeded {
                    UserDefaults.standard.removeObject(
                        forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed
                    )
                } else {
                    UserDefaults.standard.set(
                        Date(),
                        forKey: QuitXConstants.UserDefaultsKeys.lastAutomaticUpdateCheckFailed
                    )
                }
            }
        }
    }

    func stopAutomaticChecks() {
        automaticCheckTask?.cancel()
        automaticCheckTask = nil
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

        var request = URLRequest(url: updateWorkerURL)
        request.setValue("QuitX-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                handleError(message: "Invalid response from server", isUserInitiated: isUserInitiated)
                return false
            }

            if httpResponse.statusCode == 404 {
                handleUpToDate(isUserInitiated: isUserInitiated)
                return true
            }

            guard httpResponse.statusCode == 200 else {
                handleError(message: "Server returned status code \(httpResponse.statusCode)", isUserInitiated: isUserInitiated)
                return false
            }

            let release = try JSONDecoder().decode(GatekeeperRelease.self, from: data)
            let latestVersionRaw = release.version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let downloadURL = Self.secureDownloadURL(from: release.downloadUrl)

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                guard let downloadURL else {
                    handleError(
                        message: "Update metadata contains an invalid or insecure download URL.",
                        isUserInitiated: isUserInitiated
                    )
                    return false
                }
                guard let digest = release.digest, !digest.isEmpty else {
                    handleError(
                        message: "Update metadata is missing its checksum digest.",
                        isUserInitiated: isUserInitiated
                    )
                    return false
                }
                guard let edSignature = release.edSignature, !edSignature.isEmpty else {
                    handleError(
                        message: "Update metadata is missing its publisher signature.",
                        isUserInitiated: isUserInitiated
                    )
                    return false
                }
                handleUpdateAvailable(
                    latestVersion: latestVersionRaw,
                    downloadURL: downloadURL,
                    digest: digest,
                    edSignature: edSignature,
                    isUserInitiated: isUserInitiated
                )
                return true
            } else {
                handleUpToDate(isUserInitiated: isUserInitiated)
                return true
            }
        } catch {
            handleError(message: "Could not check for updates. Please check your internet connection and try again.", isUserInitiated: isUserInitiated)
            return false
        }
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        VersionComparator.isGreaterThan(v1, v2)
    }

    nonisolated static func secureDownloadURL(from value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    private func handleUpdateAvailable(latestVersion: String, downloadURL: URL?, digest: String?, edSignature: String?, isUserInitiated: Bool) {
        checkState = .available(version: latestVersion, downloadURL: downloadURL, digest: digest, edSignature: edSignature)
        if !isUserInitiated {
            AppUpdateWindowController.shared.showCheckWindow()
        }
    }

    private func handleUpToDate(isUserInitiated: Bool) {
        checkState = .upToDate(version: currentVersion)
    }

    private func handleError(message: String, isUserInitiated: Bool) {
        checkState = .failed(message: message)
    }
}
