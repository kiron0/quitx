import Foundation
import IOKit
import os

enum GpuUsageService {
    struct Snapshot: Sendable, Equatable {
        var deviceUtilization: Double = 0
        var rendererUtilization: Double = 0
        var tilerUtilization: Double = 0
        var memoryUsedBytes: UInt64 = 0
        var allocatedBytes: UInt64 = 0
        var coreCount: Int = 0
        var deviceName: String = ""
        var isAvailable: Bool = false

        var memoryUsedFormatted: String {
            MemoryFormatter.format(bytes: memoryUsedBytes)
        }

        var allocatedFormatted: String {
            MemoryFormatter.format(bytes: allocatedBytes)
        }
    }

    private static let minInterval: TimeInterval = 0.9
    private static let cache = OSAllocatedUnfairLock(initialState: (snapshot: Snapshot(), at: Date.distantPast))

    static func snapshot() -> Snapshot {
        let now = Date()
        if let cached = cache.withLock({ state -> Snapshot? in
            guard now.timeIntervalSince(state.at) < minInterval else { return nil }
            return state.snapshot
        }) {
            return cached
        }
        let fresh = readSnapshot()
        cache.withLock { $0 = (fresh, now) }
        return fresh
    }

    private static func readSnapshot() -> Snapshot {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator") else { return Snapshot() }
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return Snapshot() }
        defer { IOObjectRelease(iterator) }

        var result = Snapshot()
        var deviceCount = 0

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            guard let stats = propertyDictionary(service, key: "PerformanceStatistics") else { continue }
            deviceCount += 1

            let device = percent(stats, "Device Utilization %")
            let renderer = percent(stats, "Renderer Utilization %")
            result.deviceUtilization = max(result.deviceUtilization, device)
            result.rendererUtilization = max(result.rendererUtilization, renderer)
            result.tilerUtilization = max(result.tilerUtilization, percent(stats, "Tiler Utilization %"))
            result.memoryUsedBytes += byteCount(stats, "In use system memory")
            result.allocatedBytes += byteCount(stats, "Alloc system memory")

            if result.coreCount == 0 {
                result.coreCount = intProperty(service, key: "gpu-core-count")
                    ?? intProperty(service, key: "gpu_core_count")
                    ?? 0
            }
            if result.deviceName.isEmpty,
               let model = stringProperty(service, key: "model"), !model.isEmpty {
                result.deviceName = model
            }
        }

        if result.deviceUtilization == 0, result.rendererUtilization > 0 {
            result.deviceUtilization = result.rendererUtilization
        }
        result.isAvailable = deviceCount > 0
        return result
    }

    private static func propertyDictionary(_ service: io_service_t, key: String) -> [String: Any]? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, nil, 0) else { return nil }
        let value = unmanaged.takeRetainedValue()
        return value as? [String: Any]
    }

    private static func stringProperty(_ service: io_service_t, key: String) -> String? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, nil, 0) else { return nil }
        let value = unmanaged.takeRetainedValue()
        return value as? String
    }

    private static func intProperty(_ service: io_service_t, key: String) -> Int? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, nil, 0) else { return nil }
        let value = unmanaged.takeRetainedValue()
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String {
            return Int(text)
        }
        return nil
    }

    private static func percent(_ stats: [String: Any], _ key: String) -> Double {
        guard let number = stats[key] as? NSNumber else { return 0 }
        let raw = number.doubleValue
        guard raw.isFinite else { return 0 }
        return min(100, max(0, raw))
    }

    private static func byteCount(_ stats: [String: Any], _ key: String) -> UInt64 {
        guard let number = stats[key] as? NSNumber else { return 0 }
        let raw = number.int64Value
        guard raw > 0 else { return 0 }
        return UInt64(raw)
    }
}
