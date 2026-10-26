import Foundation
import AppKit

enum QuitXConstants {
    static let appName = "QuitX"
    static let author = "Toufiq Hasan Kiron"
    static let primaryBundleId = "io.coreify.quitx"
    static let firstLaunchSeenKey = UserDefaultsKeys.firstLaunchSeen
    static let supportedBundleIdentifiers: Set<String> = [
        primaryBundleId,
        "com.coreify.quitx",
        "com.kiron.quitx",
        "com.quitx.QuitX"
    ]

    enum Notifications {
        static let showSettings = Notification.Name("\(QuitXConstants.primaryBundleId).showSettings")
        static let showPreferences = Notification.Name("\(QuitXConstants.primaryBundleId).showPreferences")
        static let showPopover = Notification.Name("\(QuitXConstants.primaryBundleId).showPopover")
        static let dismissSettingsTooltips = Notification.Name("\(QuitXConstants.primaryBundleId).dismissSettingsTooltips")
    }

    enum UserDefaultsKeys {
        static let config = "QuitXConfig"
        static let recentlyQuit = "QuitXRecentlyQuit"
        static let firstLaunchSeen = "quitx_first_launch_seen_v1"
        static let lastSeenVersion = "quitx_last_seen_version"
        static let accessibilityTrustedVersion = "quitx_accessibility_trusted_version"
        static let lastAutomaticUpdateCheck = "quitx_last_automatic_update_check"
        static let lastAutomaticUpdateCheckFailed = "quitx_last_automatic_update_check_failed"
        static let launchAtLogin = "quitx_launch_at_login"
        static let activateMenuEnabled = "sc_activate_enabled"
        static let activateMenuKeys = "sc_activate_keys"
        static let quitAllEnabled = "sc_quit_enabled"
        static let quitAllKeys = "sc_quit_keys"
        static let forceQuitAllEnabled = "sc_force_enabled"
        static let forceQuitAllKeys = "sc_force_keys"
        static let openSettingsEnabled = "sc_settings_enabled"
        static let openSettingsKeys = "sc_settings_keys"
        static let refreshAppsEnabled = "sc_refresh_enabled"
        static let refreshAppsKeys = "sc_refresh_keys"
        static let openHelpEnabled = "sc_help_enabled"
        static let openHelpKeys = "sc_help_keys"
        static let openChangelogEnabled = "sc_changelog_enabled"
        static let openChangelogKeys = "sc_changelog_keys"
        static let openUninstallerEnabled = "sc_uninstaller_enabled"
        static let openUninstallerKeys = "sc_uninstaller_keys"
    }

    enum HotKeys {
        static let signature: OSType = 1380993096
        static let activateMenuId: UInt32 = 1
        static let quitAllId: UInt32 = 2
        static let forceQuitAllId: UInt32 = 3
        static let openSettingsId: UInt32 = 4
        static let refreshAppsId: UInt32 = 5
        static let openHelpId: UInt32 = 6
        static let openChangelogId: UInt32 = 7
        static let openUninstallerId: UInt32 = 8
    }

    enum SystemBundleIds {
        static let finder = "com.apple.finder"
        static let trash = "com.apple.trash"
    }

    static let lastWindowProtectedBundleIds: Set<String> = [
        "io.github.treposting.marquee"
    ]

    static let supportEmail = "hello@kiron.dev"
    static let githubRepository = "kiron0/quitx"
    static let websiteURL = URL(string: "https://quitx.kiron.dev")!
    static let authorURL = URL(string: "https://kiron.dev")!
    static let repositoryURL = URL(string: "https://github.com/\(githubRepository)")!
    static let issuesURL = URL(string: "https://github.com/\(githubRepository)/issues/new")!
    static let releasesURL = URL(string: "https://github.com/\(githubRepository)/releases")!
    static let releasesPageURL = URL(string: "https://github.com/\(githubRepository)/releases/latest")!
    static let buyMeACoffeeURL = URL(string: "https://buymeacoffee.com/_thk")!

    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static var copyright: String {
        "Copyright © \(currentYear) \(author)"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0-dev"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static func sayHiURL() -> URL? {
        let subject = "Saying hi from QuitX!"
        let body = """
        Hi Toufiq,

        I wanted to say hi and drop a quick note about QuitX!

        """
        return makeMailtoURL(to: supportEmail, subject: subject, body: body)
    }

    static func contactURL() -> URL? {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let subject = "QuitX Feedback & Support (v\(appVersion))"
        let body = """
        Hi Toufiq,

        Feedback Type: [Bug Report / Feature Request / Other]

        Details:
        [Please describe your issue, feedback, or suggestion here]

        Steps to reproduce (if bug):
        1.
        2.

        Expected behavior:

        System Info:
        - QuitX Version: v\(appVersion) (\(buildNumber))
        - macOS Version: \(osVersion)
        """
        return makeMailtoURL(to: supportEmail, subject: subject, body: body)
    }

    private static func makeMailtoURL(to: String, subject: String, body: String) -> URL? {
        let allowed = CharacterSet.urlQueryAllowed
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return URL(string: "mailto:\(to)")
        }
        return URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
}
