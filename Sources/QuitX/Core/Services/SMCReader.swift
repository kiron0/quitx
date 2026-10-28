import Foundation
import IOKit

enum SMCReader {
    private typealias Bytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct KeyData {
        var key: UInt32 = 0
        var version = Version()
        var limitData = LimitData()
        var keyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    private static let handleEvent: UInt32 = 2
    private static let readKey: UInt8 = 5
    private static let readKeyInfo: UInt8 = 9
    static let batteryTemperatureKeys = ["TB0T", "TB1T", "TB2T", "TB3T"]

    static func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func decode(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            var bits: UInt32 = 0
            for (offset, byte) in bytes.prefix(4).enumerated() {
                bits |= UInt32(byte) << UInt32(offset * 8)
            }
            return Double(Float(bitPattern: bits))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw: UInt16 = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            let raw: UInt16 = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4
        default:
            return nil
        }
    }

    static func batteryTemperature(from readings: [Double?]) -> Double? {
        func sane(_ value: Double?) -> Double? {
            guard let value, value.isFinite, value > 0, value < 100 else { return nil }
            return value
        }
        if let primary = sane(readings.first ?? nil) { return primary }
        let others = readings.dropFirst().compactMap(sane)
        guard !others.isEmpty else { return nil }
        return others.reduce(0, +) / Double(others.count)
    }

    static func batteryTemperature() -> Double? {
        let values = values(forKeys: batteryTemperatureKeys)
        return batteryTemperature(from: batteryTemperatureKeys.map { values[$0] })
    }

    static func values(forKeys keys: [String]) -> [String: Double] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return [:] }
        defer { IOServiceClose(connection) }
        var result: [String: Double] = [:]
        for key in keys {
            if let value = read(key, connection: connection) { result[key] = value }
        }
        return result
    }

    private static func call(_ input: inout KeyData, connection: io_connect_t) -> KeyData? {
        var output = KeyData()
        var outputSize = MemoryLayout<KeyData>.stride
        let status = IOConnectCallStructMethod(
            connection,
            handleEvent,
            &input,
            MemoryLayout<KeyData>.stride,
            &output,
            &outputSize
        )
        guard status == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    private static func read(_ key: String, connection: io_connect_t) -> Double? {
        var input = KeyData()
        input.key = fourCharCode(key)
        input.data8 = readKeyInfo
        guard let info = call(&input, connection: connection), info.keyInfo.dataSize > 0 else { return nil }
        input.keyInfo.dataSize = info.keyInfo.dataSize
        input.data8 = readKey
        guard let value = call(&input, connection: connection) else { return nil }
        let size = min(Int(info.keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: value.bytes) { Array($0.prefix(size)) }
        let typeCode = info.keyInfo.dataType
        let type = String(bytes: [24, 16, 8, 0].map { UInt8((typeCode >> $0) & 0xFF) }, encoding: .ascii) ?? ""
        return decode(type: type, bytes: bytes)
    }
}
