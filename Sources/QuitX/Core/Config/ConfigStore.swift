import Foundation

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: QuitXConfig = .default {
        didSet {
            normalizedExcludedSet = Set(config.exclude.map { $0.lowercased() })
        }
    }

    private var normalizedExcludedSet: Set<String> = []
    private static let userDefaultsKey = "QuitXConfig"

    private init() { load() }

    deinit {
        saveWorkItem?.perform()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(QuitXConfig.self, from: data) else {
            normalizedExcludedSet = Set(config.exclude.map { $0.lowercased() })
            return
        }
        config = decoded
        normalizedExcludedSet = Set(decoded.exclude.map { $0.lowercased() })
    }

    private var saveWorkItem: DispatchWorkItem?

    func save(refreshAppList: Bool = false, immediate: Bool = false) {
        saveWorkItem?.cancel()
        let configToSave = self.config
        let writeBlock = {
            guard let json = try? JSONEncoder().encode(configToSave) else { return }
            UserDefaults.standard.set(json, forKey: Self.userDefaultsKey)
        }

        if immediate {
            writeBlock()
        } else {
            let item = DispatchWorkItem(block: writeBlock)
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        guard refreshAppList else { return }
        Task { @MainActor in
            await AppListViewModel.shared.refresh()
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    @discardableResult
    func addExcludedApps(_ identifiers: [String]) -> Int {
        var added = 0

        for rawIdentifier in identifiers {
            let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = identifier.lowercased()
            guard !normalized.isEmpty, normalizedExcludedSet.insert(normalized).inserted else { continue }
            config.exclude.append(identifier)
            added += 1
        }

        if added > 0 { save(refreshAppList: true) }
        return added
    }

    func removeExcludedApp(_ identifier: String) {
        let normalized = identifier.lowercased()
        let oldCount = config.exclude.count
        config.exclude.removeAll { $0.lowercased() == normalized }
        normalizedExcludedSet.remove(normalized)
        if config.exclude.count != oldCount { save(refreshAppList: true) }
    }

    func removeExcludedApps(_ identifiers: Set<String>) {
        let normalized = Set(identifiers.map { $0.lowercased() })
        guard !normalized.isEmpty else { return }
        let oldCount = config.exclude.count
        config.exclude.removeAll { normalized.contains($0.lowercased()) }
        normalizedExcludedSet.subtract(normalized)
        if config.exclude.count != oldCount { save(refreshAppList: true) }
    }

    func removeAllExcludedApps() {
        guard !config.exclude.isEmpty else { return }
        config.exclude.removeAll()
        normalizedExcludedSet.removeAll()
        save(refreshAppList: true)
    }
}
