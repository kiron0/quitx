import SwiftUI
import AppKit

@MainActor
final class AppListViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var selected: Set<UUID> = []
    @Published var searchQuery: String = ""
    @Published var showBackgroundApps: Bool = false
    @Published var isOptionKeyPressed: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastQuitCount: Int = 0
    @Published var showToast: Bool = false
    @Published var currentQuote: String = "Don't give up quitting ⚡"

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

    init() {
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
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) }
        }
        return list
    }

    var isAllSelected: Bool {
        let current = filteredApps
        return !current.isEmpty && current.allSatisfy { selected.contains($0.id) }
    }

    func toggleSelectAll() {
        if isAllSelected {
            selected.removeAll()
        } else {
            selected = Set(filteredApps.map(\.id))
        }
    }

    // MARK: - Actions

    func refresh() async {
        isLoading = true
        var cfg = configStore.config
        if showBackgroundApps {
            cfg.includeBackground = true
        }
        let fetched = AppListService.shared.fetchApps(config: cfg)
        apps = sort(apps: fetched)

        // Default to all selected if selection was empty or initialized
        if selected.isEmpty {
            selected = Set(filteredApps.map(\.id))
        } else {
            // Keep valid selections
            selected = selected.filter { id in apps.contains { $0.id == id } }
        }
        isLoading = false
    }

    func quitSingle(app: AppInfo, force: Bool) async {
        SoundService.playQuitSingle()
        _ = await QuitService.shared.quit(apps: [app], force: force)
        selected.remove(app.id)
        lastQuitCount = 1
        await refresh()
        triggerToast()
    }

    func quitAll(force: Bool) async {
        let targets = apps.filter { selected.contains($0.id) }
        guard !targets.isEmpty else { return }
        SoundService.playQuitAll()
        let results = await QuitService.shared.quit(apps: targets, force: force)
        lastQuitCount = results.filter(\.success).count
        selected.removeAll()
        await refresh()
        randomizeQuote()
        triggerToast()
    }

    func restartApp(_ app: AppInfo) async {
        _ = await RestartService.shared.restart(app: app)
        await refresh()
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

    // MARK: - Helpers

    private func sort(apps: [AppInfo]) -> [AppInfo] {
        switch configStore.config.sortBy {
        case .memory:
            return apps.sorted { $0.memoryBytes > $1.memoryBytes }
        default:
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func triggerToast() {
        showToast = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showToast = false
        }
    }
}
