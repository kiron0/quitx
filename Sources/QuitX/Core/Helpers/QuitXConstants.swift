import Foundation
import AppKit

enum QuitXConstants {
    static let appName = "QuitX"
    static let author = "Toufiq Hasan Kiron"
    static let primaryBundleId = "io.coreify.quitx"
    static let firstLaunchSeenKey = UserDefaultsKeys.firstLaunchSeen
    static let supportedBundleIdentifiers: Set<String> = [
        "io.coreify.quitx",
        "com.coreify.quitx",
        "com.kiron.quitx",
        "com.quitx.QuitX"
    ]

    enum Notifications {
        static let showSettings = Notification.Name("io.coreify.quitx.showSettings")
        static let showPreferences = Notification.Name("io.coreify.quitx.showPreferences")
        static let showPopover = Notification.Name("io.coreify.quitx.showPopover")
    }

    enum UserDefaultsKeys {
        static let config = "QuitXConfig"
        static let firstLaunchSeen = "quitx_first_launch_seen_v1"
        static let launchAtLogin = "quitx_launch_at_login"
        static let activateMenuEnabled = "sc_activate_enabled"
        static let activateMenuKeys = "sc_activate_keys"
        static let quitAllEnabled = "sc_quit_enabled"
        static let quitAllKeys = "sc_quit_keys"
        static let forceQuitAllEnabled = "sc_force_enabled"
        static let forceQuitAllKeys = "sc_force_keys"
    }

    enum HotKeys {
        static let signature: OSType = 1380993096 // 'QXHK'
        static let activateMenuId: UInt32 = 1
        static let quitAllId: UInt32 = 2
        static let forceQuitAllId: UInt32 = 3
    }

    enum SystemBundleIds {
        static let finder = "com.apple.finder"
        static let trash = "com.apple.trash"
    }

    static let supportEmail = "hello@kiron.dev"
    static let updateWorkerURL = URL(string: "https://quitx-update-gatekeeper.kiron.workers.dev/latest")!
    static var updateSecretKey: String {
        if let key = Bundle.main.infoDictionary?["QUITX_UPDATE_SECRET_KEY"] as? String, !key.isEmpty {
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["QUITX_UPDATE_SECRET_KEY"], !envKey.isEmpty {
            return envKey
        }
        return ""
    }

    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static var copyright: String {
        "Copyright © \(currentYear) \(author)"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.7"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "8"
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
