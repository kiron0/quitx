import Foundation

struct QuitXConfig: Codable, Equatable {
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
    var playSounds: Bool = true
    var quitInactiveAfterMinutes: Int = 0
    var disableQuitTips: Bool = false
    var sortBy: SortBy = .name
    var onQuitFailure: OnQuitFailureMode?

    private enum CodingKeys: String, CodingKey {
        case exclude, force, includeFinder, includeTrash, includeBackground, groupBackground
        case defaultSelectAll, neverQuitMusic, musicApps, autoUpdate, confirmQuitAll, playSounds
        case quitInactiveAfterMinutes, disableQuitTips, sortBy, onQuitFailure
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
        playSounds: Bool = true,
        quitInactiveAfterMinutes: Int = 0,
        disableQuitTips: Bool = false,
        sortBy: SortBy = .name,
        onQuitFailure: OnQuitFailureMode? = nil
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
        self.playSounds = playSounds
        self.quitInactiveAfterMinutes = quitInactiveAfterMinutes
        self.disableQuitTips = disableQuitTips
        self.sortBy = sortBy
        self.onQuitFailure = onQuitFailure
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
        playSounds = try container.decodeIfPresent(Bool.self, forKey: .playSounds) ?? defaults.playSounds
        quitInactiveAfterMinutes = try container.decodeIfPresent(Int.self, forKey: .quitInactiveAfterMinutes) ?? defaults.quitInactiveAfterMinutes
        disableQuitTips = try container.decodeIfPresent(Bool.self, forKey: .disableQuitTips) ?? defaults.disableQuitTips
        sortBy = try container.decodeIfPresent(SortBy.self, forKey: .sortBy) ?? defaults.sortBy
        onQuitFailure = try container.decodeIfPresent(OnQuitFailureMode.self, forKey: .onQuitFailure)
    }

    enum ForceMode: String, Codable, Equatable { case normal, force }
    enum SortBy: String, Codable, Equatable, CaseIterable {
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
            default: self = .cpuDesc
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
            defaultSelectAll: false,
            neverQuitMusic: false,
            musicApps: ["Music", "Spotify", "Deezer", "Tidal", "Doppler"],
            autoUpdate: true,
            confirmQuitAll: true,
            playSounds: true,
            quitInactiveAfterMinutes: 0,
            disableQuitTips: false,
            sortBy: .name,
            onQuitFailure: nil
        )
    }
}
