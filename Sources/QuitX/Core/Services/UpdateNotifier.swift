import Foundation
import UserNotifications

@MainActor
enum UpdateNotifier {
    static let identifierPrefix = "quitx-update-"
    private static let notifiedVersionKey = "quitx_update_notified_version"

    static func notifyAvailable(version: String) {
        post(
            version: version,
            kind: "available",
            title: "QuitX \(version) is available",
            body: "Open the QuitX menu and choose Update to install it."
        )
    }

    static func notifyReady(version: String) {
        post(
            version: version,
            kind: "ready",
            title: "QuitX \(version) is ready",
            body: "Choose Restart to Update in the QuitX menu to finish installing."
        )
    }

    static func shouldNotify(version: String, kind: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: notifiedVersionKey) != "\(kind):\(version)"
    }

    private static func post(version: String, kind: String, title: String, body: String) {
        guard shouldNotify(version: version, kind: kind) else { return }
        UserDefaults.standard.set("\(kind):\(version)", forKey: notifiedVersionKey)
        Task {
            let center = UNUserNotificationCenter.current()
            var status = (await center.notificationSettings()).authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
                status = (await center.notificationSettings()).authorizationStatus
            }
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(kind)-\(version)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
