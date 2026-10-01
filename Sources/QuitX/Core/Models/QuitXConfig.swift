import Foundation

/// Mirrors QuitxConfig from the CLI.
/// Reads from / writes to ~/.config/quitx/config.json for full CLI interop.
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
    var sortBy: SortBy?
    var onQuitFailure: OnQuitFailureMode?

    enum ForceMode: String, Codable, Equatable { case normal, force }
    enum SortBy: String, Codable, Equatable { case name, memory }

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
            sortBy: nil,
            onQuitFailure: nil
        )
    }
}
