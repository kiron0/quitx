import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case exclude = "Exclude"
    case shortcuts = "Shortcuts"
    case support = "Support"
    case about = "About"

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }

    var iconName: String {
        switch self {
        case .general:   return "preferences-general"
        case .exclude:   return "preferences-exclude"
        case .shortcuts: return "preferences-shortcuts"
        case .support:   return "preferences-support"
        case .about:     return "preferences-about"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .exclude:   return "nosign"
        case .shortcuts: return "command"
        case .support:   return "bubble.left.and.bubble.right"
        case .about:     return "bolt.fill"
        }
    }

    var toolbarImage: NSImage? {
        if let img = AssetImages.load(iconName) {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 19, height: 19)
            copy.isTemplate = true
            return copy
        }
        let sym = NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: rawValue)
        let copy = sym?.copy() as? NSImage
        copy?.size = NSSize(width: 19, height: 19)
        copy?.isTemplate = true
        return copy ?? sym
    }

    var contentHeight: CGFloat {
        switch self {
        case .general:   return 505
        case .exclude:   return 300
        case .shortcuts: return 215
        case .support:   return 139
        case .about:     return 130
        }
    }
}

final class HelpPopoverState: ObservableObject {
    @Published var isShowing = false
}

struct HelpPopoverButton: View {
    let text: String
    @StateObject private var state = HelpPopoverState()

    var body: some View {
        Button {
            state.isShowing.toggle()
        } label: {
            if let icon = AssetImages.load("settings-default-help") {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 13, height: 13)
                    .foregroundStyle(state.isShowing ? Color.primary : Color.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(state.isShowing ? Color.primary : Color.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $state.isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primary)
                .lineSpacing(2.5)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(width: 230)
                .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        }
    }
}

final class SettingsTabViewModel: ObservableObject {
    @Published var activeTab: SettingsTab = .general
}

struct SettingsContainerView: View {
    @ObservedObject var tabModel: SettingsTabViewModel
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        ZStack(alignment: .top) {
            switch tabModel.activeTab {
            case .general:
                GeneralTabCloneView()
                    .environmentObject(configStore)
            case .exclude:
                ExcludeTabView()
                    .environmentObject(configStore)
            case .shortcuts:
                ShortcutsTabCloneView()
            case .support:
                SupportTabCloneView()
            case .about:
                AboutTabCloneView()
            }
        }
        .frame(width: 400, height: tabModel.activeTab.contentHeight, alignment: .top)
        .background(QuitXTheme.windowBackground)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var tabModel = SettingsTabViewModel()

    var body: some View {
        SettingsContainerView(tabModel: tabModel)
            .environmentObject(configStore)
    }
}

struct ExcludeTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = ExcludeTabState()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apps on this list stay out of manual and automatic Quit actions.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            Group {
                if configStore.config.exclude.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "nosign")
                            .font(.system(size: 24))
                            .foregroundStyle(QuitXTheme.accent)
                        Text("No excluded apps")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text("Use an app's ••• menu in the QuitX popover to add it.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Button {
                            state.toggleAll(configStore.config.exclude)
                        } label: {
                            HStack(spacing: 8) {
                                excludeCheckbox(isSelected: state.allSelected(configStore.config.exclude))
                                Text(state.allSelected(configStore.config.exclude) ? "Deselect All" : "Select All")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 32)

                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(configStore.config.exclude.enumerated()), id: \.offset) { index, identifier in
                                    let normalized = identifier.lowercased()
                                    Button {
                                        state.toggle(normalized)
                                    } label: {
                                        ExcludedAppRow(
                                            identifier: identifier,
                                            isSelected: state.selectedIdentifiers.contains(normalized)
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index < configStore.config.exclude.count - 1 {
                                        Divider().padding(.leading, 42)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )

            HStack {
                Button {
                    ExcludeAppPickerWindowController.shared.show()
                } label: {
                    Label("Add Apps…", systemImage: "plus")
                }

                Button(state.selectedIdentifiers.count == 1 ? "Remove Selected" : "Remove Selected (\(state.selectedIdentifiers.count))") {
                    let identifiers = configStore.config.exclude.filter {
                        state.selectedIdentifiers.contains($0.lowercased())
                    }
                    state.pendingRemoval = ExcludeRemovalRequest(
                        identifiers: identifiers,
                        totalCount: configStore.config.exclude.count
                    )
                }
                .disabled(state.selectedIdentifiers.isEmpty)

                Spacer()

                Text("\(configStore.config.exclude.count) excluded")
                    .foregroundStyle(Color.secondary)
            }
            .font(.system(size: 11.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 400, height: 300, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
        .alert(item: $state.pendingRemoval) { request in
            Alert(
                title: Text(request.removesAll ? "Remove all excluded apps?" : "Remove selected apps?"),
                message: Text(request.message),
                primaryButton: .destructive(Text(request.removesAll ? "Remove All" : "Remove")) {
                    configStore.removeExcludedApps(Set(request.identifiers))
                    state.selectedIdentifiers.removeAll()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func excludeCheckbox(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? QuitXTheme.accent : Color.primary.opacity(0.08))
                .frame(width: 14, height: 14)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.9))
            }
        }
    }
}

private final class ExcludeTabState: ObservableObject {
    @Published var pendingRemoval: ExcludeRemovalRequest?
    @Published var selectedIdentifiers: Set<String> = []

    func toggle(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
        }
    }

    func allSelected(_ identifiers: [String]) -> Bool {
        let all = Set(identifiers.map { $0.lowercased() })
        return !all.isEmpty && all.isSubset(of: selectedIdentifiers)
    }

    func toggleAll(_ identifiers: [String]) {
        let all = Set(identifiers.map { $0.lowercased() })
        if all.isSubset(of: selectedIdentifiers) {
            selectedIdentifiers.subtract(all)
        } else {
            selectedIdentifiers.formUnion(all)
        }
    }
}

private struct ExcludeRemovalRequest: Identifiable {
    let identifiers: [String]
    let removesAll: Bool

    var id: String { identifiers.map { $0.lowercased() }.sorted().joined(separator: "|") }

    var message: String {
        if removesAll {
            return "QuitX may quit these apps after removal. This clears the entire Exclude list."
        }
        if identifiers.count == 1 {
            return "QuitX may quit this app after removal."
        } else {
            return "QuitX may quit these \(identifiers.count) apps after removal."
        }
    }

    init(identifiers: [String], totalCount: Int) {
        self.identifiers = identifiers
        self.removesAll = identifiers.count == totalCount
    }
}

private struct ExcludedAppRow: View {
    let identifier: String
    let isSelected: Bool

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    private var displayName: String {
        guard let appURL,
              let bundle = Bundle(url: appURL),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            return identifier
        }
        return name
    }

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? QuitXTheme.accent : Color.primary.opacity(0.08))
                    .frame(width: 14, height: 14)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.9))
                }
            }

            Group {
                if let appURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.secondary)
                        .padding(3)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                if displayName != identifier {
                    Text(identifier)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
    }
}

final class GeneralTabState: ObservableObject {
    @Published var autoQuitValue: Int = 1
    @Published var autoQuitUnit: String = "hours"

    func syncFromMinutes(_ minutes: Int) {
        if minutes > 0 {
            if minutes % 1440 == 0 {
                autoQuitValue = max(1, minutes / 1440)
                autoQuitUnit = "days"
            } else if minutes % 60 == 0 {
                autoQuitValue = max(1, minutes / 60)
                autoQuitUnit = "hours"
            } else {
                autoQuitValue = max(1, minutes)
                autoQuitUnit = "minutes"
            }
        } else {
            autoQuitValue = 1
            autoQuitUnit = "hours"
        }
    }

    func calculateMinutes() -> Int {
        switch autoQuitUnit {
        case "days": return max(1, autoQuitValue * 1440)
        case "hours": return max(1, autoQuitValue * 60)
        default: return max(1, autoQuitValue)
        }
    }
}

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared
    @StateObject private var state = GeneralTabState()

    private let gold = QuitXTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            row(label: "Startup:") {
                toggle("Open QuitX at login", isOn: $launchService.isEnabled)
            } help: {
                HelpPopoverButton(text: "This one is pretty self explanatory, so here's an easter egg instead of a helpful tooltip. 🐇🍳")
            }

            row(label: "Sounds:") {
                toggle("Play cool sounds", isOn: Binding(
                    get: { configStore.config.playSounds },
                    set: { configStore.config.playSounds = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "A deeply satisfying laser sound will play when quitting apps. 👾🔫")
            }

            row(label: "Advanced:") {
                toggle("View background apps", isOn: Binding(
                    get: { configStore.config.includeBackground },
                    set: {
                        configStore.config.includeBackground = $0
                        AppListViewModel.shared.showBackgroundApps = $0
                        configStore.save(refreshAppList: true)
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Heads up, some background apps will immediately restart after quitting them. It’s sorcery beyond our control. 🧙‍♂️")
            }

            row(label: "") {
                toggle("Group background instances", isOn: Binding(
                    get: { configStore.config.groupBackground },
                    set: { configStore.config.groupBackground = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Check this box to group multiple instances of the same background app into a single line item. Leave it unchecked to give each app instance its own line. 👨‍👨‍👦‍👦 -> 👨👨👨👨")
            }

            row(label: "") {
                toggle("Never quit music apps", isOn: Binding(
                    get: { configStore.config.neverQuitMusic },
                    set: { configStore.config.neverQuitMusic = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Don't stop believin', hold on to that feelin' — and your music! Exclude Spotify and Apple Music from auto or manual Quit actions. 🎵")
            }

            row(label: "") {
                toggle("Deselect apps by default", isOn: Binding(
                    get: { !configStore.config.defaultSelectAll },
                    set: {
                        configStore.config.defaultSelectAll = !$0
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Some like the whole app list selected, some like ‘em all deselected. Now you get to choose. 🙌")
            }

            row(label: "") {
                toggle("Disable quit tips", isOn: Binding(
                    get: { configStore.config.disableQuitTips },
                    set: { configStore.config.disableQuitTips = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "The rotating tips at the bottom of the QuitX dropdown will cease to show. It’s okay. We can still be friends. 🤗")
            }

            row(label: "Extras:") {
                toggle("Include Finder Windows in list", isOn: Binding(
                    get: { configStore.config.includeFinder },
                    set: { configStore.config.includeFinder = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Find yourself finding Finder windows too often? Enable this to easily close them all when you quit all apps.")
            }

            row(label: "") {
                toggle("Include Empty Trash in list", isOn: Binding(
                    get: { configStore.config.includeTrash },
                    set: { configStore.config.includeTrash = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "A truly fresh start without a restart. Take out the trash at the same time you take out the apps! 🗑️🧹")
            }

            let isAutoQuitEnabled = configStore.config.quitInactiveAfterMinutes > 0
            row(label: "Auto Quit:") {
                toggle("Quit inactive apps after", isOn: Binding(
                    get: { isAutoQuitEnabled },
                    set: { enabled in
                        if enabled {
                            configStore.config.quitInactiveAfterMinutes = state.calculateMinutes()
                        } else {
                            configStore.config.quitInactiveAfterMinutes = 0
                        }
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Keep things running in ship-shape by setting an automatic Quit for inactive apps. 🛳")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    TextField("", value: $state.autoQuitValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)

                    Stepper("", value: $state.autoQuitValue, in: 1...999)
                        .labelsHidden()

                    Picker("", selection: $state.autoQuitUnit) {
                        Text("minutes").tag("minutes")
                        Text("hours").tag("hours")
                        Text("days").tag("days")
                    }
                    .frame(width: 90)
                    .labelsHidden()
                }
                .disabled(!isAutoQuitEnabled)
                .opacity(isAutoQuitEnabled ? 1.0 : 0.42)
            } help: {
                Color.clear.frame(width: 20, height: 20)
            }

            row(label: "Sort:") {
                Picker("", selection: Binding(
                    get: { configStore.config.sortBy },
                    set: { configStore.config.sortBy = $0; configStore.save(refreshAppList: true) }
                )) {
                    ForEach(QuitXConfig.SortBy.allCases, id: \.self) { sortOpt in
                        Text(sortOpt.rawValue).tag(sortOpt)
                    }
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Sort the app list alphabetically, by CPU usage, or by memory usage. The row metric follows the selected resource sort.")
            }

            row(label: "Default:") {
                Picker("", selection: Binding(
                    get: { configStore.config.force == .force ? "Force quit" : "Normal quit" },
                    set: { configStore.config.force = ($0 == "Force quit" ? .force : .normal); configStore.save() }
                )) {
                    Text("Normal quit").tag("Normal quit")
                    Text("Force quit").tag("Force quit")
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "You can also temporarily toggle between quit and force quit by holding ⌥ (Option key). ⌥")
            }

            row(label: "On Failure:") {
                Picker("", selection: Binding(
                    get: { configStore.config.onQuitFailure ?? .error },
                    set: { configStore.config.onQuitFailure = $0; configStore.save() }
                )) {
                    Text("Show error").tag(OnQuitFailureMode.error)
                    Text("Ask to force quit").tag(OnQuitFailureMode.prompt)
                    Text("Force quit automatically").tag(OnQuitFailureMode.force)
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Choose what QuitX does when an app does not quit normally.")
            }

            row(label: "Reset:") {
                Button("Reset all") {
                    configStore.config = QuitXConfig.default
                    AppListViewModel.shared.showBackgroundApps = configStore.config.includeBackground
                    configStore.save(refreshAppList: true)
                    state.syncFromMinutes(configStore.config.quitInactiveAfterMinutes)
                }
                .font(.system(size: 11.5))
            } help: {
                Color.clear.frame(width: 20, height: 20)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 400, height: 505, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
        .onAppear {
            state.syncFromMinutes(configStore.config.quitInactiveAfterMinutes)
        }
        .onChange(of: state.autoQuitValue) {
            if configStore.config.quitInactiveAfterMinutes > 0 {
                configStore.config.quitInactiveAfterMinutes = state.calculateMinutes()
                configStore.save()
            }
        }
        .onChange(of: state.autoQuitUnit) {
            if configStore.config.quitInactiveAfterMinutes > 0 {
                configStore.config.quitInactiveAfterMinutes = state.calculateMinutes()
                configStore.save()
            }
        }
    }

    private func row<Content: View, Help: View>(
        label: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder help: () -> Help
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 84, alignment: .trailing)

            content()

            Spacer(minLength: 0)

            help()
        }
        .frame(height: 25)
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(isOn.wrappedValue ? gold : Color.primary.opacity(0.08))
                        .frame(width: 14, height: 14)

                    if isOn.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.9))
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class ShortcutsViewState: ObservableObject {
    @Published var recordingRow: String? = nil
    var localMonitor: Any? = nil
    var globalMonitor: Any? = nil

    func startMonitor(sm: ShortcutManager) {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return event }
            if self.processEvent(event, row: row, sm: sm) {
                return nil
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return }
            _ = self.processEvent(event, row: row, sm: sm)
        }
    }

    func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func processEvent(_ event: NSEvent, row: String, sm: ShortcutManager) -> Bool {
        if event.keyCode == 53 {
            DispatchQueue.main.async { self.recordingRow = nil }
            return true
        }
        if event.keyCode == 51 {
            DispatchQueue.main.async {
                self.applyKeys([], for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }

        let keys = ShortcutManager.eventToKeys(event)
        if !keys.isEmpty {
            DispatchQueue.main.async {
                self.applyKeys(keys, for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }
        return false
    }

    func applyKeys(_ keys: [String], for row: String, sm: ShortcutManager) {
        switch row {
        case "activate": sm.activateMenuKeys = keys
        case "quit": sm.quitAllKeys = keys
        case "force": sm.forceQuitAllKeys = keys
        default: break
        }
    }
}

struct ShortcutsTabCloneView: View {
    @ObservedObject private var sm = ShortcutManager.shared
    @StateObject private var viewState = ShortcutsViewState()

    private let gold = QuitXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                shortcutLine(
                    id: "activate",
                    label: "Activate menu:",
                    isEnabled: $sm.activateMenuEnabled,
                    keys: $sm.activateMenuKeys
                )
                shortcutLine(
                    id: "quit",
                    label: "Quit all:",
                    isEnabled: $sm.quitAllEnabled,
                    keys: $sm.quitAllKeys
                )
                shortcutLine(
                    id: "force",
                    label: "Force quit all:",
                    isEnabled: $sm.forceQuitAllEnabled,
                    keys: $sm.forceQuitAllKeys
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)

            HStack(spacing: 10) {
                Text("⌥")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))

                Text("Hold down Option to toggle “Quit” and “Force Quit”.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)

                Spacer()
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(width: 400, height: 215)
        .background(QuitXTheme.windowBackground)
        .onAppear {
            viewState.startMonitor(sm: sm)
        }
        .onDisappear {
            viewState.stopMonitor()
        }
    }

    private func shortcutLine(id: String, label: String, isEnabled: Binding<Bool>, keys: Binding<[String]>) -> some View {
        let active = isEnabled.wrappedValue
        let isRecording = (viewState.recordingRow == id)
        let keyList = keys.wrappedValue

        return HStack(spacing: 9) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 105, alignment: .trailing)

            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(active ? gold : Color.primary.opacity(0.08))
                        .frame(width: 15, height: 15)

                    if active {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.9))
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                if active {
                    viewState.recordingRow = (viewState.recordingRow == id ? nil : id)
                }
            } label: {
                HStack(spacing: 3) {
                    if isRecording {
                        Text("Type keys...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(QuitXTheme.accent)
                    } else if keyList.isEmpty {
                        Text("None")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    } else {
                        ForEach(keyList, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(active ? Color.primary : Color.secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 3.5)
                                        .fill(active ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06))
                                 )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .frame(width: 105, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(active ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? QuitXTheme.accent : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                viewState.applyKeys([], for: id, sm: sm)
                if viewState.recordingRow == id { viewState.recordingRow = nil }
            } label: {
                if let img = AssetImages.load("recorder-delete") {
                    Image(nsImage: img)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 13, height: 13)
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(!active || keyList.isEmpty)
            .frame(width: 18, height: 18)

            Spacer()
        }
    }
}

struct SupportTabCloneView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get in touch for any feedback, questions or feature requests!")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .padding(.top, 24)

            Button("Contact") {
                if let url = QuitXConstants.contactURL() {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(width: 400, height: 139, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
    }
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            QuitXAppIconView(size: 70, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(QuitXConstants.appName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text("⚡️ Version \(updateChecker.currentVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }

                Text(QuitXConstants.copyright)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 10) {
                    Button("Say hi 👋") {
                        if let url = QuitXConstants.sayHiURL() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11.5))

                    Button(updateChecker.isChecking ? "Checking..." : "Check Updates") {
                        Task {
                            await updateChecker.checkForUpdates(isUserInitiated: true)
                        }
                    }
                    .disabled(updateChecker.isChecking)
                    .font(.system(size: 11.5))
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .frame(width: 400, height: 130)
        .background(QuitXTheme.windowBackground)
    }
}
