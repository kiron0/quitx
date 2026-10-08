import Foundation
import IOKit

enum CPUFrequencySampler {
    private typealias FnCopyChannels = @convention(c) (CFString?, CFString?, UInt64, UInt64, UInt64) -> Unmanaged<CFMutableDictionary>?
    private typealias FnSubscribe = @convention(c) (UnsafeRawPointer?, CFMutableDictionary?, UnsafeMutablePointer<CFMutableDictionary?>?, UInt64, CFTypeRef?) -> UnsafeMutableRawPointer?
    private typealias FnSamples = @convention(c) (UnsafeMutableRawPointer?, CFMutableDictionary?, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias FnDelta = @convention(c) (CFDictionary?, CFDictionary?, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias FnStateCount = @convention(c) (CFDictionary?, Int32) -> Int32
    private typealias FnResidency = @convention(c) (CFDictionary?, Int32) -> UInt64
    private typealias FnStateName = @convention(c) (CFDictionary?, Int32) -> Unmanaged<CFString>?

    private static var prepared = false
    private static var subscription: UnsafeMutableRawPointer?
    private static var subbedChannels: CFMutableDictionary?
    private static var previousSample: CFDictionary?
    private static var efficiencyTable: [Double] = [0]
    private static var performanceTable: [Double] = [0]
    private static var createSamplesFn: FnSamples?
    private static var createDeltaFn: FnDelta?
    private static var stateCountFn: FnStateCount?
    private static var residencyFn: FnResidency?
    private static var stateNameFn: FnStateName?

    static func prepare() -> Bool {
        if prepared { return true }
        guard let handle = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW) else { return false }
        guard
            let copyChannels = symbol(handle, "IOReportCopyChannelsInGroup", FnCopyChannels.self),
            let subscribe = symbol(handle, "IOReportCreateSubscription", FnSubscribe.self),
            let samples = symbol(handle, "IOReportCreateSamples", FnSamples.self),
            let delta = symbol(handle, "IOReportCreateSamplesDelta", FnDelta.self),
            let count = symbol(handle, "IOReportStateGetCount", FnStateCount.self),
            let residency = symbol(handle, "IOReportStateGetResidency", FnResidency.self),
            let name = symbol(handle, "IOReportStateGetNameForIndex", FnStateName.self)
        else { return false }
        guard let channelsUnmanaged = copyChannels("CPU Stats" as CFString, nil, 0, 0, 0) else { return false }
        let channels = channelsUnmanaged.takeRetainedValue()
        var subbed: CFMutableDictionary?
        guard let sub = subscribe(nil, channels, &subbed, 0, nil), let subbed else { return false }
        createSamplesFn = samples
        createDeltaFn = delta
        stateCountFn = count
        residencyFn = residency
        stateNameFn = name
        subscription = sub
        subbedChannels = subbed
        efficiencyTable = dvfsTable(property: "voltage-states1-sram")
        performanceTable = dvfsTable(property: "voltage-states5-sram")
        prepared = true
        return true
    }

    static func poll() -> (efficiencyMHz: Int, performanceMHz: Int)? {
        guard prepared, let createSamplesFn, let createDeltaFn else { return nil }
        guard let current = createSamplesFn(subscription, subbedChannels, nil)?.takeRetainedValue() else { return nil }
        guard let previous = previousSample else {
            previousSample = current
            return nil
        }
        previousSample = current
        guard let delta = createDeltaFn(previous, current, nil)?.takeRetainedValue() else { return nil }
        return compute(delta)
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String, _: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func dvfsTable(property: String) -> [Double] {
        var table: [Double] = [0]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleARMIODevice"), &iterator) == KERN_SUCCESS else {
            return table
        }
        defer { IOObjectRelease(iterator) }
        while true {
            let entry = IOIteratorNext(iterator)
            if entry == 0 { break }
            defer { IOObjectRelease(entry) }
            guard let unmanaged = IORegistryEntryCreateCFProperty(entry, property as CFString, kCFAllocatorDefault, 0),
                  let data = unmanaged.takeRetainedValue() as? Data else { continue }
            let bytes = [UInt8](data)
            var index = 0
            while index + 8 <= bytes.count {
                let frequency = UInt32(bytes[index])
                    | UInt32(bytes[index + 1]) << 8
                    | UInt32(bytes[index + 2]) << 16
                    | UInt32(bytes[index + 3]) << 24
                let mhz = UInt32(Double(frequency) * 1e-6)
                if mhz != 0 { table.append(Double(mhz)) }
                index += 8
            }
            break
        }
        return table
    }

    private static func compute(_ delta: CFDictionary) -> (efficiencyMHz: Int, performanceMHz: Int)? {
        guard let stateCountFn, let residencyFn, let stateNameFn else { return nil }
        guard let channelArray: CFArray = dictionaryValue(delta, key: "IOReportChannels") else { return nil }
        let channelCount = CFArrayGetCount(channelArray)
        var efficiencyProduct = 0.0
        var efficiencyActive: UInt64 = 0
        var performanceProduct = 0.0
        var performanceActive: UInt64 = 0
        for index in 0..<channelCount {
            guard let raw = CFArrayGetValueAtIndex(channelArray, index) else { continue }
            let channel = Unmanaged<CFDictionary>.fromOpaque(raw).takeUnretainedValue()
            guard dictionaryString(channel, key: "IOReportSubGroupName") == "CPU Complex Performance States" else { continue }
            guard let channelName = legendName(channel), !channelName.contains("CPM") else { continue }
            let isEfficiency = channelName.contains("E")
            let table = isEfficiency ? efficiencyTable : performanceTable
            let states = Int(stateCountFn(channel, 0))
            guard states > 1 else { continue }
            let upperBound = min(states, table.count)
            for state in 1..<upperBound {
                guard let stateLabelCF = stateNameFn(channel, Int32(state)) else { continue }
                let stateLabel = stateLabelCF.takeUnretainedValue() as String
                guard stateLabel.contains("P") || stateLabel.contains("V") else { continue }
                let ticks = residencyFn(channel, Int32(state))
                guard ticks > 0 else { continue }
                if isEfficiency {
                    efficiencyActive += ticks
                    efficiencyProduct += Double(ticks) * table[state]
                } else {
                    performanceActive += ticks
                    performanceProduct += Double(ticks) * table[state]
                }
            }
        }
        let efficiency = efficiencyActive > 0 ? Int((efficiencyProduct / Double(efficiencyActive)).rounded()) : 0
        let performance = performanceActive > 0 ? Int((performanceProduct / Double(performanceActive)).rounded()) : 0
        return (efficiency, performance)
    }

    private static func dictionaryValue<T: AnyObject>(_ dictionary: CFDictionary, key: String) -> T? {
        let keyString = key as CFString
        guard let raw = CFDictionaryGetValue(dictionary, Unmanaged.passUnretained(keyString).toOpaque()) else { return nil }
        return Unmanaged<T>.fromOpaque(raw).takeUnretainedValue()
    }

    private static func dictionaryString(_ dictionary: CFDictionary, key: String) -> String? {
        guard let value: CFString = dictionaryValue(dictionary, key: key) else { return nil }
        return value as String
    }

    private static func legendName(_ channel: CFDictionary) -> String? {
        guard let legend: CFArray = dictionaryValue(channel, key: "LegendChannel"), CFArrayGetCount(legend) > 2 else { return nil }
        guard let raw = CFArrayGetValueAtIndex(legend, 2) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
