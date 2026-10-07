import Foundation
import IOKit.ps

enum BatterySaver {

    static func isOnBattery(descriptions: [[String: Any]]) -> Bool {
        let batteryValue = kIOPSBatteryPowerValue as String
        let stateKey = kIOPSPowerSourceStateKey as String
        return descriptions.contains { ($0[stateKey] as? String) == batteryValue }
    }

    static func currentDescriptions() -> [[String: Any]] {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return [] }
        return list.compactMap {
            IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any]
        }
    }

    static func isSaverActive(config: QuitXConfig, descriptions: [[String: Any]]) -> Bool {
        config.batterySaverEnabled && isOnBattery(descriptions: descriptions)
    }

    static func isSaverActive(config: QuitXConfig) -> Bool {
        isSaverActive(config: config, descriptions: currentDescriptions())
    }

    static func effectiveTimeout(minutes: Int, saverActive: Bool) -> Int {
        guard saverActive, minutes > 0 else { return minutes }
        return max(1, minutes / 2)
    }

    static func percentText(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func memoryPercentText(bytes: UInt64, totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) -> String {
        guard totalBytes > 0 else { return "0%" }
        let pct = (Double(bytes) / Double(totalBytes)) * 100.0
        return percentText(pct)
    }

    static func compactMemoryText(bytes: UInt64, unit: QuitXConfig.MenuBarMemoryUnit = .gb, totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) -> String {
        switch unit {
        case .gb:
            let gb = Double(bytes) / 1_073_741_824
            if gb >= 1 {
                return String(format: "%.1fG", gb)
            }
            return String(format: "%.0fM", Double(bytes) / 1_048_576)
        case .percentage:
            return memoryPercentText(bytes: bytes, totalBytes: totalBytes)
        }
    }

    static func menuBarText(
        cpu: Double,
        memoryUsedBytes: UInt64,
        enabled: Bool,
        unit: QuitXConfig.MenuBarMemoryUnit = .gb,
        totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> String? {
        guard enabled else { return nil }
        let memStr: String
        switch unit {
        case .gb:
            memStr = MemoryFormatter.format(bytes: memoryUsedBytes)
        case .percentage:
            memStr = memoryPercentText(bytes: memoryUsedBytes, totalBytes: totalBytes)
        }
        return "CPU \(percentText(cpu)) · Memory \(memStr)"
    }
}
