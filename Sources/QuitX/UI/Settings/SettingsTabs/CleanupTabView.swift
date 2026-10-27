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
    @Published private(set) var items: [CleanupItem] = []
    @Published var selected: Set<String> = []
    @Published var confirmationShown = false
    @Published var errorMessage: String?
    @Published var resultMessage: String?
    private var task: Task<Void, Never>?

    init(category: CleanupCategory) {
        self.category = category
    }

    deinit {
        task?.cancel()
    }

    var selectedItems: [CleanupItem] { items.filter { selected.contains($0.id) } }
    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var allSelected: Bool { !items.isEmpty && selected.count == items.count }

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
            phase = .ready
        }
    }

    func toggle(_ item: CleanupItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    func selectAll() { selected = Set(items.map(\.id)) }
    func deselectAll() { selected.removeAll() }

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
                errorMessage = "\(result.failed.count) \(result.failed.count == 1 ? "item couldn't" : "items couldn't") be removed."
            }
            phase = .ready
        }
    }
}

struct CleanupTabView: View {
    let category: CleanupCategory
    @ObservedObject private var model: CleanupViewModel

    init(model: CleanupViewModel) {
        category = model.category
        self.model = model
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                summaryCard
                    .padding(.bottom, 12)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.phase == .ready, !model.items.isEmpty {
                    Divider()
                    footer
                        .padding(.vertical, 12)
                }
            }

            if model.phase == .removing {
                Color(NSColor.windowBackgroundColor).opacity(0.72)
                VStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Removing selected files permanently…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
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
        .onAppear {
            if model.phase == .idle { model.scan() }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(category.tint)
                .frame(width: 38, height: 38)
                .background(category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text(category.detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if model.phase == .ready {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(model.totalBytes))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                    Text("\(model.items.count) \(model.items.count == 1 ? "item" : "items")")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Button(model.phase == .idle ? "Scan" : "Scan Again") { model.scan() }
                .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: model.phase != .scanning))
                .disabled(model.phase == .scanning || model.phase == .removing)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 11).fill(QuitXTheme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.07), lineWidth: 0.5))
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
                    detail: model.resultMessage ?? "No removable items were found in this category.",
                    tint: Color(nsColor: .systemGreen),
                    actionTitle: "Scan Again",
                    action: model.scan
                )
            } else {
                itemList
            }
        }
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.items) { item in
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
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: .systemRed))
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
                    .disabled(model.selected.isEmpty)
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
