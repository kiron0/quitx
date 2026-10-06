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
    var confirmQuitAll: Bool = true
    var confirmIndividualAction: Bool = false
    var playSounds: Bool = true
    var quitInactiveAfterMinutes: Int = 0
    var disableQuitTips: Bool = false
    var sortBy: SortBy = .name
    var perAppQuitRules: [String: Int] = [:]
    var quitOnSleep: Bool = false
    var quitOnScreenLock: Bool = false
    var showMenuBarStats: Bool = false
    var hogAlertEnabled: Bool = false
    var hogCpuThreshold: Double = 80
    var hogSustainMinutes: Int = 5
    var memoryPressureQuitEnabled: Bool = false
    var memoryPressureThresholdMB: Int = 1024
    var batterySaverEnabled: Bool = false
    var quitTimers: [String: Double] = [:]

    private enum CodingKeys: String, CodingKey {
        case exclude, force, includeFinder, includeTrash, includeBackground, groupBackground
        case defaultSelectAll, neverQuitMusic, musicApps, autoUpdate, confirmQuitAll, confirmIndividualAction, playSounds
        case quitInactiveAfterMinutes, disableQuitTips, sortBy, perAppQuitRules
        case quitOnSleep, quitOnScreenLock, showMenuBarStats
        case hogAlertEnabled, hogCpuThreshold, hogSustainMinutes
        case memoryPressureQuitEnabled, memoryPressureThresholdMB, batterySaverEnabled
        case quitTimers
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
        confirmQuitAll: Bool = true,
        confirmIndividualAction: Bool = false,
        playSounds: Bool = true,
        quitInactiveAfterMinutes: Int = 0,
        disableQuitTips: Bool = false,
        sortBy: SortBy = .name,
        perAppQuitRules: [String: Int] = [:],
        quitOnSleep: Bool = false,
        quitOnScreenLock: Bool = false,
        showMenuBarStats: Bool = false,
        hogAlertEnabled: Bool = false,
        hogCpuThreshold: Double = 80,
        hogSustainMinutes: Int = 5,
        memoryPressureQuitEnabled: Bool = false,
        memoryPressureThresholdMB: Int = 1024,
        batterySaverEnabled: Bool = false,
        quitTimers: [String: Double] = [:]
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
        self.confirmQuitAll = confirmQuitAll
        self.confirmIndividualAction = confirmIndividualAction
        self.playSounds = playSounds
        self.quitInactiveAfterMinutes = quitInactiveAfterMinutes
        self.disableQuitTips = disableQuitTips
        self.sortBy = sortBy
        self.perAppQuitRules = perAppQuitRules
        self.quitOnSleep = quitOnSleep
        self.quitOnScreenLock = quitOnScreenLock
        self.showMenuBarStats = showMenuBarStats
        self.hogAlertEnabled = hogAlertEnabled
        self.hogCpuThreshold = hogCpuThreshold
        self.hogSustainMinutes = hogSustainMinutes
        self.memoryPressureQuitEnabled = memoryPressureQuitEnabled
        self.memoryPressureThresholdMB = memoryPressureThresholdMB
        self.batterySaverEnabled = batterySaverEnabled
        self.quitTimers = quitTimers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        exclude = try container.decodeIfPresent([String].self, forKey: .exclude) ?? defaults.exclude
        force = try container.decodeIfPresent(ForceMode.self, forKey: .force) ?? defaults.force
        includeFinder = try container.decodeIfPresent(Bool.self, forKey: .includeFinder) ?? defaults.includeFinder
        includeTrash = try container.decodeIfPresent(Bool.self, forKey: .includeTrash) ?? defaults.includeTrash
        includeBackground = try container.decodeIfPresent(Bool.self, forKey: .includeBackground) ?? defaults.includeBackground
        groupBackground = try container.decodeIfPresent(Bool.self, forKey: .groupBackground) ?? defaults.groupBackground
        defaultSelectAll = try container.decodeIfPresent(Bool.self, forKey: .defaultSelectAll) ?? defaults.defaultSelectAll
        neverQuitMusic = try container.decodeIfPresent(Bool.self, forKey: .neverQuitMusic) ?? defaults.neverQuitMusic
        musicApps = try container.decodeIfPresent([String].self, forKey: .musicApps) ?? defaults.musicApps
        autoUpdate = try container.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? defaults.autoUpdate
        confirmQuitAll = try container.decodeIfPresent(Bool.self, forKey: .confirmQuitAll) ?? defaults.confirmQuitAll
        confirmIndividualAction = try container.decodeIfPresent(Bool.self, forKey: .confirmIndividualAction) ?? defaults.confirmIndividualAction
        playSounds = try container.decodeIfPresent(Bool.self, forKey: .playSounds) ?? defaults.playSounds
        quitInactiveAfterMinutes = try container.decodeIfPresent(Int.self, forKey: .quitInactiveAfterMinutes) ?? defaults.quitInactiveAfterMinutes
        disableQuitTips = try container.decodeIfPresent(Bool.self, forKey: .disableQuitTips) ?? defaults.disableQuitTips
        sortBy = try container.decodeIfPresent(SortBy.self, forKey: .sortBy) ?? defaults.sortBy
        perAppQuitRules = try container.decodeIfPresent([String: Int].self, forKey: .perAppQuitRules) ?? defaults.perAppQuitRules
        quitOnSleep = try container.decodeIfPresent(Bool.self, forKey: .quitOnSleep) ?? defaults.quitOnSleep
        quitOnScreenLock = try container.decodeIfPresent(Bool.self, forKey: .quitOnScreenLock) ?? defaults.quitOnScreenLock
        showMenuBarStats = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarStats) ?? defaults.showMenuBarStats
        hogAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .hogAlertEnabled) ?? defaults.hogAlertEnabled
        hogCpuThreshold = try container.decodeIfPresent(Double.self, forKey: .hogCpuThreshold) ?? defaults.hogCpuThreshold
        hogSustainMinutes = try container.decodeIfPresent(Int.self, forKey: .hogSustainMinutes) ?? defaults.hogSustainMinutes
        memoryPressureQuitEnabled = try container.decodeIfPresent(Bool.self, forKey: .memoryPressureQuitEnabled) ?? defaults.memoryPressureQuitEnabled
        memoryPressureThresholdMB = try container.decodeIfPresent(Int.self, forKey: .memoryPressureThresholdMB) ?? defaults.memoryPressureThresholdMB
        batterySaverEnabled = try container.decodeIfPresent(Bool.self, forKey: .batterySaverEnabled) ?? defaults.batterySaverEnabled
        quitTimers = try container.decodeIfPresent([String: Double].self, forKey: .quitTimers) ?? defaults.quitTimers
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
