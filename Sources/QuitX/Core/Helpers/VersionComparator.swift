import Foundation

enum VersionComparator {
    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let lhsInfo = parseVersion(lhs)
        let rhsInfo = parseVersion(rhs)
        let count = max(lhsInfo.components.count, rhsInfo.components.count)

        for index in 0..<count {
            let lhsPart = index < lhsInfo.components.count ? lhsInfo.components[index] : 0
            let rhsPart = index < rhsInfo.components.count ? rhsInfo.components[index] : 0
            if lhsPart != rhsPart { return lhsPart < rhsPart ? -1 : 1 }
        }

        switch (lhsInfo.isPreRelease, rhsInfo.isPreRelease) {
        case (true, false): return -1
        case (false, true): return 1
        default: return 0
        }
    }

    static func isGreaterThan(_ lhs: String, _ rhs: String) -> Bool {
        compare(lhs, rhs) > 0
    }

    private struct VersionInfo {
        let components: [Int]
        let isPreRelease: Bool
    }

    private static func parseVersion(_ version: String) -> VersionInfo {
        let stripped = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let hyphenIdx = stripped.firstIndex(of: "-")
        let numericPart = hyphenIdx.map { String(stripped[stripped.startIndex..<$0]) } ?? stripped
        let isPreRelease = hyphenIdx != nil

        let components = numericPart
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }

        return VersionInfo(components: components, isPreRelease: isPreRelease)
    }
}
