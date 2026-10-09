import AppKit
import Foundation

enum SystemAppProtection {
    private static let groupedSuffixRegex = try? NSRegularExpression(pattern: #"\s*\([^)]*\)$"#)

    static func cleanAppName(_ rawName: String) -> String {
        let filtered = rawName.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x200B...0x200D, 0x200E, 0x200F, 0xFEFF:
                return false
            default:
                return true
            }
        }
        return String(filtered).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanGroupedName(_ name: String) -> String {
        guard let regex = groupedSuffixRegex else { return name }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        let stripped = regex.stringByReplacingMatches(
            in: name,
            options: [],
            range: range,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? name : stripped
    }

    private static let criticalAppleBundleIds: Set<String> = [
        "com.apple.dock",
        "com.apple.spotlight",
        "com.apple.systemuiserver",
        "com.apple.windowmanager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.loginwindow",
        "com.apple.screensaver.engine"
    ]

    static func isSystemProtected(
        bundleIdentifier: String?,
        isBackground: Bool,
        path: String
    ) -> Bool {
        let bid = bundleIdentifier ?? ""
        if !bid.isEmpty && QuitXConstants.supportedBundleIdentifiers.contains(bid) {
            return true
        }

        if !bid.isEmpty && criticalAppleBundleIds.contains(bid.lowercased()) {
            return true
        }

        if path.hasPrefix("/System/Library/PrivateFrameworks/") || path.hasPrefix("/usr/") {
            return true
        }

        if isBackground {
            if path.hasPrefix("/System/Library/")
                || path.hasPrefix("/System/Volumes/Preboot/")
                || path.hasPrefix("/Library/Apple/System/") {
                return true
            }
        }

        return false
    }

    static func isSystemProtected(
        bundleIdentifier: String?,
        isBackground: Bool,
        bundleURL: URL?,
        executableURL: URL? = nil
    ) -> Bool {
        let bundlePath = bundleURL?.path ?? ""
        let execPath = executableURL?.path ?? ""
        let path = bundlePath.isEmpty ? execPath : bundlePath
        return isSystemProtected(bundleIdentifier: bundleIdentifier, isBackground: isBackground, path: path)
    }
}
