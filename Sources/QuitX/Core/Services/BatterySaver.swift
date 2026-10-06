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

    static func menuBarText(totalCPU: Double, enabled: Bool) -> String? {
        guard enabled else { return nil }
        return String(format: "%.0f%%", totalCPU)
    }
}
