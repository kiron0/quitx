import Foundation

enum ListenerGrouping: String, Codable, Equatable, CaseIterable, Sendable {
    case none = "None"
    case project = "Project"
    case docker = "Docker"
    case process = "Process"
}

enum PortSortBy: String, Codable, Equatable, CaseIterable, Sendable {
    case portAsc = "Port (Low to High)"
    case portDesc = "Port (High to Low)"
    case name = "Process Name (A-Z)"
    case memoryDesc = "Memory Usage"
    case cpuDesc = "CPU Usage"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "Port (High to Low)", "portDesc": self = .portDesc
        case "Process Name (A-Z)", "name": self = .name
        case "Memory Usage", "memoryDesc": self = .memoryDesc
        case "CPU Usage", "cpuDesc": self = .cpuDesc
        default: self = .portAsc
        }
    }
}

enum PopoverTab: String, CaseIterable, Sendable {
    case apps
    case ports

    static let defaultsKey = "QuitXPopoverTab"

    static func stored(defaults: UserDefaults = .standard) -> PopoverTab {
        defaults.string(forKey: defaultsKey).flatMap(PopoverTab.init(rawValue:)) ?? .apps
    }

    func store(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
