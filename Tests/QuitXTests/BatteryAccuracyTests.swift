import Foundation
import Testing
@testable import QuitX

@Suite("Battery accuracy")
struct BatteryAccuracyTests {
    private static let stateKey = "Power Source State"
    private static let currentCapKey = "Current Capacity"
    private static let timeToEmptyKey = "Time to Empty"
    private static let timeToFullKey = "Time to Full Charge"
    private static let chargingKey = "Is Charging"

    @Test("Battery percent matches pmset ground truth")
    func snapshotMatchesPmsetPercent() throws {
        let pmset = try shellOutput("pmset -g batt")
        guard !pmset.contains("No batteries") else {
            return
        }
        guard let pmsetPercent = percentFromPmset(pmset) else {
            return
        }
        guard let snapshot = BatteryDetailSampler.snapshot() else {
            return
        }
        #expect(abs(snapshot.percent - pmsetPercent) <= 2)
    }

    @Test("Power watts in sane range")
    func powerSanity() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        if let power = snapshot.powerW {
            #expect(power >= 0)
            #expect(power < 100)
        }
    }

    @Test("Temperature in sane range")
    func temperatureSanity() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        if let temp = snapshot.tempC {
            #expect(temp > 10)
            #expect(temp < 60)
        }
    }

    @Test("Cycle count is non-negative")
    func cycleCountNonNegative() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        if let cycles = snapshot.cycleCount {
            #expect(cycles >= 0)
        }
    }

    @Test("Missing descriptions returns nil")
    func missingDescriptionsReturnsNil() {
        #expect(BatteryDetailSampler.snapshot(descriptions: [], smartBattery: [:]) == nil)
    }

    @Test("Missing battery percentage returns nil")
    func missingPercentageReturnsNil() {
        let descriptions: [[String: Any]] = [
            ["Type": "InternalBattery", Self.stateKey: "Battery Power"]
        ]
        #expect(BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: [:]) == nil)
    }

    @Test("Injected battery snapshot decodes every field")
    func injectedBatterySnapshot() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 42,
                Self.timeToEmptyKey: 90,
                Self.timeToFullKey: -1,
                Self.chargingKey: false
            ]
        ]
        let smart: [String: Any] = [
            "Amperage": -1200,
            "Voltage": 12000,
            "Temperature": 3032,
            "CycleCount": 100,
            "BatteryHealth": "Normal",
            "IsCharging": false,
            "BatteryData": [
                "RemainingCapacity": 2500,
                "DesignCapacity": 5000,
                "FullChargeCapacity": 4800,
                "NominalChargeCapacity": 4800
            ]
        ]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: smart)
        #expect(snapshot?.percent == 42)
        #expect(snapshot?.isACPower == false)
        #expect(snapshot?.timeToEmptyMin == 90)
        #expect(snapshot?.timeToFullMin == nil)
        #expect(snapshot?.amperageMA == -1200)
        #expect(snapshot?.voltageMV == 12000)
        #expect(abs((snapshot?.powerW ?? 0) - 14.4) < 0.01)
        #expect(abs((snapshot?.tempC ?? 0) - 30.32) < 0.01)
        #expect(snapshot?.chargeMAh == 2500)
        #expect(snapshot?.designCapacityMAh == 5000)
        #expect(snapshot?.maxCapacityMAh == 4800)
        #expect(snapshot?.cycleCount == 100)
        #expect(snapshot?.condition == "Normal")
        #expect(snapshot?.healthPercent == 96)
        #expect(snapshot?.isCharging == false)
    }

    @Test("AC power injection flags isACPower")
    func acPowerInjection() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "AC Power",
                Self.currentCapKey: 100,
                Self.timeToFullKey: 45
            ]
        ]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: [:])
        #expect(snapshot?.isACPower == true)
        #expect(snapshot?.timeToFullMin == 45)
    }

    @Test("Duration format uses hours and minutes")
    func durationFormat() {
        #expect(BatteryDetailSampler.formatDuration(minutes: 83) == "1 hr 23 min")
        #expect(BatteryDetailSampler.formatDuration(minutes: 120) == "2 hr")
        #expect(BatteryDetailSampler.formatDuration(minutes: 45) == "45 min")
        #expect(BatteryDetailSampler.formatDuration(minutes: 0) == nil)
    }

    @Test("Health falls back to IOPS health condition")
    func healthFallbackIOPS() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 50,
                "Health Condition": "Service Recommended"
            ]
        ]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: [:])
        #expect(snapshot?.condition == "Service Recommended")
    }

    @Test("Health percent prefers BatteryData nominal over raw")
    func healthDerivedFromCapacity() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 50
            ]
        ]
        let weak: [String: Any] = [
            "BatteryData": ["NominalChargeCapacity": 3500, "DesignCapacity": 5000]
        ]
        let ok: [String: Any] = [
            "BatteryData": ["NominalChargeCapacity": 4800, "DesignCapacity": 5000]
        ]
        let degraded: [String: Any] = [
            "BatteryData": ["DesignCapacity": 4382],
            "AppleRawMaxCapacity": 4000
        ]
        #expect(
            BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: weak)?.healthPercent == 70
        )
        #expect(
            BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: ok)?.healthPercent == 96
        )
        #expect(
            BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: degraded)?.healthPercent == 91
        )
    }

    @Test("Percentage-scale top-level MaxCapacity is ignored for health")
    func percentScaleMaxCapacityIgnored() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 74
            ]
        ]
        let smart: [String: Any] = [
            "MaxCapacity": 100,
            "CurrentCapacity": 74,
            "BatteryData": ["DesignCapacity": 4382, "NominalChargeCapacity": 3610]
        ]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: smart)
        #expect(snapshot?.healthPercent == 82)
    }

    @Test("Health percent matches ioreg ground truth")
    func healthMatchesIoreg() throws {
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        let nominal = try intFromIoreg(ioreg, key: "NominalChargeCapacity")
        let fullCharge = try intFromIoreg(ioreg, key: "FullChargeCapacity")
        let design = try intFromIoreg(ioreg, key: "DesignCapacity")
        guard let design, design > 0 else { return }
        let current: Double
        if let nominal, let fullCharge, nominal > 0, fullCharge > 0 {
            current = Double(nominal + fullCharge) / 2
        } else if let nominal, nominal > 0 {
            current = Double(nominal)
        } else if let fullCharge, fullCharge > 0 {
            current = Double(fullCharge)
        } else {
            return
        }
        let smart: [String: Any] = [
            "BatteryData": [
                "DesignCapacity": design,
                "NominalChargeCapacity": nominal ?? 0,
                "FullChargeCapacity": fullCharge ?? 0
            ]
        ]
        let batteryData = smart["BatteryData"] as? [String: Any]
        let blend = try #require(BatteryDetailSampler.healthPercent(smart: smart, batteryData: batteryData))
        let expected = Int((current / Double(design) * 100).rounded())
        #expect(abs(blend - expected) <= 1)
    }

    @Test("Health percent blends FullCharge and Nominal like System Information")
    func healthBlendsForSystemInformationMatch() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 87
            ]
        ]
        let smart: [String: Any] = [
            "BatteryData": [
                "DesignCapacity": 4382,
                "NominalChargeCapacity": 3662,
                "FullChargeCapacity": 3532
            ]
        ]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: smart)
        #expect(snapshot?.healthPercent == 82)
    }

    @Test("Charge mAh matches ioreg RemainingCapacity")
    func chargeMatchesIoreg() throws {
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        guard let remaining = try intFromIoreg(ioreg, key: "RemainingCapacity"), remaining > 0 else {
            return
        }
        let snapshot = try #require(BatteryDetailSampler.snapshot())
        #expect(snapshot.chargeMAh == remaining)
    }

    @Test("Percent matches ioreg CurrentCapacity over MaxCapacity")
    func percentMatchesIoregCapacity() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        let current = try intFromIoreg(ioreg, key: "CurrentCapacity")
        let maxCap = try intFromIoreg(ioreg, key: "MaxCapacity")
        guard let current, let maxCap, maxCap > 0 else { return }
        let expected = Int((Double(current) / Double(maxCap) * 100).rounded())
        #expect(abs(snapshot.percent - expected) <= 2)
    }

    @Test("Amperage and voltage match ioreg")
    func amperageVoltageMatchIoreg() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        guard let amps = try intFromIoreg(ioreg, key: "Amperage"),
              let volts = try intFromIoreg(ioreg, key: "Voltage") else { return }
        let sampledAmps = try #require(snapshot.amperageMA)
        let sampledVolts = try #require(snapshot.voltageMV)
        #expect(abs(sampledAmps - amps) <= max(200, abs(amps) / 4))
        #expect(abs(sampledVolts - volts) <= 100)
    }

    @Test("Cycle count matches ioreg")
    func cycleCountMatchesIoreg() throws {
        guard let snapshot = BatteryDetailSampler.snapshot(), let cycles = snapshot.cycleCount else { return }
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        guard let expected = try intFromIoreg(ioreg, key: "CycleCount") else { return }
        #expect(cycles == expected)
    }

    @Test("Temperature matches ioreg centi-Celsius or the SMC battery sensors")
    func temperatureMatchesIoreg() throws {
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        if let centiC = try intFromIoreg(ioreg, key: "Temperature"), centiC > 0 {
            let temp = try #require(snapshot.tempC)
            #expect(abs(temp - Double(centiC) / 100.0) < 0.5)
        } else if let smc = SMCReader.batteryTemperature() {
            let temp = try #require(snapshot.tempC)
            #expect(abs(temp - smc) < 3)
        }
    }

    @Test("SMC values decode flt, sp78 and fpe2")
    func smcDecoding() {
        #expect(SMCReader.fourCharCode("TB0T") == 0x5442_3054)
        let floatBytes: [UInt8] = withUnsafeBytes(of: Float(41.5).bitPattern.littleEndian) { Array($0) }
        #expect(SMCReader.decode(type: "flt ", bytes: floatBytes) == 41.5)
        #expect(SMCReader.decode(type: "sp78", bytes: [0x1E, 0x80]) == 30.5)
        #expect(SMCReader.decode(type: "fpe2", bytes: [0x00, 0x08]) == 2)
        #expect(SMCReader.decode(type: "ui8 ", bytes: [1]) == nil)
        #expect(SMCReader.decode(type: "flt ", bytes: [1, 2]) == nil)
    }

    @Test("SMC battery temperature prefers TB0T and ignores bogus sensors")
    func smcBatteryTemperature() {
        #expect(SMCReader.batteryTemperature(from: [41, 35, 30]) == 41)
        #expect(SMCReader.batteryTemperature(from: [nil, 40, 30]) == 35)
        #expect(SMCReader.batteryTemperature(from: [0, -5, 300, nil]) == nil)
        #expect(SMCReader.batteryTemperature(from: [.nan, 36]) == 36)
        #expect(SMCReader.batteryTemperature(from: []) == nil)
    }

    @Test("IORegistry temperature keys are centi-Celsius with fallbacks")
    func ioregTemperatureKeys() {
        #expect(BatteryDetailSampler.temperature(smart: ["Temperature": 3047], batteryData: nil) == 30.47)
        #expect(BatteryDetailSampler.temperature(smart: ["VirtualTemperature": 3100], batteryData: nil) == 31)
        #expect(BatteryDetailSampler.temperature(smart: [:], batteryData: ["Temperature": 2950]) == 29.5)
        #expect(BatteryDetailSampler.temperature(smart: ["Temperature": 0], batteryData: nil) == nil)
        #expect(BatteryDetailSampler.temperature(smart: nil, batteryData: nil) == nil)
    }

    @Test("Live battery snapshot reports temperature when the SMC has a battery sensor")
    func liveTemperaturePresent() {
        guard HardwareCapabilities.hasBattery, SMCReader.batteryTemperature() != nil else { return }
        #expect(BatteryDetailSampler.snapshot()?.tempC != nil)
    }

    @Test("Power watts equals amperage times voltage over 1e6")
    func powerMatchesIoreg() throws {
        guard let snapshot = BatteryDetailSampler.snapshot(), let power = snapshot.powerW else { return }
        let ioreg = try shellOutput("ioreg -r -c AppleSmartBattery -d 1")
        guard let amps = try intFromIoreg(ioreg, key: "Amperage"),
              let volts = try intFromIoreg(ioreg, key: "Voltage") else { return }
        let expected = Double(abs(amps) * volts) / 1_000_000
        #expect(abs(power - expected) <= max(1, expected / 4))
    }

    @Test("Charging flag matches pmset")
    func chargingMatchesPmset() throws {
        let pmset = try shellOutput("pmset -g batt")
        guard pmset.contains("InternalBattery") else { return }
        guard let snapshot = BatteryDetailSampler.snapshot() else { return }
        if pmset.contains("discharging;") {
            #expect(!snapshot.isCharging)
        } else if pmset.contains("charging;") {
            #expect(snapshot.isCharging)
        }
    }

    @Test("Max Capacity row value within 1 of System Information Maximum Capacity")
    func maxCapacityMatchesSystemSettings() throws {
        let profiler = try shellOutput("system_profiler SPPowerDataType")
        let regex = try NSRegularExpression(pattern: "Maximum Capacity:\\s*(\\d+)%")
        let range = NSRange(profiler.startIndex..., in: profiler)
        guard let match = regex.firstMatch(in: profiler, range: range),
              let valueRange = Range(match.range(at: 1), in: profiler),
              let expected = Int(profiler[valueRange]) else { return }
        let snapshot = try #require(BatteryDetailSampler.snapshot())
        let delta = (snapshot.healthPercent ?? 0) - expected
        #expect(abs(delta) <= 1)
    }

    private func intFromIoreg(_ output: String, key: String) throws -> Int? {
        let pattern = "\"\(key)\"\\s*=\\s*(-?\\d+)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              let valueRange = Range(match.range(at: 1), in: output) else {
            return nil
        }
        let text = String(output[valueRange])
        if let value = Int(text) { return value }
        return UInt64(text).map { Int(bitPattern: UInt($0)) }
    }

    @Test("Charging limit parses System Settings domain")
    func chargingLimitParsing() {
        let domain = ["com.apple.batteryui.charging.mac.prior.limit": 90]
        #expect(BatteryDetailSampler.readChargingLimit(persistentDomain: domain) == 90)
        #expect(BatteryDetailSampler.readChargingLimit(persistentDomain: [:]) == nil)
        #expect(
            BatteryDetailSampler.readChargingLimit(
                persistentDomain: ["com.apple.batteryui.charging.mac.prior.limit": 120]
            ) == nil
        )
    }

    @Test("Charging limit matches System Settings defaults domain")
    func chargingLimitMatchesDefaults() throws {
        let raw = try shellOutput("defaults read com.apple.batteryui.charging.mac")
        guard let range = raw.range(of: "prior.limit\" = (\\d+)", options: .regularExpression) else {
            return
        }
        let digits = raw[range].filter(\.isNumber)
        guard let expected = Int(digits) else { return }
        let snapshot = try #require(BatteryDetailSampler.snapshot())
        #expect(snapshot.chargingLimitPercent == expected)
    }

    @Test("Injected snapshot passes charging limit through")
    func injectedChargingLimit() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 50
            ]
        ]
        let snapshot = BatteryDetailSampler.snapshot(
            descriptions: descriptions,
            smartBattery: ["BatteryData": ["DesignCapacity": 4382, "NominalChargeCapacity": 3610]],
            chargingLimitPercent: 80
        )
        #expect(snapshot?.chargingLimitPercent == 80)
        #expect(snapshot?.healthPercent == 82)
    }

    @Test("Garbage amperage sentinels are dropped")
    func garbageAmperageDropped() {
        let descriptions: [[String: Any]] = [
            [
                "Type": "InternalBattery",
                Self.stateKey: "Battery Power",
                Self.currentCapKey: 50
            ]
        ]
        let garbage: [String: Any] = ["Amperage": Int32.min, "Voltage": 12000]
        let snapshot = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: garbage)
        #expect(snapshot?.amperageMA == nil)
        #expect(snapshot?.powerW == nil)
        let sane: [String: Any] = ["Amperage": -1234, "Voltage": 12000]
        let ok = BatteryDetailSampler.snapshot(descriptions: descriptions, smartBattery: sane)
        #expect(ok?.amperageMA == -1234)
        #expect(abs((ok?.powerW ?? 0) - 14.808) < 0.001)

        let minimum = BatteryDetailSampler.snapshot(
            descriptions: descriptions,
            smartBattery: ["Amperage": Int.min, "Voltage": 12000]
        )
        #expect(minimum?.amperageMA == nil)
        #expect(minimum?.powerW == nil)

        let invalidVoltage = BatteryDetailSampler.snapshot(
            descriptions: descriptions,
            smartBattery: ["Amperage": -1234, "Voltage": Int.max]
        )
        #expect(invalidVoltage?.voltageMV == nil)
        #expect(invalidVoltage?.powerW == nil)
    }

    @Test("Menu bar symbol buckets follow system icon levels")
    func menuBarSymbolBuckets() {
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 0, charging: false) == "battery.0")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 10, charging: false) == "battery.0")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 25, charging: false) == "battery.25")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 50, charging: false) == "battery.50")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 75, charging: false) == "battery.75")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 100, charging: false) == "battery.100")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 80, charging: true) == "battery.100.bolt")
        #expect(BatteryDetailSampler.menuBarSymbolName(percent: 100, charging: true) == "battery.100.bolt")
    }

    private func percentFromPmset(_ output: String) -> Int? {
        for line in output.split(separator: "\n") where line.contains("%") {
            let before = line.split(separator: "%", maxSplits: 1).first ?? ""
            let digits = before.reversed().prefix(while: \.isNumber)
            if let value = Int(String(digits.reversed())) {
                return value
            }
        }
        return nil
    }

    private func shellOutput(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
