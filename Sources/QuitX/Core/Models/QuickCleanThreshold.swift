import Foundation

enum QuickCleanSizeUnit: String, Codable, CaseIterable, Sendable {
    case mb = "MB"
    case gb = "GB"

    var megabytes: Int {
        switch self {
        case .mb: 1
        case .gb: 1_000
        }
    }

    var maxFractionDigits: Int {
        switch self {
        case .mb: 0
        case .gb: 3
        }
    }

    var stepMegabytes: Int {
        switch self {
        case .mb: 100
        case .gb: 1_000
        }
    }
}

enum QuickCleanThreshold {
    static let bytesPerMB: Int64 = 1_000_000
    static let minMB = 100
    static let maxMB = 500_000

    enum Problem: Error, Equatable, Sendable {
        case empty
        case notANumber
        case negative
        case zero
        case tooPrecise(QuickCleanSizeUnit)
        case belowMinimum
        case aboveMaximum

        var message: String {
            switch self {
            case .empty: "Enter a size."
            case .notANumber: "Enter a number, like 800 MB or 2.5 GB."
            case .negative: "Size can't be negative."
            case .zero: "Size must be more than 0."
            case .tooPrecise(.mb): "Use whole megabytes."
            case .tooPrecise(.gb): "Use at most 3 decimal places for GB."
            case .belowMinimum: "Minimum is \(QuickCleanThreshold.format(minMB, unit: .mb)) MB."
            case .aboveMaximum: "Maximum is \(QuickCleanThreshold.format(maxMB, unit: .gb)) GB."
            }
        }
    }

    struct Parsed: Equatable, Sendable {
        let megabytes: Int
        let unit: QuickCleanSizeUnit
    }

    static func clamped(_ megabytes: Int) -> Int {
        min(max(megabytes, minMB), maxMB)
    }

    static func parse(_ text: String, unit: QuickCleanSizeUnit) -> Result<Parsed, Problem> {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !body.isEmpty else { return .failure(.empty) }

        var resolvedUnit = unit
        for (suffix, suffixUnit) in [("gb", QuickCleanSizeUnit.gb), ("mb", .mb), ("g", .gb), ("m", .mb)] where body.hasSuffix(suffix) {
            body = String(body.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            resolvedUnit = suffixUnit
            break
        }

        if body.hasPrefix("-") { return .failure(.negative) }
        if body.hasPrefix("+") { body.removeFirst() }
        body = body.replacingOccurrences(of: ",", with: ".")

        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard !body.isEmpty, parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts.contains(where: { !$0.isEmpty }) else {
            return .failure(.notANumber)
        }

        let integerDigits = String(parts[0])
        let fractionDigits = parts.count == 2 ? String(parts[1]) : ""
        let significantFraction = fractionDigits.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        guard significantFraction.count <= resolvedUnit.maxFractionDigits else {
            return .failure(.tooPrecise(resolvedUnit))
        }

        let trimmedInteger = integerDigits.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        guard trimmedInteger.count <= 7 else { return .failure(.aboveMaximum) }

        let wholePart = Int(trimmedInteger.isEmpty ? "0" : trimmedInteger) ?? 0
        let paddedFraction = significantFraction.padding(toLength: resolvedUnit.maxFractionDigits, withPad: "0", startingAt: 0)
        let fractionPart = Int(paddedFraction.isEmpty ? "0" : paddedFraction) ?? 0
        let megabytes = wholePart * resolvedUnit.megabytes + fractionPart

        guard megabytes > 0 else { return .failure(.zero) }
        guard megabytes >= minMB else { return .failure(.belowMinimum) }
        guard megabytes <= maxMB else { return .failure(.aboveMaximum) }
        return .success(Parsed(megabytes: megabytes, unit: resolvedUnit))
    }

    static func format(_ megabytes: Int, unit: QuickCleanSizeUnit) -> String {
        let whole = megabytes / unit.megabytes
        let remainder = megabytes % unit.megabytes
        guard remainder > 0, unit.maxFractionDigits > 0 else { return "\(whole)" }
        let padded = String(repeating: "0", count: max(0, unit.maxFractionDigits - String(remainder).count)) + String(remainder)
        let digits = padded.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return "\(whole).\(digits)"
    }

    static func stepped(_ megabytes: Int, unit: QuickCleanSizeUnit, up: Bool) -> Int {
        let step = unit.stepMegabytes
        let snapped = up ? (megabytes / step + 1) * step : ((megabytes + step - 1) / step - 1) * step
        return clamped(snapped)
    }
}
