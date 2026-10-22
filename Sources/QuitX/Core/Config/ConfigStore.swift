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
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else {
            normalizedExcludedSet = Set(config.exclude.map { $0.lowercased() })
            normalizeThresholds()
            return
        }
        do {
            let decoded = try JSONDecoder().decode(QuitXConfig.self, from: data)
            config = decoded
            normalizedExcludedSet = Set(decoded.exclude.map { $0.lowercased() })
        } catch {
            NSLog("QuitX: config decode failed, raw blob backed up: \(error)")
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey + ".backup")
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
            normalizedExcludedSet = Set(config.exclude.map { $0.lowercased() })
        }
        normalizeThresholds()
    }

    private func normalizeThresholds() {
        let systemMaxMB = max(128, Int(ProcessInfo.processInfo.physicalMemory / 1_048_576))
        let memoryFloorMB = max(128, Int((Double(systemMaxMB) * 0.25).rounded()))
        var mutated = false
        if config.hogCpuThreshold < 80 {
            config.hogCpuThreshold = 80
            mutated = true
        }
        if config.hogCpuThreshold > 100 {
            config.hogCpuThreshold = 100
            mutated = true
        }
        if config.memoryPressureThresholdMB < memoryFloorMB {
            config.memoryPressureThresholdMB = memoryFloorMB
            mutated = true
        }
        if config.memoryPressureThresholdMB > systemMaxMB {
            config.memoryPressureThresholdMB = systemMaxMB
            mutated = true
        }
        var seen = Set<String>()
        let deduped = config.exclude.filter { seen.insert($0.lowercased()).inserted }
        if deduped.count != config.exclude.count {
            config.exclude = deduped
            mutated = true
        }
        if mutated {
            flush()
        }
    }

    private var saveWorkItem: DispatchWorkItem?
    private var refreshWorkItem: DispatchWorkItem?
    private var saveGeneration = 0
    private var refreshGeneration = 0

    func flush() {
        saveGeneration += 1
        refreshGeneration += 1
        saveWorkItem?.cancel()
        saveWorkItem = nil
        refreshWorkItem?.cancel()
        refreshWorkItem = nil
        if let json = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(json, forKey: Self.userDefaultsKey)
        }
    }

    func save(refreshAppList: Bool = false, immediate: Bool = false) {
        saveGeneration += 1
        let generation = saveGeneration
        saveWorkItem?.cancel()
        let configToSave = self.config
        let writeBlock = {
            guard let json = try? JSONEncoder().encode(configToSave) else { return }
            UserDefaults.standard.set(json, forKey: Self.userDefaultsKey)
        }

        if immediate {
            writeBlock()
        } else {
            let item = DispatchWorkItem { [weak self] in
                guard let self, generation == self.saveGeneration else { return }
                writeBlock()
            }
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
        }

        guard refreshAppList else { return }
        refreshGeneration += 1
        let refreshToken = refreshGeneration
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, refreshToken == self.refreshGeneration else { return }
            Task { @MainActor in
                await AppListViewModel.shared.refresh()
                StatusItemController.shared?.updatePopoverSize()
            }
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
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
        normalizeThresholds()
        save(refreshAppList: true, immediate: true)
    }

    func perAppQuitMinutes(bundleId: String?, name: String) -> Int? {
        PerAppQuitRule.storedMinutes(bundleId: bundleId, name: name, rules: config.perAppQuitRules)
    }

    func effectiveQuitTimeoutMinutes(bundleId: String?, name: String) -> Int {
        PerAppQuitRule.timeoutMinutes(
            bundleId: bundleId,
            name: name,
            rules: config.perAppQuitRules,
            globalMinutes: config.quitInactiveAfterMinutes
        )
    }

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
