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
    static func scan() -> [InstalledApplication] {
        let fileManager = FileManager.default
        let roots = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
            + fileManager.urls(for: .applicationDirectory, in: .systemDomainMask)
            + fileManager.urls(for: .applicationDirectory, in: .userDomainMask)

        var applicationsByIdentifier: [String: InstalledApplication] = [:]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            if Task.isCancelled { return [] }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard url.pathExtension.lowercased() == "app",
                      let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      !QuitXIdentity.supportedBundleIdentifiers.contains(bundleIdentifier) else { continue }

                let info = bundle.infoDictionary ?? [:]
                let name = (info["CFBundleDisplayName"] as? String)
                    ?? (info["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let isBackground = flagIsEnabled(info["LSUIElement"])
                    || flagIsEnabled(info["LSBackgroundOnly"])
                let key = bundleIdentifier.lowercased()
                let application = InstalledApplication(
                    bundleIdentifier: bundleIdentifier,
                    name: name,
                    url: url,
                    isBackground: isBackground
                )

                if let existing = applicationsByIdentifier[key] {
                    if preferred(application, over: existing) {
                        applicationsByIdentifier[key] = application
                    }
                } else {
                    applicationsByIdentifier[key] = application
                }
            }
        }

        return applicationsByIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
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
        let scanTask = Task.detached(priority: .userInitiated) {
            InstalledApplicationScanner.scan()
        }
        let result = await withTaskCancellationHandler {
            await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
        guard !Task.isCancelled else { return }
        applications = result
        isLoading = false
    }

    func toggle(_ application: InstalledApplication) {
        if selectedIdentifiers.contains(application.id) {
            selectedIdentifiers.remove(application.id)
        } else {
            selectedIdentifiers.insert(application.id)
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
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = QuitXTheme.windowBackgroundNSColor
        window.appearance = NSApp.effectiveAppearance
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.center()
        self.window = window
        WindowActivationCoordinator.update()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        let excluded = Set(configStore.config.exclude.map { $0.lowercased() })
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
                .padding(.vertical, 12)

            Divider()

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

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 500, height: 520)
        .background(QuitXTheme.windowBackground)
        .ignoresSafeArea(edges: .top)
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
            .background(QuitXTheme.windowBackground)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                TextField("Search installed apps", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
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
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 2) {
                ForEach(visibleApplications) { application in
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
            .padding(.vertical, 2)
        }
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

            AppIconView(bundleId: application.bundleIdentifier)
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
