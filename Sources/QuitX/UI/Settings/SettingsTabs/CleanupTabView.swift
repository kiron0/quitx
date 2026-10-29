import AppKit
import SwiftUI

@MainActor
final class CleanupViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case removing
    }

    let category: CleanupCategory
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var items: [CleanupItem] = [] {
        didSet { refilter() }
    }
    @Published var selected: Set<String> = []
    @Published var confirmationShown = false
    @Published var errorMessage: String?
    @Published var resultMessage: String?
    private var task: Task<Void, Never>?
    private(set) var scannedAt: Date?

    init(category: CleanupCategory) {
        self.category = category
    }

    deinit {
        task?.cancel()
    }

    var selectedItems: [CleanupItem] { items.filter { selected.contains($0.id) } }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }

    func scan() {
        guard phase != .removing else { return }
        task?.cancel()
        phase = .scanning
        errorMessage = nil
        resultMessage = nil
        task = Task { [weak self] in
            guard let self else { return }
            let found = await CleanupService.scan(category)
            guard !Task.isCancelled else { return }
            items = found
            selected = Set(found.filter(\.isSelectedByDefault).map(\.id))
            scannedAt = Date()
            phase = .ready
        }
    }

    func refreshIfStale(now: Date = Date()) {
        switch phase {
        case .idle:
            scan()
        case .ready:
            guard !confirmationShown else { return }
            let maxAge: TimeInterval = category == .trashBins ? 0 : 60
            if let scannedAt, now.timeIntervalSince(scannedAt) < maxAge { return }
            scan()
        case .scanning, .removing:
            return
        }
    }

    func toggle(_ item: CleanupItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    @Published var searchText: String = "" {
        didSet { if searchText != oldValue { refilter() } }
    }
    @Published var sizeFilter: ItemSizeFilter = .any {
        didSet { if sizeFilter != oldValue { refilter() } }
    }
    @Published var ageFilter: ItemAgeFilter = .any {
        didSet { if ageFilter != oldValue { refilter() } }
    }
    @Published var sortOrder: ItemSortOrder = .largest {
        didSet { if sortOrder != oldValue { refilter() } }
    }
    @Published private(set) var filteredItems: [CleanupItem] = []

    private func refilter() {
        filteredItems = ItemFilterHelper.filterAndSort(
            items: items,
            query: searchText,
            size: sizeFilter,
            age: ageFilter,
            sort: sortOrder
        )
    }

    var isFiltered: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sizeFilter != .any
            || ageFilter != .any
    }

    var allSelected: Bool {
        let visible = filteredItems
        return !visible.isEmpty && visible.allSatisfy { selected.contains($0.id) }
    }
    var noneSelected: Bool {
        !filteredItems.contains { selected.contains($0.id) }
    }

    func selectAll() { selected.formUnion(filteredItems.map(\.id)) }
    func deselectAll() { selected.subtract(filteredItems.map(\.id)) }

    func resetFilters() {
        searchText = ""
        sizeFilter = .any
        ageFilter = .any
        sortOrder = .largest
    }

    func requestRemoval() {
        guard phase == .ready, !selected.isEmpty else { return }
        confirmationShown = true
    }

    func removeSelected() {
        guard phase == .ready, !selectedItems.isEmpty else { return }
        confirmationShown = false
        phase = .removing
        errorMessage = nil
        let chosen = selectedItems
        task = Task { [weak self] in
            guard let self else { return }
            let result = await AppUninstaller.removePermanently(chosen.map(\.url))
            guard !Task.isCancelled else { return }
            let removedPaths = Set(result.trashed.map { $0.standardizedFileURL.path })
            items.removeAll { removedPaths.contains($0.id) }
            selected.subtract(removedPaths)
            if result.failed.isEmpty {
                resultMessage = "Permanently removed \(result.trashed.count) \(result.trashed.count == 1 ? "item" : "items")."
            } else {
                let hasFDAIssue = result.failed.contains { $0.message.contains("Full Disk Access") } || (!FullDiskAccessManager.checkFullDiskAccess() && (category == .mailFiles || category == .systemJunk))
                if hasFDAIssue {
                    errorMessage = "\(result.failed.count) \(result.failed.count == 1 ? "item couldn't" : "items couldn't") be removed. Full Disk Access is required."
                } else if let first = result.failed.first, result.failed.count == 1 {
                    errorMessage = "\(first.url.lastPathComponent): \(first.message)"
                } else {
                    errorMessage = "\(result.failed.count) items couldn't be removed."
                }
            }
            phase = .ready
        }
    }
}

struct CleanupTabView: View {
    let category: CleanupCategory
    @ObservedObject private var model: CleanupViewModel
    @ObservedObject private var fdaManager = FullDiskAccessManager.shared

    init(model: CleanupViewModel) {
        category = model.category
        self.model = model
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if category.needsFullDiskAccess && !fdaManager.hasFullDiskAccess {
                    fullDiskAccessBanner
                        .padding(.bottom, 12)
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.phase == .ready, !model.items.isEmpty {
                    Divider()
                    footer
                        .padding(.vertical, 12)
                }
            }

            if model.phase == .removing {
                QuitProgressOverlay(
                    title: "Removing Selected Files…",
                    subtitle: "Permanently deleting \(model.selectedItems.count) \(model.selectedItems.count == 1 ? "item" : "items") (\(formatBytes(model.selectedBytes)))",
                    style: .settings,
                    cardWidth: 320
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if model.confirmationShown {
                QuitConfirmationOverlay(
                    title: "Permanently remove selected files?",
                    subtitle: "\(model.selectedItems.count) items (\(formatBytes(model.selectedBytes))) will be deleted immediately. This can't be undone.",
                    confirmTitle: "Delete Permanently",
                    systemImage: "trash.fill",
                    isForced: true,
                    style: .settings,
                    cardWidth: 330,
                    onConfirm: { model.removeSelected() },
                    onCancel: { model.confirmationShown = false }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.18), value: model.confirmationShown)
        .animation(.easeInOut(duration: 0.18), value: model.phase == .removing)
        .onAppear {
            model.refreshIfStale()
        }
    }

    private var fullDiskAccessBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(category == .trashBins ? "Full Disk Access Required to See the Trash" : "Full Disk Access Required to Clean Mail Files")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(category == .trashBins ? "macOS hides Trash contents from apps without Full Disk Access." : "macOS requires Full Disk Access permission to remove protected mail attachments.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Grant Access") {
                FullDiskAccessManager.shared.openSettingsAndReveal()
            }
            .buttonStyle(UninstallSecondaryButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 0.8))
    }



    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            emptyState(
                symbol: category.symbol,
                title: "Ready to Scan",
                detail: "QuitX scans locally and shows every item before removing anything.",
                tint: category.tint,
                actionTitle: "Scan \(category.rawValue)",
                action: model.scan
            )
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning \(category.rawValue.lowercased())…")
                    .font(.system(size: 12, weight: .medium))
                Text("Large folders may take a moment.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready, .removing:
            if model.items.isEmpty {
                emptyState(
                    symbol: "checkmark.circle.fill",
                    title: model.resultMessage == nil ? "Nothing to Clean" : "Cleanup Complete",
                    detail: model.resultMessage ?? (category.needsFullDiskAccess && !fdaManager.hasFullDiskAccess
                        ? "QuitX can't look inside this location until you grant Full Disk Access."
                        : "No removable items were found in this category."),
                    tint: Color(nsColor: .systemGreen),
                    actionTitle: "Scan Again",
                    action: model.scan
                )
            } else {
                VStack(spacing: 6) {
                    CleanupFilterBar(
                        query: $model.searchText,
                        size: $model.sizeFilter,
                        age: $model.ageFilter,
                        sort: $model.sortOrder,
                        visibleCount: model.filteredItems.count,
                        totalCount: model.items.count,
                        isFiltered: model.isFiltered,
                        onReset: model.resetFilters
                    )

                    if model.filteredItems.isEmpty {
                        emptyState(
                            symbol: "line.3.horizontal.decrease.circle",
                            title: "No Matching Files",
                            detail: "Try another search term, size threshold, or modified date range.",
                            tint: category.tint,
                            actionTitle: "Reset Filters",
                            action: model.resetFilters
                        )
                    } else {
                        itemList
                    }
                }
            }
        }
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.filteredItems) { item in
                    cleanupRow(item)
                    Divider().padding(.leading, 54)
                }
            }
        }
    }

    private func cleanupRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 10) {
            Button { model.toggle(item) } label: {
                QuitXSelectionCheckbox(isSelected: model.selected.contains(item.id))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.name)")
            .accessibilityValue(model.selected.contains(item.id) ? "Selected" : "Not selected")

            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(item.isDirectory ? category.tint : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(displayPath(item.url))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if !item.isSelectedByDefault {
                Text("Review")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }

            if let date = item.lastModified {
                Text(date, style: .date)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }

            Text(formatBytes(item.bytes))
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 62, alignment: .trailing)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal \(item.name) in Finder")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(item) }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = model.errorMessage {
                HStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(nsColor: .systemRed))
                    if !fdaManager.hasFullDiskAccess {
                        Button("Grant Access") {
                            FullDiskAccessManager.shared.openSettingsAndReveal()
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .buttonStyle(.link)
                    }
                }
            } else if let message = model.resultMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: .systemGreen))
            }
            HStack(spacing: 8) {
                Button("Select All") { model.selectAll() }
                    .buttonStyle(UninstallSecondaryButtonStyle())
                    .disabled(model.allSelected)
                Button("Deselect All") { model.deselectAll() }
                    .buttonStyle(UninstallSecondaryButtonStyle())
                    .disabled(model.noneSelected)
                Spacer()
                Button {
                    model.requestRemoval()
                } label: {
                    Label(
                        model.selected.isEmpty
                            ? "Delete Permanently"
                            : "Delete \(model.selected.count) (\(formatBytes(model.selectedBytes)))",
                        systemImage: "trash.fill"
                    )
                    .monospacedDigit()
                }
                .buttonStyle(UninstallDestructiveButtonStyle(isEnabled: !model.selected.isEmpty))
                .disabled(model.selected.isEmpty)
            }
        }
    }

    private func emptyState(
        symbol: String,
        title: String,
        detail: String,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 11) {
            Spacer()
            ZStack {
                Circle().fill(tint.opacity(0.10)).frame(width: 82, height: 82)
                Circle().stroke(tint.opacity(0.16), lineWidth: 1).frame(width: 82, height: 82)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button(actionTitle, action: action)
                .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: true))
                .padding(.top, 3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home + "/") ? "~" + String(url.path.dropFirst(home.count)) : url.path
    }
}

private extension CleanupCategory {
    var needsFullDiskAccess: Bool {
        self == .mailFiles || self == .trashBins
    }

    var symbol: String {
        switch self {
        case .systemJunk: return "gearshape.2"
        case .userCache: return "internaldrive"
        case .mailFiles: return "envelope"
        case .trashBins: return "trash"
        case .largeOldFiles: return "clock"
        case .aiApps: return "cpu"
        case .xcodeJunk: return "hammer"
        case .brewCache: return "mug"
        case .nodeCache: return "leaf"
        case .dockerCache: return "shippingbox"
        }
    }

    var tint: Color {
        switch self {
        case .systemJunk: return Color(nsColor: .systemOrange)
        case .userCache: return Color(nsColor: .systemBlue)
        case .mailFiles: return Color(nsColor: .systemIndigo)
        case .trashBins: return Color(nsColor: .systemRed)
        case .largeOldFiles: return Color(nsColor: .systemYellow)
        case .aiApps: return Color(nsColor: .systemPurple)
        case .xcodeJunk: return Color(nsColor: .systemBlue)
        case .brewCache: return Color(nsColor: .systemBrown)
        case .nodeCache: return Color(nsColor: .systemGreen)
        case .dockerCache: return Color(nsColor: .systemCyan)
        }
    }

    var detail: String {
        switch self {
        case .systemJunk: return "System caches, logs and temporary files."
        case .userCache: return "Regenerable cache data created by apps."
        case .mailFiles: return "Downloaded attachments stored by Mail."
        case .trashBins: return "Items already in your user Trash."
        case .largeOldFiles: return "Files over 100 MB or old files over 10 MB. Nothing starts selected."
        case .aiApps: return "Ollama and LM Studio caches, logs and optional history."
        case .xcodeJunk: return "DerivedData, archives, device support and simulator caches."
        case .brewCache: return "Homebrew downloads and logs."
        case .nodeCache: return "npm, Yarn and pnpm package caches."
        case .dockerCache: return "Docker Desktop caches and logs. Images, containers and volumes stay untouched."
        }
    }
}
