import Foundation
import IOKit.ps

struct BatterySnapshot: Equatable, Sendable {
    let percent: Int
    let isCharging: Bool
    let isACPower: Bool
    let timeToEmptyMin: Int?
    let timeToFullMin: Int?
    let amperageMA: Int?
    let voltageMV: Int?
    let powerW: Double?
    let tempC: Double?
    let chargeMAh: Int?
    let designCapacityMAh: Int?
    let maxCapacityMAh: Int?
    let cycleCount: Int?
    let condition: String?
    let healthPercent: Int?
    let chargingLimitPercent: Int?
}

enum BatteryDetailSampler {
    private static let batteryType = "InternalBattery"
    private static let chargingLimitDomain = "com.apple.batteryui.charging.mac"
    private static let chargingLimitKey = "com.apple.batteryui.charging.mac.prior.limit"
    private static var systemHealthCache: (percent: Int?, timestamp: Date)?
    private static let healthLock = NSLock()
    private static var healthRefreshInFlight = false

    static func snapshot(
        descriptions: [[String: Any]]? = nil,
        smartBattery: [String: Any]? = nil,
        chargingLimitPercent: Int? = nil
    ) -> BatterySnapshot? {
        let descs = descriptions ?? BatterySaver.currentDescriptions()
        guard let battery = descs.first(where: { ($0["Type"] as? String) == batteryType }) else {
            return nil
        }
        let smart = smartBattery ?? readSmartBattery()

        guard let rawPercent = intValue(battery[kIOPSCurrentCapacityKey as String]) else {
            return nil
        }
        let percent = max(0, min(100, rawPercent))
        let isACPower = !BatterySaver.isOnBattery(descriptions: descs)
        let timeToEmpty = unknownToNil(intValue(battery[kIOPSTimeToEmptyKey as String]))
        let timeToFull = unknownToNil(intValue(battery[kIOPSTimeToFullChargeKey as String]))
        let isCharging = boolValue(battery, kIOPSIsChargingKey as String)
            ?? boolValue(smart, "IsCharging")
            ?? false

        let amperage = saneAmperage(intValue(smart, "Amperage"))
            ?? saneAmperage(intValue(smart, "InstantAmperage"))
        let voltage = saneVoltage(intValue(smart, "Voltage"))
        let powerW: Double? = {
            guard let amperage, let voltage else { return nil }
            return Double(abs(amperage) * voltage) / 1_000_000
        }()
        let maxCapacity = intValue(smart, "AppleRawMaxCapacity") ?? intValue(smart, "MaxCapacity")
        let designCapacity = intValue(smart, "DesignCapacity")
        let batteryData = smart?["BatteryData"] as? [String: Any]
        let tempC: Double? = {
            if let deciKelvin = intValue(smart, "Temperature"), deciKelvin > 0 {
                return Double(deciKelvin) / 10.0 - 273.15
            }
            if let centiCelsius = intValue(batteryData, "Temperature"), centiCelsius > 0 {
                return Double(centiCelsius) / 100.0
            }
            return nil
        }()
        return BatterySnapshot(
            percent: percent,
            isCharging: isCharging,
            isACPower: isACPower,
            timeToEmptyMin: timeToEmpty,
            timeToFullMin: timeToFull,
            amperageMA: amperage,
            voltageMV: voltage,
            powerW: powerW,
            tempC: tempC,
            chargeMAh: intValue(batteryData, "RemainingCapacity")
                ?? intValue(smart, "AppleRawCurrentCapacity"),
            designCapacityMAh: intValue(batteryData, "DesignCapacity") ?? designCapacity,
            maxCapacityMAh: intValue(batteryData, "FullChargeCapacity") ?? maxCapacity,
            cycleCount: intValue(smart, "CycleCount"),
            condition: healthCondition(smart: smart, batteryData: batteryData, battery: battery),
            healthPercent: smartBattery == nil
                ? (Self.systemInformationHealthPercent() ?? Self.healthPercent(smart: smart, batteryData: batteryData))
                : Self.healthPercent(smart: smart, batteryData: batteryData),
            chargingLimitPercent: chargingLimitPercent ?? Self.readChargingLimit()
        )
    }

    static func readChargingLimit(
        persistentDomain: [String: Any]? = UserDefaults.standard.persistentDomain(
            forName: chargingLimitDomain
        )
    ) -> Int? {
        guard let value = persistentDomain?[chargingLimitKey] else { return nil }
        if let limit = value as? Int, limit >= 50, limit <= 100 { return limit }
        if let limit = (value as? NSNumber)?.intValue, limit >= 50, limit <= 100 { return limit }
        return nil
    }

    static func healthPercent(smart: [String: Any]?, batteryData: [String: Any]?) -> Int? {
        let design = intValue(batteryData, "DesignCapacity")
            ?? intValue(smart, "DesignCapacity")
        guard let design, design > 0 else { return nil }
        let nominal = intValue(batteryData, "NominalChargeCapacity")
        let fullCharge = intValue(batteryData, "FullChargeCapacity")
        let rawMax = intValue(smart, "AppleRawMaxCapacity")
        if let nominal, let fullCharge, nominal > 0, fullCharge > 0 {
            let blend = Double(nominal + fullCharge) / 2
            return Int((blend / Double(design) * 100).rounded())
        }
        if let nominal, nominal > 0 {
            return Int((Double(nominal) / Double(design) * 100).rounded())
        }
        if let fullCharge, fullCharge > 0 {
            return Int((Double(fullCharge) / Double(design) * 100).rounded())
        }
        if let rawMax, rawMax > 0 {
            return Int((Double(rawMax) / Double(design) * 100).rounded())
        }
        return nil
    }

    static func systemInformationHealthPercent() -> Int? {
        healthLock.lock()
        let cache = systemHealthCache
        healthLock.unlock()

        if let cache, Date().timeIntervalSince(cache.timestamp) < 60 {
            return cache.percent
        }
        if cache == nil {
            // Cold start: one synchronous load so first caller sees the real value.
            let value = loadSystemHealthPercent()
            healthLock.lock()
            systemHealthCache = (value, Date())
            healthLock.unlock()
            return value
        }
        // Stale: refresh off the calling thread; serve last known value.
        scheduleHealthRefresh()
        return cache?.percent
    }

    private static func scheduleHealthRefresh() {
        healthLock.lock()
        if healthRefreshInFlight {
            healthLock.unlock()
            return
        }
        healthRefreshInFlight = true
        healthLock.unlock()
        Task.detached(priority: .utility) {
            let value = loadSystemHealthPercent()
            healthLock.lock()
            systemHealthCache = (value, Date())
            healthRefreshInFlight = false
            healthLock.unlock()
        }
    }

    private static func loadSystemHealthPercent() -> Int? {
        guard let output = shellOutput("/usr/sbin/system_profiler", arguments: ["SPPowerDataType"]) else {
            return nil
        }
        let regex = try? NSRegularExpression(pattern: "Maximum Capacity:\\s*(\\d+)%")
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex?.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output),
              let percent = Int(output[valueRange]) else {
            return nil
        }
        return percent
    }

    private static func shellOutput(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func formatDuration(minutes: Int) -> String? {
        guard minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
        return "\(mins) min"
    }

    static func menuBarSymbolName(percent: Int, charging: Bool) -> String {
        let bucket: Int
        switch percent {
        case ..<13: bucket = 0
        case ..<38: bucket = 25
        case ..<63: bucket = 50
        case ..<88: bucket = 75
        default: bucket = 100
        }
        return charging ? "battery.100.bolt" : "battery.\(bucket)"
    }

    private static func saneAmperage(_ raw: Int?) -> Int? {
        guard let raw, raw >= -30_000, raw <= 30_000 else { return nil }
        return raw
    }

    private static func saneVoltage(_ raw: Int?) -> Int? {
        guard let raw, raw > 0, raw <= 30_000 else { return nil }
        return raw
    }

    private static func healthCondition(smart: [String: Any]?, batteryData: [String: Any]?, battery: [String: Any]) -> String? {
        if let health = stringValue(smart, "BatteryHealth"), !health.isEmpty {
            return health
        }
        if let condition = stringValue(battery, "Health Condition"), !condition.isEmpty {
            return condition
        }
        guard let health = healthPercent(smart: smart, batteryData: batteryData) else { return nil }
        return health >= 80 ? "Normal" : "Service Recommended"
    }

    private static func readSmartBattery() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let keys = [
            "Amperage", "InstantAmperage", "Voltage", "Temperature", "IsCharging",
            "BatteryData", "AppleRawCurrentCapacity", "CurrentCapacity", "DesignCapacity",
            "AppleRawMaxCapacity", "MaxCapacity", "CycleCount", "BatteryHealth"
        ]
        var result: [String: Any] = [:]
        for key in keys {
            if let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) {
                result[key] = unmanaged.takeRetainedValue()
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func intValue(_ dict: [String: Any]?, _ key: String) -> Int? {
        guard let dict else { return nil }
        if let value = dict[key] as? Int { return value }
        if let value = dict[key] as? Int32 { return Int(value) }
        if let value = dict[key] as? NSNumber { return value.intValue }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int32 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func boolValue(_ dict: [String: Any]?, _ key: String) -> Bool? {
        guard let dict else { return nil }
        if let value = dict[key] as? Bool { return value }
        if let value = dict[key] as? NSNumber { return value.boolValue }
        return nil
    }

    private static func stringValue(_ dict: [String: Any]?, _ key: String) -> String? {
        dict?[key] as? String
    }

    private static func unknownToNil(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }
}
