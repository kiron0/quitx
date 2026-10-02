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
    var sortBy: SortBy = .cpuDesc
    var onQuitFailure: OnQuitFailureMode?

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
            sortBy: .cpuDesc,
            onQuitFailure: nil
        )
    }
}
