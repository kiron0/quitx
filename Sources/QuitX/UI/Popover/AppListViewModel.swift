import SwiftUI
import AppKit

@MainActor
final class AppListViewModel: ObservableObject {
    static let shared = AppListViewModel()

    @Published var apps: [AppInfo] = [] {
        didSet { updateFilteredApps() }
    }
    @Published var selected: Set<String> = []
    @Published var searchQuery: String = "" {
        didSet { updateFilteredApps() }
    }
    @Published var showBackgroundApps: Bool {
        didSet {
            if configStore.config.includeBackground != showBackgroundApps {
                configStore.config.includeBackground = showBackgroundApps
                configStore.save()
            }
            updateFilteredApps()
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }
    @Published private(set) var filteredApps: [AppInfo] = []
    private(set) var visibleIds: Set<String> = []
    @Published var isOptionKeyPressed: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastQuitCount: Int = 0
    @Published var showToast: Bool = false
    @Published private(set) var toastMessage: String = ""
    @Published private(set) var toastIsError: Bool = false
    @Published private(set) var pendingAppIds: Set<String> = []
    @Published private(set) var isBatchQuitting: Bool = false
    @Published var currentQuote: String = "Don't give up quitting ⚡"
    @Published var listNeedsScrolling: Bool = false
    @Published var arrowX: CGFloat = 135
    @Published var showConfirmQuitAll: Bool = false
    @Published var isConfirmQuitAllForced: Bool = false
    @Published var pendingIndividualAction: IndividualAction? = nil

    enum IndividualAction: Equatable {
        case quit(app: AppInfo, force: Bool)
        case restart(app: AppInfo)
    }

    func confirmQuitAllAction() {
        showConfirmQuitAll = false
        let force = isConfirmQuitAllForced
        isConfirmQuitAllForced = false
        Task {
            await quitAll(force: force)
        }
    }

    func cancelConfirmQuitAll() {
        showConfirmQuitAll = false
        isConfirmQuitAllForced = false
    }

    func requestQuitSingle(app: AppInfo, force: Bool) {
        if configStore.config.confirmIndividualAction {
            pendingIndividualAction = .quit(app: app, force: force)
        } else {
            Task { await quitSingle(app: app, force: force) }
        }
    }

    func requestRestart(app: AppInfo) {
        if configStore.config.confirmIndividualAction {
            pendingIndividualAction = .restart(app: app)
        } else {
            Task { await restartApp(app) }
        }
    }

    func confirmIndividualAction() {
        guard let action = pendingIndividualAction else { return }
        pendingIndividualAction = nil
        Task {
            switch action {
            case .quit(let app, let force):
                await quitSingle(app: app, force: force)
            case .restart(let app):
                await restartApp(app)
            }
        }
    }

    func cancelIndividualAction() {
        pendingIndividualAction = nil
    }

    private var hasInitializedSelection = false
    private var lastConfigDefaultSelectAll: Bool?

    private let quotes = [
        "Don't give up quitting ⚡",
        "Quitters are winners 🏆",
        "Time to quit(all) 🤘",
        "A fresh start without a restart ⚡",
        "Clear your mind and your RAM 🧠",
        "Less noise, more speed 🚀"
    ]

    private let configStore = ConfigStore.shared
    private var flagsMonitor: Any?
    private var toastTask: Task<Void, Never>?
    private var scanGeneration = 0
    private var isUpdatingLiveStats = false

    init() {
        showBackgroundApps = ConfigStore.shared.config.includeBackground
        updateFilteredApps()
        startModifierMonitor()
        randomizeQuote()
    }

    deinit {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func startModifierMonitor() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
            return event
        }
    }

    func randomizeQuote() {
        currentQuote = quotes.randomElement() ?? "Don't give up quitting ⚡"
    }

    private func updateFilteredApps() {
        var list = apps
        if !showBackgroundApps {
            list = list.filter { !$0.isBackground }
        }
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedQuery.isEmpty {
            list = list.filter { $0.name.lowercased().contains(normalizedQuery) }
        }
        if filteredApps != list {
            filteredApps = list
        }
        visibleIds = Set(list.map(\.id))
    }

    var isAllSelected: Bool {
        !visibleIds.isEmpty && visibleIds.isSubset(of: selected)
    }

    var isPartiallySelected: Bool {
        guard !visibleIds.isEmpty else { return false }
        let count = selected.intersection(visibleIds).count
        return count > 0 && count < visibleIds.count
    }

    var selectedVisibleCount: Int {
        selected.intersection(visibleIds).count
    }

    var hasPendingOperations: Bool {
        !pendingAppIds.isEmpty
    }

    func toggleSelectAll() {
        if visibleIds.isSubset(of: selected) {
            selected.subtract(visibleIds)
        } else {
            selected.formUnion(visibleIds)
        }
    }

    func applyDefaultSelection() {
        hasInitializedSelection = true
        lastConfigDefaultSelectAll = configStore.config.defaultSelectAll
        if configStore.config.defaultSelectAll {
            selected = visibleIds
        } else {
            selected = []
        }
    }

    func resetSelectionState() {
        hasInitializedSelection = false
    }

    func toggleSelection(for app: AppInfo) {
        if selected.contains(app.id) {
            selected.remove(app.id)
        } else {
            selected.insert(app.id)
        }
    }

    private var activeScanConfig: QuitXConfig {
        var cfg = configStore.config
        if showBackgroundApps {
            cfg.includeBackground = true
        }
        return cfg
    }

    func refresh() async {
        scanGeneration += 1
        let generation = scanGeneration
        isLoading = true
        defer {
            if generation == scanGeneration { isLoading = false }
        }
        let selectedAllBeforeRefresh = isAllSelected
        let cfg = activeScanConfig
        let fetched = await AppListService.shared.fetchApps(config: cfg)
        guard !Task.isCancelled, generation == scanGeneration else { return }
        if apps != fetched {
            apps = fetched
        }

        let configSettingChanged = (lastConfigDefaultSelectAll != nil && lastConfigDefaultSelectAll != cfg.defaultSelectAll)
        lastConfigDefaultSelectAll = cfg.defaultSelectAll

        let newSelection: Set<String>
        if !hasInitializedSelection || configSettingChanged {
            newSelection = cfg.defaultSelectAll ? visibleIds : []
            hasInitializedSelection = true
        } else if selectedAllBeforeRefresh {
            newSelection = visibleIds
        } else {
            newSelection = selected.intersection(Set(apps.map(\.id)))
        }
        if selected != newSelection {
            selected = newSelection
        }
    }

    func updateLiveStats() async {
        guard !isLoading, !isUpdatingLiveStats else { return }
        isUpdatingLiveStats = true
        defer { isUpdatingLiveStats = false }
        let selectedAllBeforeRefresh = isAllSelected
        let cfg = activeScanConfig
        let fetched = await AppListService.shared.fetchApps(config: cfg)
        guard !Task.isCancelled, !isLoading else { return }
        if apps != fetched {
            apps = fetched
        }
        let newSelection = selectedAllBeforeRefresh
            ? visibleIds
            : selected.intersection(Set(apps.map(\.id)))
        if selected != newSelection {
            selected = newSelection
        }
    }

    func quitAllFromShortcut(force: Bool) async {
        guard !hasPendingOperations else { return }
        await refresh()
        await quitAll(force: force)
    }

    func quitSingle(app: AppInfo, force: Bool) async {
        guard pendingAppIds.insert(app.id).inserted else { return }
        defer { pendingAppIds.remove(app.id) }

        SoundService.playQuitSingle()
        let results = await QuitService.shared.quit(apps: [app], force: force)
        let succeeded = results.first?.success == true
        if succeeded {
            selected.remove(app.id)
        }
        lastQuitCount = succeeded ? 1 : 0
        await refresh()
        if succeeded {
            triggerToast(message: "\(app.name) quit", isError: false)
        } else if !force {
            triggerToast(message: "\(app.name) is still open — ⌥ to force quit", isError: true)
        } else {
            triggerToast(message: "Couldn’t quit \(app.name)", isError: true)
        }
    }

    func quitAll(force: Bool) async {
        guard !hasPendingOperations else { return }
        let targets = filteredApps.filter { selected.contains($0.id) }
        guard !targets.isEmpty else { return }

        isBatchQuitting = true
        let targetIds = Set(targets.map(\.id))
        pendingAppIds.formUnion(targetIds)
        defer {
            pendingAppIds.subtract(targetIds)
            isBatchQuitting = false
        }

        SoundService.playQuitAll()
        let results = await QuitService.shared.quit(apps: targets, force: force)
        let successfulIds = Set(results.filter(\.success).map { $0.app.id })
        let failureCount = targets.count - successfulIds.count
        lastQuitCount = successfulIds.count
        selected.subtract(successfulIds)
        await refresh()
        randomizeQuote()
        if failureCount == 0 {
            let noun = successfulIds.count == 1 ? "app" : "apps"
            triggerToast(message: "\(successfulIds.count) \(noun) quit", isError: false)
        } else {
            triggerToast(
                message: "\(successfulIds.count) quit, \(failureCount) failed",
                isError: true
            )
        }
    }

    func restartApp(_ app: AppInfo) async {
        guard pendingAppIds.insert(app.id).inserted else { return }
        defer { pendingAppIds.remove(app.id) }

        let succeeded = await RestartService.shared.restart(app: app)
        await refresh()
        if !succeeded {
            triggerToast(message: "Couldn’t restart \(app.name)", isError: true)
        }
    }

    private func triggerToast(message: String, isError: Bool) {
        toastTask?.cancel()
        toastMessage = message
        toastIsError = isError
        showToast = true
        toastTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.showToast = false
        }
    }
}
