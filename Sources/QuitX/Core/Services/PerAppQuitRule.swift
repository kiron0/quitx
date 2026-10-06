import Foundation

enum PerAppQuitRule {
    static let neverMinutes = 0

    struct Preset: Equatable {
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

    static func ruleKey(bundleId: String?, name: String) -> String {
        let raw = (bundleId?.isEmpty == false ? bundleId! : name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return raw
    }

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

    static func timeoutMinutes(
        bundleId: String?,
        name: String,
        rules: [String: Int],
        globalMinutes: Int
    ) -> Int {
        storedMinutes(bundleId: bundleId, name: name, rules: rules) ?? globalMinutes
    }
}
