import AppKit
import SwiftUI

private final class UninstallHoverState: ObservableObject {
    @Published var itemID: String?
    @Published var button: String?
}

private final class ScanPulseState: ObservableObject {
    @Published var pulse = false
}

private struct ScanPulse: View {
    @StateObject private var state = ScanPulseState()
    private let tint = Color(nsColor: .systemBlue)

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .scaleEffect(state.pulse ? 1.8 : 1.0)
                    .opacity(state.pulse ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.7),
                        value: state.pulse
                    )
            }
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 80, height: 80)
        .onAppear { state.pulse = true }
    }
}

struct UninstallView: View {
    @ObservedObject var model: UninstallViewModel
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onDismiss: () -> Void

    @StateObject private var hover = UninstallHoverState()

    var body: some View {
        VStack(spacing: 0) {
            Text(model.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 80)
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            switch model.screen {
            case .picker:
                picker
            case .review:
                review
            }
        }
        .frame(minWidth: 560, minHeight: 460)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if model.confirmation != nil {
                QuitConfirmationOverlay(
                    title: model.confirmationTitle,
                    subtitle: model.confirmationSubtitle,
                    confirmTitle: model.targets.count > 1 && model.confirmation == .removeSelected ? "Uninstall" : "Remove",
                    systemImage: "trash.fill",
                    isForced: true,
                    cardWidth: 300,
                    onConfirm: { withAnimation(.easeInOut(duration: 0.15)) { model.confirm() } },
                    onCancel: { withAnimation(.easeInOut(duration: 0.15)) { model.confirmation = nil } }
                )
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
    }

    private var picker: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)

            Group {
                if model.isLoadingApps && model.pickerApps.isEmpty {
                    loading("Finding installed apps…", detail: nil)
                } else if model.filteredPickerApps.isEmpty {
                    Text(model.searchText.isEmpty ? "No apps can be uninstalled." : "No apps match \u{201C}\(model.searchText)\u{201D}.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.filteredPickerApps) { app in
                                pickerRow(app)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 8) {
                Button("Select All") { model.selectAllPicker() }
                    .buttonStyle(UninstallSecondaryButtonStyle())
                    .disabled(model.pickerAllSelected)
                Button("Deselect All") { model.deselectAllPicker() }
                    .buttonStyle(UninstallSecondaryButtonStyle())
                    .disabled(model.pickerNoneSelected)
                Spacer(minLength: 8)
                let count = model.pickerSelection.count
                Button {
                    model.reviewPickerSelection()
                } label: {
                    Text(count == 0
                         ? "Choose Apps to Uninstall"
                         : "Review \(count) \(count == 1 ? "App" : "Apps") (\(UninstallViewModel.formatBytes(model.pickerSelectedBytes)))")
                        .monospacedDigit()
                }
                .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: count > 0))
                .disabled(count == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search apps", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .disableInitialFocus()
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(SearchFieldGlassBackground(isFocused: !model.searchText.isEmpty))
    }

    private func pickerRow(_ app: UninstallViewModel.PickerApp) -> some View {
        let isSelected = model.pickerSelection.contains(app.id)
        return HStack(spacing: 10) {
            QuitXSelectionCheckbox(isSelected: isSelected)

            Image(nsImage: model.icon(for: app.target))
                .resizable()
                .interpolation(.high)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(app.target.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                    if model.runningIDs.contains(app.id) {
                        tag("Running")
                    }
                    if app.isBackground {
                        tag("Menu Bar")
                    }
                }
                Text(displayPath(app.target.bundleURL.deletingLastPathComponent()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(model.bundleSizes[app.id].map(UninstallViewModel.formatBytes) ?? "—")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? QuitXTheme.accent.opacity(0.10) : (hover.itemID == app.id ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { model.togglePicker(app) }
        .onHover { hover.itemID = $0 ? app.id : (hover.itemID == app.id ? nil : hover.itemID) }
        .contextMenu {
            Button("Uninstall \(app.target.name)…") { model.startReview([app.target], fromPicker: true) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.target.bundleURL]) }
        }
        .help(app.target.bundleURL.path)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)))
    }

    private var review: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)

            reviewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            reviewFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            headerIcons

            VStack(alignment: .leading, spacing: 2) {
                Text(model.targets.count == 1 ? model.targets[0].name : "\(model.targets.count) Apps")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(model.targets.count == 1 ? model.targets[0].bundleIdentifier : model.targets.map(\.name).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            if model.phase != .scanning {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UninstallViewModel.formatBytes(model.totalBytes))
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                    Text(UninstallViewModel.formatFiles(model.totalFiles))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(QuitXTheme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
    }

    private var headerIcons: some View {
        let shown = Array(model.targets.prefix(3))
        return ZStack(alignment: .leading) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, target in
                Image(nsImage: model.icon(for: target))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: shown.count == 1 ? 44 : 36, height: shown.count == 1 ? 44 : 36)
                    .offset(x: CGFloat(index) * 16)
                    .zIndex(Double(shown.count - index))
            }
        }
        .frame(width: shown.count == 1 ? 44 : 36 + CGFloat(max(shown.count - 1, 0)) * 16, height: 44, alignment: .leading)
    }

    @ViewBuilder
    private var reviewContent: some View {
        switch model.phase {
        case .scanning:
            loading("Scanning for related files…", detail: "Checking \(model.searchLocationCount) locations")
        case .ready, .removing:
            leftoverList
                .overlay {
                    if model.phase == .removing {
                        ZStack {
                            Color(NSColor.windowBackgroundColor).opacity(0.7)
                            VStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(model.runningTargets.isEmpty ? "Moving files to the Trash…" : "Force quitting and moving files to the Trash…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
        case let .finished(trashed, failed):
            finished(trashed: trashed, failed: failed)
        }
    }

    private func loading(_ text: String, detail: String?) -> some View {
        VStack(spacing: 14) {
            Spacer()
            if reduceMotion {
                ProgressView(text)
            } else {
                ScanPulse()
                Text(text)
                    .font(.system(size: 13, weight: .medium))
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rowDivider(leading: CGFloat) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
            .padding(.leading, leading)
    }

    private var leftoverList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.groups) { group in
                    groupHeader(group)
                    if !model.collapsed.contains(group.id) {
                        ForEach(group.items) { item in
                            itemRow(item, showsCategory: model.targets.count > 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func groupHeader(_ group: LeftoverGroup) -> some View {
        let state = model.groupState(group)
        let isRunningApp: Bool
        if case let .app(target) = group.kind {
            isRunningApp = model.runningIDs.contains(target.id)
        } else {
            isRunningApp = false
        }
        return HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(model.collapsed.contains(group.id) ? 0 : 90))
                .frame(width: 14, height: 14)

            Button { model.toggleGroup(group) } label: {
                QuitXSelectionCheckbox(isSelected: state.all, isPartial: state.some)
            }
            .buttonStyle(.plain)
            .disabled(model.phase != .ready)

            groupIcon(group)

            Text(group.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Text("\(group.items.count)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))

            if isRunningApp {
                tag("Running")
            }

            Spacer(minLength: 8)

            Text(UninstallViewModel.formatBytes(group.bytes))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { rowDivider(leading: 74) }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { model.toggleCollapsed(group) }
        }
    }

    @ViewBuilder
    private func groupIcon(_ group: LeftoverGroup) -> some View {
        switch group.kind {
        case let .category(category):
            Image(systemName: category.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: category.tint)))
        case let .app(target):
            Image(nsImage: model.icon(for: target))
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
        }
    }

    private func itemRow(_ item: LeftoverItem, showsCategory: Bool) -> some View {
        let isHovered = hover.itemID == item.id
        return HStack(spacing: 8) {
            Button { model.toggle(item) } label: {
                QuitXSelectionCheckbox(isSelected: model.selected.contains(item.id))
            }
            .buttonStyle(.plain)
            .disabled(model.phase != .ready)

            Group {
                if item.category == .application, let target = model.target(for: item) {
                    Image(nsImage: model.icon(for: target)).resizable()
                } else {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(item.isDirectory ? Color(nsColor: .systemBlue).opacity(0.85) : Color.secondary)
                        .padding(1)
                }
            }
            .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(showsCategory
                     ? "\(item.category.title) · \(displayPath(item.url))"
                     : displayPath(item.url))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if isHovered && model.phase == .ready {
                HStack(spacing: 2) {
                    rowAction(id: item.id + ".reveal", symbol: "folder", help: "Show in Finder", tint: .primary) {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    rowAction(id: item.id + ".trash", symbol: "trash", help: "Remove this item", tint: Color(nsColor: .systemRed)) {
                        withAnimation(.easeInOut(duration: 0.15)) { model.requestRemove(item) }
                    }
                }
                .transition(.opacity)
            }

            Text(UninstallViewModel.formatBytes(item.bytes))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 56, alignment: .trailing)
        }
        .padding(.leading, 36)
        .padding(.trailing, 4)
        .padding(.vertical, 7)
        .frame(minHeight: 40)
        .background(Rectangle().fill(isHovered ? Color.primary.opacity(0.04) : Color.clear))
        .overlay(alignment: .bottom) { rowDivider(leading: 84) }
        .contentShape(Rectangle())
        .onTapGesture { if model.phase == .ready { model.toggle(item) } }
        .onHover { hovering in
            if hovering {
                hover.itemID = item.id
            } else if hover.itemID == item.id {
                hover.itemID = nil
            }
        }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Remove…") { model.requestRemove(item) }
                .disabled(model.phase != .ready)
        }
        .help(item.url.path)
    }

    private func rowAction(id: String, symbol: String, help: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hover.button == id ? tint : Color.secondary)
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(hover.button == id ? 0.12 : 0.06)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover.button = $0 ? id : (hover.button == id ? nil : hover.button) }
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home + "/") ? "~" + String(path.dropFirst(home.count)) : path
    }

    private func finished(trashed: Int, failed: [AppUninstaller.RemovalFailure]) -> some View {
        VStack(spacing: 10) {
            Image(systemName: failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(failed.isEmpty ? Color(nsColor: .systemGreen) : QuitXTheme.accent)
            Text(failed.isEmpty
                 ? (model.targets.count == 1 ? "\(model.targets[0].name) was uninstalled" : "\(model.targets.count) apps were uninstalled")
                 : "Some items couldn't be removed")
                .font(.system(size: 14, weight: .semibold))
            Text("\(trashed) \(trashed == 1 ? "item" : "items") moved to the Trash. Empty the Trash to free the space.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if !failed.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(failed, id: \.url) { failure in
                            Text("\(displayPath(failure.url)): \(failure.message)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 140)
                .padding(.horizontal, 24)
                if failed.contains(where: { $0.url.pathExtension.lowercased() == "app" }) {
                    Text("macOS may block QuitX from removing apps. Allow it in System Settings, Privacy & Security, App Management, then try again.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Open App Management Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var reviewFooter: some View {
        switch model.phase {
        case .finished:
            HStack(spacing: 8) {
                Button("Open Trash") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
                }
                .buttonStyle(UninstallSecondaryButtonStyle())
                Spacer()
                Button("Uninstall More Apps") { model.showPicker() }
                    .buttonStyle(UninstallSecondaryButtonStyle())
                Button("Done") { onDismiss() }
                    .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: true))
                    .keyboardShortcut(.defaultAction)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .lineLimit(2)
                } else if !model.runningTargets.isEmpty && model.phase == .ready {
                    Label(runningNotice, systemImage: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if model.cameFromPicker {
                        Button {
                            model.showPicker()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(UninstallSecondaryButtonStyle())
                    }
                    Button("Select All") { model.selectAll() }
                        .buttonStyle(UninstallSecondaryButtonStyle())
                        .disabled(model.allSelected)
                    Button("Deselect All") { model.deselectAll() }
                        .buttonStyle(UninstallSecondaryButtonStyle())
                        .disabled(model.selected.isEmpty)
                    Spacer(minLength: 8)
                    removeButton
                }
                .disabled(model.phase != .ready)
            }
        }
    }

    private var runningNotice: String {
        let running = model.runningTargets
        let subject = running.count == 1 ? "\(running[0].name) is open" : "\(running.count) apps are open"
        return "\(subject). QuitX force quits before removing, so save your work first."
    }

    private var removeButton: some View {
        let enabled = model.phase == .ready && !model.selected.isEmpty
        let size = UninstallViewModel.formatBytes(model.selectedBytes)
        let title: String
        if model.selected.isEmpty {
            title = "Remove"
        } else if model.targets.count > 1 {
            title = "Uninstall \(model.targets.count) Apps (\(size))"
        } else {
            title = "Remove \(UninstallViewModel.formatFiles(model.selectedFiles)) (\(size))"
        }
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { model.requestRemoveSelected() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .monospacedDigit()
            }
        }
        .buttonStyle(UninstallDestructiveButtonStyle(isEnabled: enabled))
        .disabled(!enabled)
    }
}

struct UninstallDestructiveButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isEnabled ? Color.white : Color.primary.opacity(0.35))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isEnabled
                            ? LinearGradient(colors: [Color.red, Color(red: 210/255, green: 40/255, blue: 40/255)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .shadow(color: isEnabled ? Color.red.opacity(0.18) : Color.clear, radius: 2, y: 1)
    }
}

struct UninstallPrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.88) : Color.primary.opacity(0.35))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isEnabled
                            ? LinearGradient(colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .shadow(color: isEnabled ? QuitXTheme.accent.opacity(0.18) : Color.clear, radius: 2, y: 1)
    }
}

struct UninstallSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        UninstallSecondaryButtonBody(configuration: configuration)
    }
}

private struct UninstallSecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.55 : 0.85) : 0.3))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(isEnabled ? 0.12 : 0.06), lineWidth: 0.5)
            )
    }
}
