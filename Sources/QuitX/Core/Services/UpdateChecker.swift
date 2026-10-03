import AppKit
import Foundation

struct GitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let browser_download_url: String
    let size: Int64?
}

struct GitHubRelease: Decodable, Equatable {
    let tag_name: String
    let html_url: String?
    let name: String?
    let assets: [GitHubReleaseAsset]?
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let repoOwner = QuitXConstants.githubUser
    private let repoName = QuitXConstants.githubRepo

    var releasesWebURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
    }

    private var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    @Published var isChecking = false

    var currentVersion: String {
        QuitXConstants.appVersion
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("QuitX-App", forHTTPHeaderField: "User-Agent")
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

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersionRaw = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let releaseURL = release.html_url.flatMap { URL(string: $0) } ?? releasesWebURL
            let dmgAsset = Self.extractDMGAsset(from: release.assets)
            let downloadURL = dmgAsset.flatMap { URL(string: $0.browser_download_url) }

            if isVersion(latestVersionRaw, greaterThan: currentVersion) {
                showUpdateAvailableAlert(latestVersion: latestVersionRaw, downloadURL: downloadURL, releaseURL: releaseURL)
            } else {
                showUpToDateAlert(isUserInitiated: isUserInitiated)
            }
        } catch {
            showErrorAlert(isUserInitiated: isUserInitiated)
        }
    }

    nonisolated static func extractDMGAsset(from assets: [GitHubReleaseAsset]?) -> GitHubReleaseAsset? {
        return assets?.first(where: { $0.name.hasSuffix(".dmg") })
    }

    func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        VersionComparator.isGreaterThan(v1, v2)
    }

    private func configureAlertIcon(_ alert: NSAlert) {
        if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
            alert.icon = appIcon
        }
    }

    private func showUpdateAvailableAlert(latestVersion: String, downloadURL: URL?, releaseURL: URL) {
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of QuitX (v\(latestVersion)) is available. You currently have v\(currentVersion)."

        if let downloadURL = downloadURL {
            alert.addButton(withTitle: "Update Now")
            alert.addButton(withTitle: "View on GitHub")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AppUpdateWindowController.shared.showUpdateWindow(
                    targetVersion: latestVersion,
                    downloadURL: downloadURL,
                    releaseWebURL: releaseURL
                )
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(releaseURL)
            }
        } else {
            alert.addButton(withTitle: "Download on GitHub")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(releaseURL)
            }
        }
    }

    private func showUpToDateAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "You're Up to Date!"
        alert.informativeText = "QuitX v\(currentVersion) is currently the newest version available."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View Releases on GitHub")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(releasesWebURL)
        }
    }

    private func showErrorAlert(isUserInitiated: Bool) {
        guard isUserInitiated else { return }
        let alert = NSAlert()
        configureAlertIcon(alert)
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = "Could not connect to GitHub to check for updates. Would you like to check the releases page directly?"
        alert.addButton(withTitle: "Open GitHub")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releasesWebURL)
        }
    }
}
