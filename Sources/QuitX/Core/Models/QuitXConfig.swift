import Foundation

struct QuitXConfig: Codable, Equatable, Sendable {
    var exclude: [String]
    var force: ForceMode
    var includeFinder: Bool
    var includeTrash: Bool
    var includeBackground: Bool
    var groupBackground: Bool
    var defaultSelectAll: Bool
    var neverQuitMusic: Bool
    var musicApps: [String]
    var autoUpdate: Bool
    var autoInstallUpdates: Bool = false
    var confirmQuitAll: Bool = true
    var confirmIndividualAction: Bool = false
    var playSounds: Bool = true
    var quitInactiveAfterMinutes: Int = 0
    var disableQuitTips: Bool = false
    var sortBy: SortBy = .name
    var perAppQuitRules: [String: Int] = [:]
    var quitOnSleep: Bool = false
    var quitOnScreenLock: Bool = false
    var quitWhenLastWindowClosed: Bool = false
    var sleepLockStartMinutes: Int = 0
    var sleepLockEndMinutes: Int = 360
    var sleepLockUse24Hour: Bool = true
    var showMenuBarStats: Bool = false
    var menuBarShowCpu: Bool = false
    var menuBarShowMemory: Bool = false
    var menuBarShowGpu: Bool = false
    var batteryMenuBarEnabled: Bool = false
    var menuBarStatStyle: MenuBarStatStyle = .icon
    var menuBarMemoryUnit: MenuBarMemoryUnit = .gb
    var hogAlertEnabled: Bool = false
    var hogCpuThreshold: Double = 80
    var memoryPressureQuitEnabled: Bool = false
    var memoryPressureThresholdMB: Int = 1024
    var batterySaverEnabled: Bool = false
    var quitTimers: [String: Double] = [:]
    var liquidGlassEnabled: Bool = true
    var portsEnabled: Bool = false
    var portsExcluded: [Int] = []
    var portsForceKill: Bool = false
    var portsConfirmKill: Bool = true
    var portsSelectAllByDefault: Bool = false
    var portsSortBy: PortSortBy = .portAsc
    var portsDockerStopTimeout: Int = 5
    var portsIncludeUDP: Bool = false
    var portsGrouping: ListenerGrouping = .none
    var portsShowMenuBarCount: Bool = false
    var portsRefreshSeconds: Int = 3

    static let portRefreshChoices: [Int] = [2, 3, 5, 10]

    private enum CodingKeys: String, CodingKey {
        case exclude, force, includeFinder, includeTrash, includeBackground, groupBackground
        case defaultSelectAll, neverQuitMusic, musicApps, autoUpdate, autoInstallUpdates, confirmQuitAll, confirmIndividualAction, playSounds
        case quitInactiveAfterMinutes, disableQuitTips, sortBy, perAppQuitRules
        case quitOnSleep, quitOnScreenLock, showMenuBarStats, menuBarShowCpu, menuBarShowMemory, menuBarShowGpu, batteryMenuBarEnabled, menuBarStatStyle, menuBarMemoryUnit
        case quitWhenLastWindowClosed
        case sleepLockStartMinutes, sleepLockEndMinutes, sleepLockUse24Hour
        case hogAlertEnabled, hogCpuThreshold
        case memoryPressureQuitEnabled, memoryPressureThresholdMB, batterySaverEnabled
        case quitTimers, liquidGlassEnabled
        case portsEnabled, portsExcluded, portsForceKill, portsConfirmKill, portsSelectAllByDefault, portsSortBy
        case portsDockerStopTimeout, portsIncludeUDP, portsGrouping
        case portsShowMenuBarCount, portsRefreshSeconds
    }

    init(
        exclude: [String],
        force: ForceMode,
        includeFinder: Bool,
        includeTrash: Bool,
        includeBackground: Bool,
        groupBackground: Bool,
        defaultSelectAll: Bool,
        neverQuitMusic: Bool,
        musicApps: [String],
        autoUpdate: Bool,
        autoInstallUpdates: Bool = false,
        confirmQuitAll: Bool = true,
        confirmIndividualAction: Bool = false,
        playSounds: Bool = true,
        quitInactiveAfterMinutes: Int = 0,
        disableQuitTips: Bool = false,
        sortBy: SortBy = .name,
        perAppQuitRules: [String: Int] = [:],
        quitOnSleep: Bool = false,
        quitOnScreenLock: Bool = false,
        quitWhenLastWindowClosed: Bool = false,
        sleepLockStartMinutes: Int = 0,
        sleepLockEndMinutes: Int = 360,
        sleepLockUse24Hour: Bool = true,
        showMenuBarStats: Bool = false,
        menuBarShowCpu: Bool = false,
        menuBarShowMemory: Bool = false,
        menuBarShowGpu: Bool = false,
        batteryMenuBarEnabled: Bool = false,
        menuBarStatStyle: MenuBarStatStyle = .icon,
        menuBarMemoryUnit: MenuBarMemoryUnit = .gb,
        hogAlertEnabled: Bool = false,
        hogCpuThreshold: Double = 80,
        memoryPressureQuitEnabled: Bool = false,
        memoryPressureThresholdMB: Int = 1024,
        batterySaverEnabled: Bool = false,
        quitTimers: [String: Double] = [:],
        liquidGlassEnabled: Bool = true
    ) {
        self.exclude = exclude
        self.force = force
        self.includeFinder = includeFinder
        self.includeTrash = includeTrash
        self.includeBackground = includeBackground
        self.groupBackground = groupBackground
        self.defaultSelectAll = defaultSelectAll
        self.neverQuitMusic = neverQuitMusic
        self.musicApps = musicApps
        self.autoUpdate = autoUpdate
        self.autoInstallUpdates = autoInstallUpdates
        self.confirmQuitAll = confirmQuitAll
        self.confirmIndividualAction = confirmIndividualAction
        self.playSounds = playSounds
        self.quitInactiveAfterMinutes = quitInactiveAfterMinutes
        self.disableQuitTips = disableQuitTips
        self.sortBy = sortBy
        self.perAppQuitRules = perAppQuitRules
        self.quitOnSleep = quitOnSleep
        self.quitOnScreenLock = quitOnScreenLock
        self.quitWhenLastWindowClosed = quitWhenLastWindowClosed
        self.sleepLockStartMinutes = min(1439, max(0, sleepLockStartMinutes))
        self.sleepLockEndMinutes = min(1439, max(0, sleepLockEndMinutes))
        self.sleepLockUse24Hour = sleepLockUse24Hour
        self.showMenuBarStats = showMenuBarStats
        self.menuBarShowCpu = menuBarShowCpu
        self.menuBarShowMemory = menuBarShowMemory
        self.menuBarShowGpu = menuBarShowGpu
        self.batteryMenuBarEnabled = batteryMenuBarEnabled
        self.menuBarStatStyle = menuBarStatStyle
        self.menuBarMemoryUnit = menuBarMemoryUnit
        self.hogAlertEnabled = hogAlertEnabled
        self.hogCpuThreshold = hogCpuThreshold
        self.memoryPressureQuitEnabled = memoryPressureQuitEnabled
        self.memoryPressureThresholdMB = memoryPressureThresholdMB
        self.batterySaverEnabled = batterySaverEnabled
        self.quitTimers = quitTimers
        self.liquidGlassEnabled = liquidGlassEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        exclude = Self.dec(container, .exclude, defaults.exclude)
        force = Self.dec(container, .force, defaults.force)
        includeFinder = Self.dec(container, .includeFinder, defaults.includeFinder)
        includeTrash = Self.dec(container, .includeTrash, defaults.includeTrash)
        includeBackground = Self.dec(container, .includeBackground, defaults.includeBackground)
        groupBackground = Self.dec(container, .groupBackground, defaults.groupBackground)
        defaultSelectAll = Self.dec(container, .defaultSelectAll, defaults.defaultSelectAll)
        neverQuitMusic = Self.dec(container, .neverQuitMusic, defaults.neverQuitMusic)
        musicApps = Self.dec(container, .musicApps, defaults.musicApps)
        autoUpdate = Self.dec(container, .autoUpdate, defaults.autoUpdate)
        autoInstallUpdates = Self.dec(container, .autoInstallUpdates, defaults.autoInstallUpdates)
        confirmQuitAll = Self.dec(container, .confirmQuitAll, defaults.confirmQuitAll)
        confirmIndividualAction = Self.dec(container, .confirmIndividualAction, defaults.confirmIndividualAction)
        playSounds = Self.dec(container, .playSounds, defaults.playSounds)
        quitInactiveAfterMinutes = Self.dec(container, .quitInactiveAfterMinutes, defaults.quitInactiveAfterMinutes)
        disableQuitTips = Self.dec(container, .disableQuitTips, defaults.disableQuitTips)
        sortBy = Self.dec(container, .sortBy, defaults.sortBy)
        perAppQuitRules = Self.decIntMap(container, .perAppQuitRules, defaults.perAppQuitRules)
        quitOnSleep = Self.dec(container, .quitOnSleep, defaults.quitOnSleep)
        quitOnScreenLock = Self.dec(container, .quitOnScreenLock, defaults.quitOnScreenLock)
        quitWhenLastWindowClosed = Self.dec(container, .quitWhenLastWindowClosed, defaults.quitWhenLastWindowClosed)
        sleepLockStartMinutes = min(1439, max(0, Self.dec(container, .sleepLockStartMinutes, defaults.sleepLockStartMinutes)))
        sleepLockEndMinutes = min(1439, max(0, Self.dec(container, .sleepLockEndMinutes, defaults.sleepLockEndMinutes)))
        sleepLockUse24Hour = Self.dec(container, .sleepLockUse24Hour, defaults.sleepLockUse24Hour)
        showMenuBarStats = Self.dec(container, .showMenuBarStats, defaults.showMenuBarStats)
        menuBarShowCpu = (try? container.decodeIfPresent(Bool.self, forKey: .menuBarShowCpu)) ?? showMenuBarStats
        menuBarShowMemory = (try? container.decodeIfPresent(Bool.self, forKey: .menuBarShowMemory)) ?? showMenuBarStats
        menuBarShowGpu = (try? container.decodeIfPresent(Bool.self, forKey: .menuBarShowGpu)) ?? showMenuBarStats
        batteryMenuBarEnabled = Self.dec(container, .batteryMenuBarEnabled, defaults.batteryMenuBarEnabled)
        menuBarStatStyle = Self.dec(container, .menuBarStatStyle, defaults.menuBarStatStyle)
        menuBarMemoryUnit = Self.dec(container, .menuBarMemoryUnit, defaults.menuBarMemoryUnit)
        hogAlertEnabled = Self.dec(container, .hogAlertEnabled, defaults.hogAlertEnabled)
        hogCpuThreshold = Self.dec(container, .hogCpuThreshold, defaults.hogCpuThreshold)
        memoryPressureQuitEnabled = Self.dec(container, .memoryPressureQuitEnabled, defaults.memoryPressureQuitEnabled)
        memoryPressureThresholdMB = Self.dec(container, .memoryPressureThresholdMB, defaults.memoryPressureThresholdMB)
        batterySaverEnabled = Self.dec(container, .batterySaverEnabled, defaults.batterySaverEnabled)
        quitTimers = Self.decDoubleMap(container, .quitTimers, defaults.quitTimers)
        liquidGlassEnabled = Self.dec(container, .liquidGlassEnabled, defaults.liquidGlassEnabled)
        portsEnabled = Self.dec(container, .portsEnabled, defaults.portsEnabled)
        portsExcluded = Self.validPorts(Self.dec(container, .portsExcluded, defaults.portsExcluded))
        portsForceKill = Self.dec(container, .portsForceKill, defaults.portsForceKill)
        portsConfirmKill = Self.dec(container, .portsConfirmKill, defaults.portsConfirmKill)
        portsSelectAllByDefault = Self.dec(container, .portsSelectAllByDefault, defaults.portsSelectAllByDefault)
        portsSortBy = Self.dec(container, .portsSortBy, defaults.portsSortBy)
        portsDockerStopTimeout = min(max(Self.dec(container, .portsDockerStopTimeout, defaults.portsDockerStopTimeout), 1), 60)
        portsIncludeUDP = Self.dec(container, .portsIncludeUDP, defaults.portsIncludeUDP)
        portsGrouping = Self.dec(container, .portsGrouping, defaults.portsGrouping)
        portsShowMenuBarCount = Self.dec(container, .portsShowMenuBarCount, defaults.portsShowMenuBarCount)
        portsRefreshSeconds = min(max(Self.dec(container, .portsRefreshSeconds, defaults.portsRefreshSeconds), 1), 60)
    }

    static func validPorts(_ ports: [Int]) -> [Int] {
        Array(Set(ports.filter { (1...65535).contains($0) })).sorted()
    }

    private static func dec<T: Decodable>(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, _ fallback: T) -> T {
        ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    private static func decIntMap(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, _ fallback: [String: Int]) -> [String: Int] {
        guard let raw = try? container.decodeIfPresent([String: LossyInt].self, forKey: key) else { return fallback }
        var result: [String: Int] = [:]
        for (identifier, value) in raw {
            if let resolved = value.value {
                result[identifier] = resolved
            } else {
                NSLog("QuitX: dropping malformed config entry %@.%@", key.stringValue, identifier)
            }
        }
        return result
    }

    private static func decDoubleMap(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, _ fallback: [String: Double]) -> [String: Double] {
        guard let raw = try? container.decodeIfPresent([String: LossyDouble].self, forKey: key) else { return fallback }
        var result: [String: Double] = [:]
        for (identifier, value) in raw {
            if let resolved = value.value {
                result[identifier] = resolved
            } else {
                NSLog("QuitX: dropping malformed config entry %@.%@", key.stringValue, identifier)
            }
        }
        return result
    }

    private struct LossyInt: Decodable {
        let value: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                if double.isFinite, double >= -9.223_372_036_854_775e18, double <= 9.223_372_036_854_775e18 {
                    value = Int(double)
                } else {
                    value = nil
                }
            } else {
                value = nil
            }
        }
    }

    private struct LossyDouble: Decodable {
        let value: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let double = try? container.decode(Double.self) {
                value = double.isFinite ? double : nil
            } else if let int = try? container.decode(Int.self) {
                value = Double(int)
            } else {
                value = nil
            }
        }
    }

    var effectiveHogCpuThreshold: Double {
        max(80, min(100, hogCpuThreshold))
    }

    var menuBarStatsEnabled: Bool {
        showMenuBarStats && (menuBarShowCpu || menuBarShowMemory || menuBarShowGpu || batteryMenuBarEnabled)
    }

    func menuBarStatsEnabled(hasBattery: Bool, hasGpu: Bool) -> Bool {
        showMenuBarStats && (menuBarShowCpu || menuBarShowMemory || (menuBarShowGpu && hasGpu) || (batteryMenuBarEnabled && hasBattery))
    }

    func adjustedForHardware(hasBattery: Bool, hasGpu: Bool) -> QuitXConfig {
        var copy = self
        if !hasBattery {
            copy.batteryMenuBarEnabled = false
            copy.batterySaverEnabled = false
        }
        if !hasGpu {
            copy.menuBarShowGpu = false
        }
        return copy
    }

    var hardwareAdjusted: QuitXConfig {
        adjustedForHardware(hasBattery: HardwareCapabilities.hasBattery, hasGpu: HardwareCapabilities.hasGpuStatistics)
    }

    var availableMenuBarStatsEnabled: Bool {
        menuBarStatsEnabled(hasBattery: HardwareCapabilities.hasBattery, hasGpu: HardwareCapabilities.hasGpuStatistics)
    }

    enum MenuBarStatStyle: String, Codable, Equatable, CaseIterable, Sendable {
        case icon = "Icon"
        case text = "Text"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw.lowercased() {
            case "text", "txt":
                self = .text
            default:
                self = .icon
            }
        }
    }

    enum MenuBarMemoryUnit: String, Codable, Equatable, CaseIterable, Sendable {
        case gb = "GB"
        case percentage = "Percentage"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw.lowercased() {
            case "percentage", "percent", "%":
                self = .percentage
            default:
                self = .gb
            }
        }
    }

    enum ForceMode: String, Codable, Equatable, Sendable { case normal, force }
    enum SortBy: String, Codable, Equatable, CaseIterable, Sendable {
        case cpuDesc = "High to Low CPU %"
        case cpuAsc = "Low to High CPU %"
        case memoryDesc = "High to Low Memory"
        case memoryAsc = "Low to High Memory"
        case name = "A-Z Alphabetical"
        case nameDesc = "Z-A Alphabetical"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "High to Low CPU %", "cpu", "cpuDesc": self = .cpuDesc
            case "Low to High CPU %", "cpuAsc": self = .cpuAsc
            case "High to Low Memory", "memory", "memoryDesc": self = .memoryDesc
            case "Low to High Memory", "memoryAsc": self = .memoryAsc
            case "A-Z Alphabetical", "name", "alphaAsc": self = .name
            case "Z-A Alphabetical", "nameDesc", "alphaDesc": self = .nameDesc
            default: self = .name
            }
        }
    }

    static var `default`: QuitXConfig {
        QuitXConfig(
            exclude: [],
            force: .normal,
            includeFinder: false,
            includeTrash: false,
            includeBackground: false,
            groupBackground: true,
            defaultSelectAll: true,
            neverQuitMusic: false,
            musicApps: ["Music", "Spotify", "Deezer", "Tidal", "Doppler"],
            autoUpdate: true,
            confirmQuitAll: true,
            confirmIndividualAction: false,
            playSounds: true,
            quitInactiveAfterMinutes: 0,
            disableQuitTips: false,
            sortBy: .name
        )
    }
}
