import Foundation
import IOKit.ps

enum HardwareCapabilities {
    static let hasBattery: Bool = hasInternalBattery(descriptions: BatterySaver.currentDescriptions())

    static let hasGpuStatistics: Bool = GpuUsageService.snapshot().isAvailable

    static func hasInternalBattery(descriptions: [[String: Any]]) -> Bool {
        let typeKey = kIOPSTypeKey as String
        let internalType = kIOPSInternalBatteryType as String
        return descriptions.contains { ($0[typeKey] as? String) == internalType }
    }
}
