import Foundation

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: QuitXConfig = .default

    private static let userDefaultsKey = "QuitXConfig"

    private init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(QuitXConfig.self, from: data) else {
            return
        }
        config = decoded
    }

    func save() {
        guard let json = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(json, forKey: Self.userDefaultsKey)
        Task { @MainActor in
            await AppListViewModel.shared.refresh()
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    @discardableResult
    func addExcludedApps(_ identifiers: [String]) -> Int {
        var known = Set(config.exclude.map { $0.lowercased() })
        var added = 0

        for rawIdentifier in identifiers {
            let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = identifier.lowercased()
            guard !normalized.isEmpty, known.insert(normalized).inserted else { continue }
            config.exclude.append(identifier)
            added += 1
        }

        if added > 0 { save() }
        return added
    }

    func removeExcludedApp(_ identifier: String) {
        let normalized = identifier.lowercased()
        let oldCount = config.exclude.count
        config.exclude.removeAll { $0.lowercased() == normalized }
        if config.exclude.count != oldCount { save() }
    }

    func removeAllExcludedApps() {
        guard !config.exclude.isEmpty else { return }
        config.exclude.removeAll()
        save()
    }
}
