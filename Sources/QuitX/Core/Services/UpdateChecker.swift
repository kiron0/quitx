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

    private var updateWorkerURL: URL {
        QuitXConstants.updateWorkerURL
    }

    @Published var isChecking = false
    @Published var checkState: UpdateCheckState = .idle

    var currentVersion: String {
        QuitXConstants.appVersion
    }

    func resetState() {
        checkState = .idle
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        checkState = .checking
        defer { isChecking = false }

        if isUserInitiated {
            AppUpdateWindowController.shared.showCheckWindow()
        }

        var request = URLRequest(url: updateWorkerURL)
        request.setValue(QuitXConstants.updateSecretKey, forHTTPHeaderField: "X-QuitX-Key")
        request.setValue("QuitX-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                handleError(message: "Invalid response from server", isUserInitiated: isUserInitiated)
                return
            }

            if httpResponse.statusCode == 404 {
                handleUpToDate(isUserInitiated: isUserInitiated)
                return
            }

            guard httpResponse.statusCode == 200 else {
                handleError(message: "Server returned status code \(httpResponse.statusCode)", isUserInitiated: isUserInitiated)
                return
            }

            let release = try JSONDecoder().decode(GatekeeperRelease.self, from: data)
            let latestVersionRaw = release.version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let downloadURL = URL(string: release.downloadUrl)

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                handleUpdateAvailable(
                    latestVersion: latestVersionRaw,
                    downloadURL: downloadURL,
                    digest: release.digest,
                    isUserInitiated: isUserInitiated
                )
            } else {
                handleUpToDate(isUserInitiated: isUserInitiated)
            }
        } catch {
            handleError(message: "Could not check for updates. Please check your internet connection and try again.", isUserInitiated: isUserInitiated)
        }
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        VersionComparator.isGreaterThan(v1, v2)
    }

    private func handleUpdateAvailable(latestVersion: String, downloadURL: URL?, digest: String?, isUserInitiated: Bool) {
        checkState = .available(version: latestVersion, downloadURL: downloadURL, digest: digest)
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
