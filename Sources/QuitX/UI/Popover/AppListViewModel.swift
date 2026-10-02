import SwiftUI
import AppKit

@MainActor
final class AppListViewModel: ObservableObject {
    static let shared = AppListViewModel()

    @Published var apps: [AppInfo] = []
    @Published var selected: Set<String> = []
    @Published var searchQuery: String = ""
    @Published var showBackgroundApps: Bool
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

    private var hasInitializedSelection = false

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

    init() {
        showBackgroundApps = ConfigStore.shared.config.includeBackground
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
            DispatchQueue.main.async {
                self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
            }
            return event
        }
    }

    func randomizeQuote() {
        currentQuote = quotes.randomElement() ?? "Don't give up quitting ⚡"
    }

    var filteredApps: [AppInfo] {
        var list = apps
        if !showBackgroundApps {
            list = list.filter { !$0.isBackground }
        }
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedQuery.isEmpty {
            let q = normalizedQuery
            list = list.filter { $0.name.lowercased().contains(q) }
        }
        return list
    }

    var isAllSelected: Bool {
        let current = filteredApps
        return !current.isEmpty && current.allSatisfy { selected.contains($0.id) }
    }

    var isPartiallySelected: Bool {
        let visibleIds = Set(filteredApps.map(\.id))
        let visibleSelection = selected.intersection(visibleIds)
        return !visibleSelection.isEmpty && visibleSelection.count < visibleIds.count
    }

    var selectedVisibleCount: Int {
        let visibleIds = Set(filteredApps.map(\.id))
        return selected.intersection(visibleIds).count
    }

    var hasPendingOperations: Bool {
        !pendingAppIds.isEmpty
    }

    func toggleSelectAll() {
        let visibleIds = Set(filteredApps.map(\.id))
        if visibleIds.isSubset(of: selected) {
            selected.subtract(visibleIds)
        } else {
            selected.formUnion(visibleIds)
        }
    }

    func toggleSelection(for app: AppInfo) {
        if selected.contains(app.id) {
            selected.remove(app.id)
        } else {
            selected.insert(app.id)
        }
    }

    func refresh() async {
        isLoading = true
        let selectedAllBeforeRefresh = isAllSelected
        var cfg = configStore.config
        if showBackgroundApps {
            cfg.includeBackground = true
        }
        let fetched = AppListService.shared.fetchApps(config: cfg)
        apps = sort(apps: fetched)

        if !hasInitializedSelection {
            if cfg.defaultSelectAll {
                selected = Set(filteredApps.map(\.id))
            } else {
                selected = []
            }
            hasInitializedSelection = true
        } else if selectedAllBeforeRefresh {
            selected = Set(filteredApps.map(\.id))
        } else {
            let validIds = Set(apps.map(\.id))
            selected = selected.intersection(validIds)
        }
        isLoading = false
    }

    func updateLiveStats() async {
        guard !isLoading else { return }
        var cfg = configStore.config
        if showBackgroundApps {
            cfg.includeBackground = true
        }
        let fetched = AppListService.shared.fetchApps(config: cfg)
        apps = sort(apps: fetched)
        let validIds = Set(apps.map(\.id))
        selected = selected.intersection(validIds)
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

    func stash() async {
        let targets = filteredApps
        _ = await StashService.shared.stash(apps: targets)
        await refresh()
    }

    func restore() async {
        _ = await StashService.shared.restore()
        await refresh()
    }

    var hasStash: Bool { StashService.shared.hasStash }

    private func sort(apps: [AppInfo]) -> [AppInfo] {
        switch configStore.config.sortBy {
        case .cpuDesc:
            return apps.sorted {
                if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .cpuAsc:
            return apps.sorted {
                if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage < $1.cpuUsage }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .memoryDesc:
            return apps.sorted {
                if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .memoryAsc:
            return apps.sorted {
                if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes < $1.memoryBytes }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .name:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
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
