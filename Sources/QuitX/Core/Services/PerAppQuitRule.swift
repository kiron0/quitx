import Foundation

/// Per-app auto-quit rules.
///
/// Rules are keyed by lowercase bundle identifier or app name, matching the
/// same convention as the exclude list. A stored value of `0` means Never:
/// the app is exempt from automatic quitting. A missing key means the app
/// follows the global `quitInactiveAfterMinutes` setting.
enum PerAppQuitRule {
    static let neverMinutes = 0

    struct Preset: Equatable {
        /// Displayed minutes, or `nil` for "Use Default" (removes the rule).
        let minutes: Int?
        let title: String
    }

    static let presets: [Preset] = [
        Preset(minutes: nil, title: "Use Default"),
        Preset(minutes: 15, title: "After 15 minutes"),
        Preset(minutes: 30, title: "After 30 minutes"),
        Preset(minutes: 60, title: "After 1 hour"),
        Preset(minutes: 120, title: "After 2 hours"),
        Preset(minutes: 240, title: "After 4 hours"),
        Preset(minutes: 0, title: "Never"),
    ]

    /// Canonical storage key for an app: lowercase bundle ID preferred,
    /// lowercase name as fallback.
    static func ruleKey(bundleId: String?, name: String) -> String {
        let raw = (bundleId?.isEmpty == false ? bundleId! : name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return raw
    }

    /// Stored rule for an app, or `nil` when the app follows the default.
    static func storedMinutes(
        bundleId: String?,
        name: String,
        rules: [String: Int]
    ) -> Int? {
        if let bundleId, !bundleId.isEmpty,
           let value = rules[bundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] {
            return value
        }
        let nameKey = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rules[nameKey]
    }

    /// Effective timeout in minutes. Returns `0` for Never.
    static func timeoutMinutes(
        bundleId: String?,
        name: String,
        rules: [String: Int],
        globalMinutes: Int
    ) -> Int {
        storedMinutes(bundleId: bundleId, name: name, rules: rules) ?? globalMinutes
    }
}
