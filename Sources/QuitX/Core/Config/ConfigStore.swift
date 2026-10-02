import Foundation

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: QuitXConfig = .default

    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/quitx/config.json")
    }

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode(QuitXConfig.self, from: data) else {
            return
        }
        config = decoded
    }

    func save() {
        guard let json = try? JSONEncoder().encode(config) else { return }
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? json.write(to: configURL, options: .atomic)
    }
}
