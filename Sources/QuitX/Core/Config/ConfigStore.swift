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

    var excludedNormalized: Set<String> { normalizedExcludedSet }

    private static let userDefaultsKey = QuitXConstants.UserDefaultsKeys.config

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
        var exclude = config.exclude

        for rawIdentifier in identifiers {
            let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = identifier.lowercased()
            guard !normalized.isEmpty, normalizedExcludedSet.insert(normalized).inserted else { continue }
            exclude.append(identifier)
            added += 1
        }

        guard added > 0 else { return 0 }
        config.exclude = exclude
        save(refreshAppList: true)
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

    func reset() {
        config = .default
        save(refreshAppList: true, immediate: true)
    }

    /// Stored per-app rule in minutes, or `nil` when the app follows the default.
    func perAppQuitMinutes(bundleId: String?, name: String) -> Int? {
        PerAppQuitRule.storedMinutes(bundleId: bundleId, name: name, rules: config.perAppQuitRules)
    }

    /// Effective auto-quit timeout in minutes. Returns `0` for Never.
    func effectiveQuitTimeoutMinutes(bundleId: String?, name: String) -> Int {
        PerAppQuitRule.timeoutMinutes(
            bundleId: bundleId,
            name: name,
            rules: config.perAppQuitRules,
            globalMinutes: config.quitInactiveAfterMinutes
        )
    }

    /// Stores a per-app rule. Minutes `<= 0` means Never.
    func setPerAppQuitRule(identifier: String, minutes: Int) {
        let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        var rules = config.perAppQuitRules
        rules[key] = max(0, minutes)
        config.perAppQuitRules = rules
        save()
    }

    func removePerAppQuitRule(identifier: String) {
        let key = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, config.perAppQuitRules[key] != nil else { return }
        var rules = config.perAppQuitRules
        rules.removeValue(forKey: key)
        config.perAppQuitRules = rules
        save()
    }
}
