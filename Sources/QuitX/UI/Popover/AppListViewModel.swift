import SwiftUI
import AppKit

@MainActor
final class AppListViewModel: ObservableObject {
    static let shared = AppListViewModel()

    private var appIdSet: Set<String> = []

    @Published var apps: [AppInfo] = [] {
        didSet {
            appIdSet = Set(apps.map(\.id))
            updateFilteredApps()
        }
    }
    @Published var selected: Set<String> = [] {
        didSet { updateSelectionCache() }
    }
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
    @Published private(set) var isAllSelected: Bool = false
    @Published private(set) var isPartiallySelected: Bool = false
    @Published private(set) var selectedVisibleCount: Int = 0
    @Published var isOptionKeyPressed: Bool = false
    private var resistantPids = [String: pid_t]()

    static func flagResistantApps(
        _ list: [AppInfo],
        resistantPids: [String: pid_t]
    ) -> (apps: [AppInfo], live: [String: pid_t]) {
        guard !resistantPids.isEmpty else { return (list, resistantPids) }
        var running = Set<String>()
        for app in list {
            let key = PerAppQuitRule.ruleKey(bundleId: app.bundleId, name: app.name)
            for pid in app.pids {
                running.insert("\(key)#\(pid)")
            }
        }
        let live = resistantPids.filter { running.contains("\($0.key)#\($0.value)") }
        let flagged = list.map { app -> AppInfo in
            let key = PerAppQuitRule.ruleKey(bundleId: app.bundleId, name: app.name)
            guard !app.isUnresponsive,
                  let pid = live[key],
                  app.pids.contains(pid) else { return app }
            return app.settingUnresponsive(true)
        }
        return (flagged, live)
    }

    private func applyResistantFlags(_ list: [AppInfo]) -> [AppInfo] {
        let result = Self.flagResistantApps(list, resistantPids: resistantPids)
        resistantPids = result.live
        return result.apps
    }

    private func noteQuitResistance(app: AppInfo, succeeded: Bool) {
        let key = PerAppQuitRule.ruleKey(bundleId: app.bundleId, name: app.name)
        if succeeded {
            resistantPids.removeValue(forKey: key)
        } else if let pid = app.pid ?? app.pids.first {
            resistantPids[key] = pid
        }
    }
    @Published var isLoading: Bool = false
    @Published var lastQuitCount: Int = 0
    @Published var showToast: Bool = false
    @Published private(set) var toastMessage: String = ""
    @Published private(set) var toastIsError: Bool = false
    @Published private(set) var pendingAppIds: Set<String> = []
    @Published private(set) var isBatchQuitting: Bool = false
    @Published var currentQuote: String = "Don't give up quitting ⚡"
    @Published var listNeedsScrolling: Bool = false
    @Published var showConfirmQuitAll: Bool = false {
        didSet {
            StatusItemController.shared?.updatePopoverSize()
        }
    }
    @Published var isConfirmQuitAllForced: Bool = false
    private var pendingQuitAllTargets: [AppInfo]?
    @Published var pendingIndividualAction: IndividualAction? = nil {
        didSet {
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    enum IndividualAction: Equatable {
        case quit(app: AppInfo, force: Bool)
        case restart(app: AppInfo)
    }

    func confirmQuitAllAction() {
        showConfirmQuitAll = false
        let force = isConfirmQuitAllForced
        isConfirmQuitAllForced = false
        let targets = pendingQuitAllTargets ?? filteredApps.filter { selected.contains($0.id) }
        pendingQuitAllTargets = nil
        Task {
            await performQuit(targets: targets, force: force)
        }
    }

    func cancelConfirmQuitAll() {
        showConfirmQuitAll = false
        isConfirmQuitAllForced = false
        pendingQuitAllTargets = nil
    }

    func requestConfirmQuitAll(targets: [AppInfo], force: Bool) {
        pendingQuitAllTargets = targets
        isConfirmQuitAllForced = force
        showConfirmQuitAll = true
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
    private var liveStatsGeneration = 0
    private(set) var lastRefreshDate: Date = .distantPast
    private var lastHogRescueDate: Date = .distantPast

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
            let optionPressed = event.modifierFlags.contains(.option)
            if let self, optionPressed != self.isOptionKeyPressed {
                self.isOptionKeyPressed = optionPressed
            }
            return event
        }
    }

    func randomizeQuote() {
        currentQuote = quotes.randomElement() ?? "Don't give up quitting ⚡"
    }

    private func updateFilteredApps() {
        let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasQuery = !normalizedQuery.isEmpty
        let list: [AppInfo]
        if !showBackgroundApps || hasQuery {
            list = apps.filter { app in
                if !showBackgroundApps && app.isBackground { return false }
                if hasQuery && !app.name.lowercased().contains(normalizedQuery) { return false }
                return true
            }
        } else {
            list = apps
        }
        if filteredApps != list {
            filteredApps = list
            visibleIds = Set(list.map(\.id))
        }
        updateSelectionCache()
    }

    private func updateSelectionCache() {
        let intersectionCount = selected.intersection(visibleIds).count
        selectedVisibleCount = intersectionCount
        isAllSelected = !visibleIds.isEmpty && intersectionCount == visibleIds.count
        isPartiallySelected = !visibleIds.isEmpty && intersectionCount > 0 && intersectionCount < visibleIds.count
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
        let flagged = applyResistantFlags(fetched)
        if apps != flagged {
            apps = flagged
        }
        lastRefreshDate = Date()

        let configSettingChanged = (lastConfigDefaultSelectAll != nil && lastConfigDefaultSelectAll != cfg.defaultSelectAll)
        lastConfigDefaultSelectAll = cfg.defaultSelectAll

        let newSelection: Set<String>
        if !hasInitializedSelection || configSettingChanged {
            newSelection = cfg.defaultSelectAll ? visibleIds : []
            hasInitializedSelection = true
        } else if selectedAllBeforeRefresh {
            newSelection = visibleIds
        } else {
            newSelection = selected.intersection(appIdSet)
        }
        if selected != newSelection {
            selected = newSelection
        }
    }

    func updateLiveStats() async {
        guard !isLoading else { return }
        liveStatsGeneration += 1
        let generation = liveStatsGeneration
        let selectedAllBeforeRefresh = isAllSelected
        let cfg = activeScanConfig
        let hogPids: Set<pid_t>
        if cfg.hogAlertEnabled {
            hogPids = HogMonitor.shared.noteLiveApps(
                apps,
                threshold: cfg.effectiveHogCpuThreshold
            )
        } else {
            HogMonitor.shared.reset()
            hogPids = []
        }
        let updated = await AppListService.shared.fetchLiveStats(currentApps: apps, config: cfg, hogPids: hogPids)
        guard !Task.isCancelled, !isLoading, generation == liveStatsGeneration else { return }
        let flagged = applyResistantFlags(updated)
        if cfg.hogAlertEnabled,
           HogMonitor.shared.rescueEligible(
               cpu: SystemUsage.cpuPercent(),
               threshold: cfg.effectiveHogCpuThreshold
           ),
           Date().timeIntervalSince(lastHogRescueDate) >= 5 {
            let rescueTargets = InactiveRescueTargets.select(
                apps: flagged,
                config: cfg,
                frontmostPid: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                ownPid: ProcessInfo.processInfo.processIdentifier
            )
            if !rescueTargets.isEmpty {
                lastHogRescueDate = Date()
                RescueConsentController.shared.request(targets: rescueTargets, reason: .cpu(SystemUsage.cpuPercent()))
                return
            }
        }
        if apps != flagged {
            apps = flagged
        }
        let newSelection = selectedAllBeforeRefresh
            ? visibleIds
            : selected.intersection(appIdSet)
        if selected != newSelection {
            selected = newSelection
        }
    }

    func quitAllFromShortcut(force: Bool) async {
        guard !hasPendingOperations else { return }
        await refresh()

        let targets = apps
        guard !targets.isEmpty else { return }

        if configStore.config.confirmQuitAll {
            selected = Set(targets.map(\.id))
            requestConfirmQuitAll(targets: targets, force: force)
            StatusItemController.shared?.showPopover()
            return
        }

        await performQuit(targets: targets, force: force)
    }

    func quitSingle(app: AppInfo, force: Bool) async {
        guard pendingAppIds.insert(app.id).inserted else { return }
        defer { pendingAppIds.remove(app.id) }

        SoundService.playQuitSingle()
        let results = await QuitService.shared.quit(apps: [app], force: force)
        let succeeded = results.first?.success == true
        noteQuitResistance(app: app, succeeded: succeeded)
        if succeeded {
            RecentlyQuitService.shared.record(app: app)
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
        let targets = filteredApps.filter { selected.contains($0.id) }
        guard !targets.isEmpty else { return }
        await performQuit(targets: targets, force: force)
    }

    static func othersTargets(keepingId: String, apps: [AppInfo]) -> [AppInfo] {
        apps.filter { $0.id != keepingId }
    }

    func quitOthers(keeping: AppInfo, force: Bool) async {
        guard !hasPendingOperations else { return }
        let targets = Self.othersTargets(keepingId: keeping.id, apps: apps)
        guard !targets.isEmpty else { return }

        if configStore.config.confirmQuitAll {
            selected = Set(targets.map(\.id))
            requestConfirmQuitAll(targets: targets, force: force)
            StatusItemController.shared?.showPopover()
            return
        }

        await performQuit(targets: targets, force: force)
    }

    func quitSilently(targets: [AppInfo], force: Bool) async {
        await performQuit(targets: targets, force: force)
    }

    func runBackgroundHogRescue() async {
        guard Date().timeIntervalSince(lastHogRescueDate) >= 5 else { return }
        if Date().timeIntervalSince(lastRefreshDate) > 2.0 {
            await refresh()
        }
        let cfg = ConfigStore.shared.config
        let targets = InactiveRescueTargets.select(
            apps: apps,
            config: cfg,
            frontmostPid: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            ownPid: ProcessInfo.processInfo.processIdentifier
        )
        guard !targets.isEmpty else { return }
        lastHogRescueDate = Date()
        RescueConsentController.shared.request(targets: targets, reason: .cpu(SystemUsage.cpuPercent()))
    }

    private func performQuit(targets: [AppInfo], force: Bool) async {
        guard !hasPendingOperations else { return }
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
        for result in results {
            noteQuitResistance(app: result.app, succeeded: result.success)
        }
        RecentlyQuitService.shared.record(apps: targets.filter { successfulIds.contains($0.id) })
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
            triggerToast(message: "Couldn’t restart \(app.name). Try force quit.", isError: true)
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
