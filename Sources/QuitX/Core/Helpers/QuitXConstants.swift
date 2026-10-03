import Foundation
import AppKit

enum QuitXConstants {
    static let appName = "QuitX"
    static let author = "Toufiq Hasan Kiron"
    static let primaryBundleId = "io.coreify.quitx"
    static let supportedBundleIdentifiers: Set<String> = [
        "io.coreify.quitx",
        "com.coreify.quitx",
        "com.kiron.quitx",
        "com.quitx.QuitX"
    ]

    static let supportEmail = "hello@kiron.dev"
    static let githubUser = "kiron0"
    static let githubRepo = "quitx"
    static let githubURL = URL(string: "https://github.com/kiron0/quitx")!
    static let githubIssuesURL = URL(string: "https://github.com/kiron0/quitx/issues")!

    static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    static var copyright: String {
        "Copyright © \(currentYear) \(author)"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "4"
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
