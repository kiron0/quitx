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

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private var updateWorkerURL: URL {
        QuitXConstants.updateWorkerURL
    }

    @Published var isChecking = false

    var currentVersion: String {
        QuitXConstants.appVersion
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: updateWorkerURL)
        request.setValue(QuitXConstants.updateSecretKey, forHTTPHeaderField: "X-QuitX-Key")
        request.setValue("QuitX-App", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                showErrorAlert(isUserInitiated: isUserInitiated)
                return
            }

            if httpResponse.statusCode == 404 {
                showUpToDateAlert(isUserInitiated: isUserInitiated)
                return
            }

            guard httpResponse.statusCode == 200 else {
                showErrorAlert(isUserInitiated: isUserInitiated)
                return
            }

            let release = try JSONDecoder().decode(GatekeeperRelease.self, from: data)
            let latestVersionRaw = release.version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let downloadURL = URL(string: release.downloadUrl)

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                showUpdateAvailableAlert(latestVersion: latestVersionRaw, downloadURL: downloadURL)
            } else {
                showUpToDateAlert(isUserInitiated: isUserInitiated)
            }
        } catch {
            showErrorAlert(isUserInitiated: isUserInitiated)
        }
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        VersionComparator.isGreaterThan(v1, v2)
    }

    private func configureAlertIcon(_ alert: NSAlert) {
        if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
            alert.icon = appIcon
        }
    }

    private func showUpdateAvailableAlert(latestVersion: String, downloadURL: URL?) {
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of QuitX (v\(latestVersion)) is available. You currently have v\(currentVersion)."

        if let downloadURL = downloadURL {
            alert.addButton(withTitle: "Update Now")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AppUpdateWindowController.shared.showUpdateWindow(
                    targetVersion: latestVersion,
                    downloadURL: downloadURL
                )
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    private func showUpToDateAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "You're Up to Date!"
        alert.informativeText = "QuitX v\(currentVersion) is currently the newest version available."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showErrorAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = "Could not check for updates. Please check your internet connection and try again."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
}
