import AppKit
import SwiftUI

@MainActor
final class UninstallViewModel: ObservableObject {
    enum Phase: Equatable {
        case scanning
        case ready
        case removing
        case finished(trashed: Int, failed: [AppUninstaller.RemovalFailure])
    }

    let target: UninstallTarget
    let icon: NSImage

    @Published private(set) var items: [LeftoverItem] = []
    @Published var selected: Set<String> = []
    @Published var collapsed: Set<LeftoverCategory> = []
    @Published private(set) var phase: Phase = .scanning
    @Published var errorMessage: String?
    @Published private(set) var isAppRunning = false

    init(target: UninstallTarget) {
        self.target = target
        self.icon = AppIconCache.icon(for: target.bundleIdentifier, url: target.bundleURL)
            ?? NSWorkspace.shared.icon(forFile: target.bundleURL.path)
    }

    var groups: [LeftoverGroup] {
        var result: [LeftoverGroup] = []
        for category in LeftoverCategory.allCases {
            let members = items.filter { $0.category == category }
            if !members.isEmpty {
                result.append(LeftoverGroup(category: category, items: members))
            }
        }
        return result
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var totalFiles: Int { items.reduce(0) { $0 + $1.fileCount } }
    var selectedItems: [LeftoverItem] { items.filter { selected.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var selectedFiles: Int { selectedItems.reduce(0) { $0 + $1.fileCount } }

    func scan() async {
        phase = .scanning
        errorMessage = nil
        refreshRunningState()
        let found = await AppUninstaller.scan(target: target)
        items = found
        selected = Set(found.map(\.id))
        phase = .ready
    }

    func refreshRunningState() {
        isAppRunning = !AppUninstaller.runningInstances(bundleIdentifier: target.bundleIdentifier).isEmpty
    }

    func groupState(_ category: LeftoverCategory) -> (all: Bool, some: Bool) {
        let ids = items.filter { $0.category == category }.map(\.id)
        let count = ids.filter { selected.contains($0) }.count
        return (count == ids.count && count > 0, count > 0 && count < ids.count)
    }

    func toggleGroup(_ category: LeftoverCategory) {
        let ids = items.filter { $0.category == category }.map(\.id)
        if groupState(category).all {
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

    func toggleCollapsed(_ category: LeftoverCategory) {
        if collapsed.contains(category) {
            collapsed.remove(category)
        } else {
            collapsed.insert(category)
        }
    }

    func selectAll() { selected = Set(items.map(\.id)) }
    func deselectAll() { selected.removeAll() }

    func remove() async {
        let chosen = selectedItems
        guard !chosen.isEmpty, phase == .ready else { return }
        errorMessage = nil
        phase = .removing
        let quit = await AppUninstaller.quitRunningInstances(bundleIdentifier: target.bundleIdentifier)
        guard quit else {
            refreshRunningState()
            errorMessage = "\(target.name) didn't quit. Save your work, quit it, then try again."
            phase = .ready
            return
        }
        let result = await AppUninstaller.moveToTrash(chosen.map(\.url))
        phase = .finished(trashed: result.trashed.count, failed: result.failed)
        await AppListViewModel.shared.refresh(force: true)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func formatFiles(_ count: Int) -> String {
        count == 1 ? "1 file" : "\(count.formatted()) files"
    }
}
