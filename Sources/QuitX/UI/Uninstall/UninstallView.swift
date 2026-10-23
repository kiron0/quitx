import AppKit
import SwiftUI

struct UninstallView: View {
    @ObservedObject var model: UninstallViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Uninstall \(model.target.name)")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            headerCard
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
        .ignoresSafeArea()
        .task { await model.scan() }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(nsImage: model.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.target.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(model.target.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .scanning:
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking for \(model.target.name)'s files…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        case .ready, .removing:
            list
                .overlay {
                    if model.phase == .removing {
                        ZStack {
                            Color(NSColor.windowBackgroundColor).opacity(0.7)
                            VStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(model.isAppRunning ? "Quitting \(model.target.name) and moving files to the Trash…" : "Moving files to the Trash…")
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

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.groups) { group in
                    groupHeader(group)
                    if !model.collapsed.contains(group.category) {
                        ForEach(group.items) { item in
                            itemRow(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func groupHeader(_ group: LeftoverGroup) -> some View {
        let category = group.category
        let state = model.groupState(category)
        return HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { model.toggleCollapsed(category) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(model.collapsed.contains(category) ? 0 : 90))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { model.toggleGroup(category) } label: {
                QuitXSelectionCheckbox(isSelected: state.all, isPartial: state.some)
            }
            .buttonStyle(.plain)
            .disabled(model.phase != .ready)

            Image(systemName: category.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: category.tint)))

            Text(category.title)
                .font(.system(size: 13, weight: .semibold))

            Text("\(group.items.count)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.08)))

            Spacer(minLength: 8)

            Text(UninstallViewModel.formatBytes(group.bytes))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { model.toggleCollapsed(category) }
        }
    }

    private func itemRow(_ item: LeftoverItem) -> some View {
        HStack(spacing: 8) {
            Button { model.toggle(item) } label: {
                QuitXSelectionCheckbox(isSelected: model.selected.contains(item.id))
            }
            .buttonStyle(.plain)
            .disabled(model.phase != .ready)

            Group {
                if item.category == .application {
                    Image(nsImage: model.icon).resizable()
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
                Text(displayPath(item.url.deletingLastPathComponent()))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(UninstallViewModel.formatBytes(item.bytes))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 22)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { if model.phase == .ready { model.toggle(item) } }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
        .help(item.url.path)
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
            Text(failed.isEmpty ? "\(model.target.name) was moved to the Trash" : "Some items couldn't be removed")
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
    private var footer: some View {
        switch model.phase {
        case .finished:
            HStack {
                Button("Open Trash") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                if let message = model.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .systemRed))
                } else if model.isAppRunning && model.phase == .ready {
                    Label("\(model.target.name) is open. QuitX quits it normally before removing files.", systemImage: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("Select All") { model.selectAll() }
                        .buttonStyle(.bordered)
                    Button("Deselect All") { model.deselectAll() }
                        .buttonStyle(.bordered)
                    Spacer(minLength: 8)
                    removeButton
                }
                .disabled(model.phase != .ready)
            }
        }
    }

    private var removeButton: some View {
        let enabled = model.phase == .ready && !model.selected.isEmpty
        return Button {
            Task { await model.remove() }
        } label: {
            Text(model.selected.isEmpty
                 ? "Remove"
                 : "Remove \(UninstallViewModel.formatFiles(model.selectedFiles)) (\(UninstallViewModel.formatBytes(model.selectedBytes)))")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(nsColor: .systemRed).opacity(enabled ? 1 : 0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
