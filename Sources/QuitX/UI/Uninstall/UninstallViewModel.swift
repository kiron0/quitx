import AppKit
import SwiftUI

@MainActor
final class UninstallViewModel: ObservableObject {
    enum Screen: Equatable {
        case picker
        case review
    }

    enum Phase: Equatable {
        case scanning
        case ready
        case removing
        case finished(trashed: Int, failed: [AppUninstaller.RemovalFailure])
    }

    enum Confirmation: Equatable {
        case removeSelected
        case removeItem(LeftoverItem)
    }

    struct PickerApp: Identifiable, Hashable {
        let target: UninstallTarget
        let isBackground: Bool

        var id: String { target.id }
    }

    enum LayoutMode: String, CaseIterable {
        case list
        case grid
    }

    enum AppStatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all = "All apps"
        case running = "Running"
        case background = "Menu bar"
        var id: String { rawValue }
    }

    enum AppSortOrder: String, CaseIterable, Identifiable, Sendable {
        case nameAsc = "Name (A–Z)"
        case nameDesc = "Name (Z–A)"
        case largest = "Largest first"
        case smallest = "Smallest first"
        var id: String { rawValue }
    }

    @Published private(set) var screen: Screen = .picker
    @Published private(set) var cameFromPicker = false

    @Published private(set) var pickerApps: [PickerApp] = []
    @Published private(set) var isLoadingApps = false
    private(set) var hasLoadedApps = false
    @Published var pickerSelection: Set<String> = []
    @Published var searchText = ""
    @Published var sizeFilter: ItemSizeFilter = .any
    @Published var statusFilter: AppStatusFilter = .all
    @Published var sortOrder: AppSortOrder = .nameAsc
    var isFiltered: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sizeFilter != .any
            || statusFilter != .all
    }
    func resetFilters() {
        searchText = ""
        sizeFilter = .any
        statusFilter = .all
        sortOrder = .nameAsc
    }
    @Published private(set) var bundleSizes: [String: Int64] = [:]
    @Published private(set) var runningIDs: Set<String> = []
    @Published var layoutMode: LayoutMode = {
        if let saved = UserDefaults.standard.string(forKey: "QuitXUninstallLayoutMode"),
           let mode = LayoutMode(rawValue: saved) {
            return mode
        }
        return .list
    }() {
        didSet {
            UserDefaults.standard.set(layoutMode.rawValue, forKey: "QuitXUninstallLayoutMode")
        }
    }

    @Published private(set) var targets: [UninstallTarget] = []
    @Published private(set) var items: [LeftoverItem] = []
    @Published var selected: Set<String> = []
    @Published var collapsed: Set<String> = []
    @Published private(set) var phase: Phase = .ready
    @Published var confirmation: Confirmation?
    @Published var errorMessage: String?

    private var icons: [String: NSImage] = [:]
    private var loadTask: Task<Void, Never>?
    private var sizeTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    func cancelWork() {
        loadTask?.cancel()
        sizeTask?.cancel()
        scanTask?.cancel()
        isLoadingApps = false
    }

    func icon(for target: UninstallTarget) -> NSImage {
        if let cached = icons[target.id] { return cached }
        let image = AppIconCache.icon(for: target.bundleIdentifier, url: target.bundleURL)
            ?? NSWorkspace.shared.icon(forFile: target.bundleURL.path)
        icons[target.id] = image
        return image
    }

    var filteredPickerApps: [PickerApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return pickerApps.filter { app in
            if sizeFilter != .any {
                let size = bundleSizes[app.id] ?? 0
                guard size >= sizeFilter.minimumBytes else { return false }
            }
            if statusFilter == .running {
                guard runningIDs.contains(app.id) else { return false }
            } else if statusFilter == .background {
                guard app.isBackground else { return false }
            }
            guard !query.isEmpty else { return true }
            return app.target.name.localizedCaseInsensitiveContains(query)
                || app.target.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }.sorted { left, right in
            switch sortOrder {
            case .nameAsc:
                let comp = left.target.name.localizedStandardCompare(right.target.name)
                if comp != .orderedSame { return comp == .orderedAscending }
            case .nameDesc:
                let comp = left.target.name.localizedStandardCompare(right.target.name)
                if comp != .orderedSame { return comp == .orderedDescending }
            case .largest:
                let lSize = bundleSizes[left.id] ?? 0
                let rSize = bundleSizes[right.id] ?? 0
                if lSize != rSize { return lSize > rSize }
            case .smallest:
                let lSize = bundleSizes[left.id] ?? 0
                let rSize = bundleSizes[right.id] ?? 0
                if lSize != rSize { return lSize < rSize }
            }
            return left.target.name.localizedStandardCompare(right.target.name) == .orderedAscending
        }
    }

    var pickerSelectedApps: [PickerApp] {
        pickerApps.filter { pickerSelection.contains($0.id) }
    }

    var pickerSelectedBytes: Int64 {
        pickerSelectedApps.reduce(0) { $0 + (bundleSizes[$1.id] ?? 0) }
    }

    var pickerTotalBytes: Int64 {
        pickerApps.reduce(0) { $0 + (bundleSizes[$1.id] ?? 0) }
    }

    func showPicker() {
        guard phase != .removing else { return }
        scanTask?.cancel()
        confirmation = nil
        errorMessage = nil
        screen = .picker
        loadAppsIfNeeded()
    }

    func loadAppsIfNeeded() {
        guard (!hasLoadedApps || pickerApps.isEmpty), !isLoadingApps else { return }
        loadApps(forceRefresh: false)
    }

    func loadApps(forceRefresh: Bool) {
        if !forceRefresh, hasLoadedApps, !pickerApps.isEmpty { return }
        loadTask?.cancel()
        isLoadingApps = true
        let running = InstalledApplicationScanner.runningApplicationInfos()
        loadTask = Task { [weak self] in
            let installed = await Task.detached(priority: .userInitiated) {
                InstalledApplicationScanner.scan(forceRefresh: forceRefresh, runningApplications: running)
            }.value
            guard let self, !Task.isCancelled else { return }
            let apps = installed.compactMap { app -> PickerApp? in
                guard let target = AppUninstaller.target(name: app.name, bundleIdentifier: app.bundleIdentifier, bundleURL: app.url) else { return nil }
                return PickerApp(target: target, isBackground: app.isBackground)
            }
            self.pickerApps = apps
            self.hasLoadedApps = true
            self.pickerSelection.formIntersection(Set(apps.map(\.id)))
            self.isLoadingApps = false
            self.refreshRunningState()
            self.measureBundles(apps.map(\.target))
        }
    }

    private func measureBundles(_ targets: [UninstallTarget]) {
        sizeTask?.cancel()
        let pending = targets.filter { bundleSizes[$0.id] == nil }
        guard !pending.isEmpty else { return }
        sizeTask = Task { [weak self] in
            for target in pending {
                if Task.isCancelled { return }
                let bytes = await Task.detached(priority: .utility) {
                    AppUninstaller.measure(target.bundleURL).bytes
                }.value
                guard let self, !Task.isCancelled else { return }
                self.bundleSizes[target.id] = bytes
            }
        }
    }

    func togglePicker(_ app: PickerApp) {
        if pickerSelection.contains(app.id) {
            pickerSelection.remove(app.id)
        } else {
            pickerSelection.insert(app.id)
        }
    }

    func selectAllPicker() { pickerSelection.formUnion(filteredPickerApps.map(\.id)) }
    func deselectAllPicker() { pickerSelection.subtract(filteredPickerApps.map(\.id)) }

    func reviewPickerSelection() {
        let chosen = pickerSelectedApps.map(\.target)
        guard !chosen.isEmpty else { return }
        startReview(chosen, fromPicker: true)
    }

    func startReview(_ newTargets: [UninstallTarget], fromPicker: Bool) {
        guard phase != .removing else { return }
        scanTask?.cancel()
        targets = newTargets
        cameFromPicker = fromPicker
        items = []
        selected = []
        collapsed = []
        confirmation = nil
        errorMessage = nil
        screen = .review
        phase = .scanning
        refreshRunningState()
        scanTask = Task { [weak self] in
            let found = await AppUninstaller.scan(targets: newTargets)
            guard let self, !Task.isCancelled else { return }
            self.items = found
            self.selected = Set(found.map(\.id))
            self.phase = .ready
        }
    }

    func bundles(for target: UninstallTarget) -> [URL] {
        var urls = [target.bundleURL]
        for item in items where item.targetID == target.id && item.category == .application && !urls.contains(item.url) {
            urls.append(item.url)
        }
        return urls
    }

    func refreshRunningState() {
        if screen == .review {
            runningIDs = Set(targets.filter { AppUninstaller.isRunning($0, bundles: bundles(for: $0)) }.map(\.id))
        } else {
            let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.isTerminated ? nil : $0.bundleIdentifier?.lowercased() })
            runningIDs = Set(pickerApps.map(\.id).filter { running.contains($0) })
        }
    }

    var runningTargets: [UninstallTarget] { targets.filter { runningIDs.contains($0.id) } }

    var groups: [LeftoverGroup] { LeftoverGroup.grouped(items, targets: targets) }

    var title: String {
        switch screen {
        case .picker:
            return "Uninstall Apps"
        case .review:
            return targets.count == 1 ? "Uninstall \(targets[0].name)" : "Uninstall \(targets.count) Apps"
        }
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var totalFiles: Int { items.reduce(0) { $0 + $1.fileCount } }
    var selectedItems: [LeftoverItem] { items.filter { selected.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var selectedFiles: Int { selectedItems.reduce(0) { $0 + $1.fileCount } }

    func groupState(_ group: LeftoverGroup) -> (all: Bool, some: Bool) {
        let count = group.items.filter { selected.contains($0.id) }.count
        return (count == group.items.count && count > 0, count > 0 && count < group.items.count)
    }

    func toggleGroup(_ group: LeftoverGroup) {
        let ids = group.items.map(\.id)
        if groupState(group).all {
            selected.subtract(ids)
        } else {
            selected.formUnion(ids)
        }
    }

    func toggle(_ item: LeftoverItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    func toggleCollapsed(_ group: LeftoverGroup) {
        if collapsed.contains(group.id) {
            collapsed.remove(group.id)
        } else {
            collapsed.insert(group.id)
        }
    }

    var allSelected: Bool { !items.isEmpty && selected.count == items.count }
    var pickerAllSelected: Bool {
        let visible = filteredPickerApps
        return !visible.isEmpty && visible.allSatisfy { pickerSelection.contains($0.id) }
    }
    var pickerNoneSelected: Bool { !filteredPickerApps.contains { pickerSelection.contains($0.id) } }

    var searchLocationCount: Int {
        AppUninstaller.searchRoots(
            home: FileManager.default.homeDirectoryForCurrentUser,
            temporaryDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        ).count * max(targets.count, 1)
    }

    func selectAll() { selected = Set(items.map(\.id)) }
    func deselectAll() { selected.removeAll() }

    func target(for item: LeftoverItem) -> UninstallTarget? {
        targets.first { $0.id == item.targetID }
    }

    func requestRemoveSelected() {
        guard phase == .ready, !selected.isEmpty else { return }
        refreshRunningState()
        confirmation = .removeSelected
    }

    func requestRemove(_ item: LeftoverItem) {
        guard phase == .ready else { return }
        refreshRunningState()
        confirmation = .removeItem(item)
    }

    func confirm() {
        guard let pending = confirmation else { return }
        confirmation = nil
        switch pending {
        case .removeSelected:
            Task { await removeSelected() }
        case let .removeItem(item):
            Task { await remove(item) }
        }
    }

    var confirmationTitle: String {
        switch confirmation {
        case .removeSelected:
            return targets.count > 1 ? "Uninstall \(targets.count) Apps?" : "Remove \(Self.formatFiles(selectedFiles).capitalized)?"
        case let .removeItem(item):
            return "Remove \u{201C}\(item.name)\u{201D}?"
        case nil:
            return ""
        }
    }

    var confirmationSubtitle: String {
        switch confirmation {
        case .removeSelected:
            let size = "\(Self.formatFiles(selectedFiles)) (\(Self.formatBytes(selectedBytes))) will be permanently deleted. This can't be undone."
            let running = runningTargets.filter { target in selectedItems.contains { $0.targetID == target.id } }
            guard !running.isEmpty else { return size }
            let names = running.count == 1 ? running[0].name : "\(running.count) running apps"
            return "\(names) will be force quit without saving. \(size)"
        case let .removeItem(item):
            if item.category == .application, let target = target(for: item), runningIDs.contains(target.id) {
                return "\(target.name) will be force quit without saving, then permanently deleted. This can't be undone."
            }
            return "It will be permanently deleted (\(Self.formatBytes(item.bytes))). This can't be undone."
        case nil:
            return ""
        }
    }

    private func removeSelected() async {
        let chosen = selectedItems
        guard !chosen.isEmpty, phase == .ready else { return }
        errorMessage = nil
        phase = .removing
        let outcome = await performRemoval(chosen, forceQuitAll: true)
        phase = .finished(trashed: outcome.trashed.count, failed: outcome.failed)
        refreshAfterRemoval()
    }

    private func remove(_ item: LeftoverItem) async {
        guard phase == .ready else { return }
        errorMessage = nil
        phase = .removing
        let outcome = await performRemoval([item], forceQuitAll: false)
        let trashedPaths = Set(outcome.trashed.map(\.path))
        items.removeAll { trashedPaths.contains($0.url.path) }
        selected = selected.filter { id in items.contains { $0.id == id } }
        if let failure = outcome.failed.first {
            errorMessage = "Couldn't remove \(failure.url.lastPathComponent): \(failure.message)"
        }
        phase = .ready
        refreshRunningState()
        if item.category == .application { refreshAfterRemoval() }
    }

    private func performRemoval(_ chosen: [LeftoverItem], forceQuitAll: Bool) async -> AppUninstaller.RemovalResult {
        var outcome = AppUninstaller.RemovalResult()
        for target in targets {
            let owned = chosen.filter { $0.targetID == target.id }
            guard !owned.isEmpty else { continue }
            let needsQuit = forceQuitAll || owned.contains { $0.category == .application }
            if needsQuit {
                let quit = await AppUninstaller.forceQuit(target, bundles: bundles(for: target))
                guard quit else {
                    outcome.failed.append(contentsOf: owned.map {
                        AppUninstaller.RemovalFailure(url: $0.url, message: "\(target.name) couldn't be force quit")
                    })
                    continue
                }
            }
            let result = await AppUninstaller.removePermanently(owned.map(\.url))
            outcome.trashed.append(contentsOf: result.trashed)
            outcome.failed.append(contentsOf: result.failed)
        }
        return outcome
    }

    private func refreshAfterRemoval() {
        let removed = Set(targets.map(\.id))
        pickerSelection.subtract(removed)
        loadApps(forceRefresh: true)
        Task { await AppListViewModel.shared.refresh(force: true) }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func formatFiles(_ count: Int) -> String {
        count == 1 ? "1 file" : "\(count.formatted()) files"
    }
}
