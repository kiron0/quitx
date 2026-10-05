import Foundation

enum VersionComparator {
    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = versionComponents(lhs)
        let rhsParts = versionComponents(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsPart = index < lhsParts.count ? lhsParts[index] : 0
            let rhsPart = index < rhsParts.count ? rhsParts[index] : 0
            if lhsPart != rhsPart { return lhsPart < rhsPart ? -1 : 1 }
        }
        return 0
    }

    static func isGreaterThan(_ lhs: String, _ rhs: String) -> Bool {
        compare(lhs, rhs) > 0
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { component in
                Int(component.prefix(while: { $0.isNumber })) ?? 0
            }
    }
}
