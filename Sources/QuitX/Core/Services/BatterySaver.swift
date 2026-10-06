import Foundation
import IOKit.ps

/// Battery saver state and behavior.
///
/// Active when the user enabled it and the machine runs on battery.
/// While active, auto-quit timeouts are halved and the live menu-bar
/// refresh slows down. Both effects are documented in Help.
enum BatterySaver {
    /// Parses power-source descriptions (as returned by
    /// `IOPSGetPowerSourceDescription`) into an on-battery verdict.
    /// Pure for testing: pass dictionaries shaped like
    /// `[kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue]`.
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

    /// Halves a timeout while the saver is active, keeping a 1-minute floor.
    static func effectiveTimeout(minutes: Int, saverActive: Bool) -> Int {
        guard saverActive, minutes > 0 else { return minutes }
        return max(1, minutes / 2)
    }

    /// Menu-bar readout text for total CPU, or `nil` when hidden.
    static func menuBarText(totalCPU: Double, enabled: Bool) -> String? {
        guard enabled else { return nil }
        return String(format: "%.0f%%", totalCPU)
    }
}
