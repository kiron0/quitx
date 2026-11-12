import AppKit
import SwiftUI

struct DefaultAppsChooserRequest {
    let title: String
    let subtitle: String
    let suggested: [HandlerApp]
    let current: HandlerApp?
    let confirmTitle: String
    let onChoose: @MainActor (HandlerApp) -> Void
}

struct DefaultAppsChooserItem: Identifiable, Hashable, Sendable {
    let app: HandlerApp
    let isSuggested: Bool
    let isCurrent: Bool

    var id: String { app.bundleID?.lowercased() ?? app.id }
}

@MainActor
final class DefaultAppsChooserModel: ObservableObject {
    @Published private(set) var items: [DefaultAppsChooserItem] = []
    @Published private(set) var isLoading = true
    @Published var query = ""
    @Published var selectedID: String?

    let request: DefaultAppsChooserRequest
    private var loadTask: Task<Void, Never>?

    init(request: DefaultAppsChooserRequest) {
        self.request = request
        self.items = Self.merge(installed: [], request: request)
        self.selectedID = items.first(where: \.isCurrent)?.id
    }

    deinit {
        loadTask?.cancel()
    }

    var suggestedItems: [DefaultAppsChooserItem] {
        filtered.filter(\.isSuggested)
    }

    var otherItems: [DefaultAppsChooserItem] {
        filtered.filter { !$0.isSuggested }
    }

    var visibleItems: [DefaultAppsChooserItem] {
        suggestedItems + otherItems
    }

    var selectedItem: DefaultAppsChooserItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    private var filtered: [DefaultAppsChooserItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            item.app.name.localizedCaseInsensitiveContains(trimmed)
                || (item.app.bundleID?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    func load() {
        guard loadTask == nil else { return }
        isLoading = true
        let running = InstalledApplicationScanner.runningApplicationInfos()
        let request = request
        loadTask = Task { [weak self] in
            let installed = await Self.scanInstalled(running: running)
            guard let self, !Task.isCancelled else { return }
            self.items = Self.merge(installed: installed, request: request)
            if self.selectedID == nil || !self.items.contains(where: { $0.id == self.selectedID }) {
                self.selectedID = self.items.first(where: \.isCurrent)?.id
            }
            self.isLoading = false
        }
    }

    func moveSelection(by offset: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        let index = visible.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : visible.count)
        let next = min(max(index + offset, 0), visible.count - 1)
        selectedID = visible[next].id
    }

    func selectFirstMatchIfNeeded() {
        let visible = visibleItems
        if let selectedID, visible.contains(where: { $0.id == selectedID }) { return }
        selectedID = visible.first?.id
    }

    nonisolated static func scanInstalled(running: [InstalledApplicationScanner.RunningApplicationInfo]) async -> [HandlerApp] {
        InstalledApplicationScanner.scan(runningApplications: running)
            .filter { !$0.isBackground && $0.url.pathExtension.lowercased() == "app" }
            .map { HandlerApp(url: $0.url, bundleID: $0.bundleIdentifier, name: $0.name) }
    }

    static func merge(installed: [HandlerApp], request: DefaultAppsChooserRequest) -> [DefaultAppsChooserItem] {
        var byKey: [String: DefaultAppsChooserItem] = [:]
        func key(_ app: HandlerApp) -> String { app.bundleID?.lowercased() ?? app.id }
        let suggestedKeys = Set(request.suggested.map(key))
        for app in request.suggested + installed + (request.current.map { [$0] } ?? []) {
            let k = key(app)
            if byKey[k] != nil { continue }
            byKey[k] = DefaultAppsChooserItem(
                app: app,
                isSuggested: suggestedKeys.contains(k),
                isCurrent: app.matches(request.current)
            )
        }
        return byKey.values.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent }
            return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
        }
    }
}

@MainActor
final class DefaultAppsAppChooserWindowController: NSObject, NSWindowDelegate {
    static let shared = DefaultAppsAppChooserWindowController()
    static let size = NSSize(width: 520, height: 580)

    private(set) var window: NSWindow?

    var isOpen: Bool { window != nil }

    func present(_ request: DefaultAppsChooserRequest) {
        window?.close()

        let model = DefaultAppsChooserModel(request: request)
        let view = DefaultAppsAppChooserView(
            model: model,
            onChoose: { [weak self] app in
                self?.close()
                request.onChoose(app)
            },
            onBrowse: { [weak self] in
                guard let app = DefaultAppsModel.browseForApp(prompt: request.confirmTitle) else { return }
                self?.close()
                request.onChoose(app)
            },
            onCancel: { [weak self] in self?.close() }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = request.title
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(Self.size)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.animationBehavior = .none
        window.delegate = self

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }

        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: targetFrame)
        model.load()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}

struct DefaultAppsAppChooserView: View {
    @ObservedObject var model: DefaultAppsChooserModel
    let onChoose: (HandlerApp) -> Void
    let onBrowse: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            searchField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Group {
                if model.visibleItems.isEmpty && !model.isLoading {
                    emptyView
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
            .padding(.horizontal, 16)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle()).ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground.ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onChange(of: model.query) { _, _ in model.selectFirstMatchIfNeeded() }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(model.request.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(model.request.subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 60)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(QuitXTheme.paneBackground)
    }

    private var searchField: some View {
        QuitXSearchField(
            placeholder: "Search apps",
            text: $model.query,
            disableInitialFocus: false,
            onSubmit: {
                if let item = model.selectedItem { onChoose(item.app) }
            },
            onMoveDown: { model.moveSelection(by: 1) },
            onMoveUp: { model.moveSelection(by: -1) }
        )
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let suggested = model.suggestedItems
                    if !suggested.isEmpty {
                        sectionHeader("Suggested", count: suggested.count, detail: "Says it can open this")
                        rows(suggested)
                    }
                    sectionHeader(suggested.isEmpty ? "Applications" : "All Other Apps", count: model.otherItems.count, detail: nil)
                    rows(model.otherItems)
                    if model.isLoading {
                        QuitXLoadingView(text: "Finding installed apps…")
                            .frame(minHeight: 180)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .onChange(of: model.selectedID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) }
            }
        }
    }

    private func rows(_ items: [DefaultAppsChooserItem]) -> some View {
        ForEach(items) { item in
            DefaultAppsChooserRow(item: item, isSelected: model.selectedID == item.id)
                .id(item.id)
                .onTapGesture(count: 2) { onChoose(item.app) }
                .onTapGesture { model.selectedID = item.id }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onChoose(item.app) }
        }
    }

    private func sectionHeader(_ title: String, count: Int, detail: String?) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(QuitXTheme.accent)
            Text("No matching apps")
                .font(.system(size: 13, weight: .medium))
            Text("Try another name, or use Browse… for an app outside the Applications folders.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = model.selectedItem, !item.isSuggested, !model.request.suggested.isEmpty {
                Label("\(item.app.name) doesn't say it can open this. macOS will still use it, but files may not open correctly.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Browse…", action: onBrowse)
                    .help("Choose an app from anywhere on this Mac")
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(model.request.confirmTitle) {
                    if let item = model.selectedItem { onChoose(item.app) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.selectedItem == nil)
            }
            .font(.system(size: 11.5))
        }
    }
}

private struct DefaultAppsChooserRow: View {
    let item: DefaultAppsChooserItem
    let isSelected: Bool
    @StateObject private var hover = DefaultAppsChooserRowHover()

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(bundleId: item.app.bundleID, url: item.app.url, size: 24, cornerRadius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.app.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.88) : Color.primary)
                    .lineLimit(1)
                Text(item.app.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.6) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if item.isCurrent {
                Text("Current")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : QuitXTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isSelected ? Color.black : QuitXTheme.accent).opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? QuitXTheme.accent : (hover.isHovered ? Color.primary.opacity(0.07) : Color.clear))
        )
        .onHover { hover.isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.app.name)\(item.isCurrent ? ", current" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private final class DefaultAppsChooserRowHover: ObservableObject {
    @Published var isHovered = false
}
