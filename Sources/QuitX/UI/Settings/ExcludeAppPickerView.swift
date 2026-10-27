import AppKit
import SwiftUI

struct InstalledApplication: Identifiable, Hashable, Sendable {
    let bundleIdentifier: String
    let name: String
    let url: URL
    let isBackground: Bool

    var id: String { bundleIdentifier.lowercased() }
}

enum InstalledApplicationScanner {
    struct RunningApplicationInfo: Sendable {
        let bundleIdentifier: String?
        let isTerminated: Bool
        let isBackground: Bool
        let bundleURL: URL?
        let executableURL: URL?
        let localizedName: String?
    }

    private static var cached: [InstalledApplication]?
    private static var cachedAt = Date.distantPast
    private static let cacheLifetime: TimeInterval = 300
    private static let lock = NSLock()

    @MainActor
    static func runningApplicationInfos() -> [RunningApplicationInfo] {
        NSWorkspace.shared.runningApplications.map { app in
            RunningApplicationInfo(
                bundleIdentifier: app.bundleIdentifier,
                isTerminated: app.isTerminated,
                isBackground: app.activationPolicy == .accessory,
                bundleURL: app.bundleURL,
                executableURL: app.executableURL,
                localizedName: app.localizedName
            )
        }
    }

    static func scan(forceRefresh: Bool = false, runningApplications: [RunningApplicationInfo]) -> [InstalledApplication] {
        lock.lock()

        defer { lock.unlock() }

        let cacheIsFresh = Date().timeIntervalSince(cachedAt) < cacheLifetime
        if !forceRefresh, cacheIsFresh, let cached {
            return cached
        }

        var applicationsByIdentifier: [String: InstalledApplication] = [:]
        for app in runningApplications {
            if Task.isCancelled { return [] }
            guard !app.isTerminated else { continue }
            guard let bundleIdentifier = app.bundleIdentifier else { continue }

            let isBackground = app.isBackground
            let bundleURL = app.bundleURL ?? (app.executableURL.map { URL(fileURLWithPath: $0.path) })
            let path = bundleURL?.path ?? ""

            if SystemAppProtection.isSystemProtected(bundleIdentifier: bundleIdentifier, isBackground: isBackground, path: path) {
                continue
            }

            let rawName = app.localizedName
                ?? bundleURL?.deletingPathExtension().lastPathComponent
                ?? app.executableURL?.lastPathComponent
                ?? bundleIdentifier
            let name = SystemAppProtection.cleanAppName(rawName)
            guard !name.isEmpty else { continue }

            let application = InstalledApplication(
                bundleIdentifier: bundleIdentifier,
                name: name,
                url: bundleURL ?? URL(fileURLWithPath: "/"),
                isBackground: isBackground
            )

            insertOrUpdate(application, into: &applicationsByIdentifier)
        }

        let fileManager = FileManager.default
        let searchRoots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
            URL(fileURLWithPath: "/Library/Input Methods"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        ]

        var visitedPaths = Set<String>()

        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            if Task.isCancelled { return [] }

            let rootPath = root.standardizedFileURL.path
            guard !visitedPaths.contains(rootPath) else { continue }
            visitedPaths.insert(rootPath)

            if root.pathExtension.lowercased() == "app" {
                processAppBundle(at: root, into: &applicationsByIdentifier)
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard !url.lastPathComponent.hasPrefix("."),
                      url.pathExtension.lowercased() == "app" else { continue }
                processAppBundle(at: url, into: &applicationsByIdentifier)
            }
        }

        let sorted = applicationsByIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        cached = sorted
        cachedAt = Date()

        return sorted
    }

    private static func processAppBundle(
        at url: URL,
        into dict: inout [String: InstalledApplication]
    ) {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return }

        let info = bundle.infoDictionary ?? [:]
        let isBackground = flagIsEnabled(info["LSUIElement"]) || flagIsEnabled(info["LSBackgroundOnly"])

        if SystemAppProtection.isSystemProtected(
            bundleIdentifier: bundleIdentifier,
            isBackground: isBackground,
            path: url.path
        ) {
            return
        }

        let rawName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let name = SystemAppProtection.cleanAppName(rawName)
        guard !name.isEmpty else { return }

        let application = InstalledApplication(
            bundleIdentifier: bundleIdentifier,
            name: name,
            url: url,
            isBackground: isBackground
        )

        insertOrUpdate(application, into: &dict)
    }

    private static func insertOrUpdate(
        _ application: InstalledApplication,
        into dict: inout [String: InstalledApplication]
    ) {
        let key = application.id
        if let existing = dict[key] {
            if preferred(application, over: existing) {
                dict[key] = application
            }
        } else {
            dict[key] = application
        }
    }

    private static func preferred(_ candidate: InstalledApplication, over existing: InstalledApplication) -> Bool {
        let candidateInApplications = candidate.url.path.hasPrefix("/Applications/")
        let existingInApplications = existing.url.path.hasPrefix("/Applications/")
        if candidateInApplications != existingInApplications { return candidateInApplications }
        return candidate.url.path.count < existing.url.path.count
    }

    private static func flagIsEnabled(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            return string == "1" || string.caseInsensitiveCompare("true") == .orderedSame
        }
        return false
    }
}

@MainActor
final class ExcludeAppPickerViewModel: ObservableObject {
    @Published private(set) var applications: [InstalledApplication] = []
    @Published private(set) var isLoading = true
    @Published var selectedIdentifiers: Set<String> = []
    @Published var searchQuery = ""
    @Published var showBackgroundApps = false

    private var hasLoaded = false

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }
        let runningApplications = InstalledApplicationScanner.runningApplicationInfos()
        let scanTask = Task.detached(priority: .userInitiated) {
            InstalledApplicationScanner.scan(runningApplications: runningApplications)
        }
        let result = await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
        guard !Task.isCancelled else {
            hasLoaded = false
            return
        }
        applications = result
    }

    func toggle(_ application: InstalledApplication) {
        if selectedIdentifiers.contains(application.id) {
            selectedIdentifiers.remove(application.id)
        } else {
            selectedIdentifiers.insert(application.id)
        }
    }

    func selectionState(for applications: [InstalledApplication]) -> (isAll: Bool, isPartial: Bool) {
        guard !applications.isEmpty else { return (false, false) }
        var selectedCount = 0
        for app in applications {
            if selectedIdentifiers.contains(app.id) {
                selectedCount += 1
            }
        }
        if selectedCount == 0 {
            return (false, false)
        } else if selectedCount == applications.count {
            return (true, false)
        } else {
            return (false, true)
        }
    }

    func isAllSelected(for applications: [InstalledApplication]) -> Bool {
        selectionState(for: applications).isAll
    }

    func isPartiallySelected(for applications: [InstalledApplication]) -> Bool {
        selectionState(for: applications).isPartial
    }

    func toggleSelectAll(for applications: [InstalledApplication]) {
        if isAllSelected(for: applications) {
            for app in applications {
                selectedIdentifiers.remove(app.id)
            }
        } else {
            for app in applications {
                selectedIdentifiers.insert(app.id)
            }
        }
    }
}

@MainActor
final class ExcludeAppPickerWindowController: NSObject, NSWindowDelegate {
    static let shared = ExcludeAppPickerWindowController()
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        if let window {
            if let screen = WindowPositioner.targetScreen {
                window.setFrameOrigin(WindowPositioner.topBiasedOrigin(for: window.frame.size, on: screen))
            }
            WindowAnimator.activateExisting(window)
            return
        }

        let view = ExcludeAppPickerView { [weak self] in
            self?.close()
        }
        .environmentObject(ConfigStore.shared)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 500, height: 520))
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
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}

struct ExcludeAppPickerView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var viewModel = ExcludeAppPickerViewModel()
    let onClose: () -> Void

    private var visibleApplications: [InstalledApplication] {
        let excluded = configStore.excludedNormalized
        let query = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.applications.filter { application in
            guard !excluded.contains(application.id) else { return false }
            guard viewModel.showBackgroundApps || !application.isBackground else { return false }
            guard !query.isEmpty else { return true }
            return application.name.localizedCaseInsensitiveContains(query)
                || application.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            controls
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Group {
                if viewModel.isLoading {
                    InstalledAppsSkeletonView()
                } else if visibleApplications.isEmpty {
                    emptyView
                } else {
                    appList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
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
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        Text("Add Apps to Exclude List")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(QuitXTheme.paneBackground)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                TextField("Search apps", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .disableInitialFocus()
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))

            Button {
                viewModel.showBackgroundApps.toggle()
            } label: {
                HStack(spacing: 6) {
                    QuitXSelectionCheckbox(isSelected: viewModel.showBackgroundApps)
                    Text("Show background apps")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.primary)
                }
            }
            .buttonStyle(.plain)
            .help("Only changes this window")
        }
    }

    private var appList: some View {
        let apps = visibleApplications
        let state = viewModel.selectionState(for: apps)
        return VStack(spacing: 0) {
            Button {
                viewModel.toggleSelectAll(for: apps)
            } label: {
                HStack(spacing: 8) {
                    QuitXSelectionCheckbox(
                        isSelected: state.isAll,
                        isPartial: state.isPartial
                    )
                    Text(state.isAll ? "Deselect All" : "Select All")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text("\(apps.count) apps")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 27)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(apps) { application in
                        Button {
                            viewModel.toggle(application)
                        } label: {
                            InstalledAppPickerRow(
                                application: application,
                                isSelected: viewModel.selectedIdentifiers.contains(application.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.searchQuery.isEmpty ? "checkmark.circle" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(QuitXTheme.accent)
            Text(viewModel.searchQuery.isEmpty ? "No apps available" : "No matching apps")
                .font(.system(size: 13, weight: .medium))
            Text(viewModel.searchQuery.isEmpty ? "All visible apps are already excluded." : "Try another search.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.selectedIdentifiers.count) selected")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)

            Spacer()

            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)

            Button(viewModel.selectedIdentifiers.count == 1 ? "Add App" : "Add Apps") {
                let selected = viewModel.applications
                    .filter { viewModel.selectedIdentifiers.contains($0.id) }
                    .map(\.bundleIdentifier)
                configStore.addExcludedApps(selected)
                onClose()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.selectedIdentifiers.isEmpty)
        }
        .font(.system(size: 11.5))
    }
}

private struct InstalledAppPickerRow: View {
    let application: InstalledApplication
    let isSelected: Bool
    @StateObject private var state = InstalledAppPickerRowState()

    var body: some View {
        HStack(spacing: 8) {
            QuitXSelectionCheckbox(isSelected: isSelected)

            AppIconView(bundleId: application.bundleIdentifier, url: application.url)
                .frame(width: 18, height: 18)

            Text(application.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if application.isBackground {
                Text("Background")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}

private final class InstalledAppPickerRowState: ObservableObject {
    @Published var isHovered = false
}

private struct InstalledAppsSkeletonView: View {
    @StateObject private var state = InstalledAppsSkeletonState()

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<14, id: \.self) { index in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).frame(width: 14, height: 14)
                    RoundedRectangle(cornerRadius: 4).frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: CGFloat(105 + ((index % 3) * 24)), height: 10)
                    Spacer()
                }
                .foregroundStyle(Color.primary.opacity(state.isBright ? 0.12 : 0.055))
                .padding(.horizontal, 8)
                .frame(height: 29)
            }
            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                state.isBright = true
            }
        }
    }
}

private final class InstalledAppsSkeletonState: ObservableObject {
    @Published var isBright = false
}
