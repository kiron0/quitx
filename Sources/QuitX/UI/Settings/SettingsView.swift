import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case support = "Support"
    case about = "About"

    var iconName: String {
        switch self {
        case .general:   return "gearshape"
        case .shortcuts: return "command"
        case .support:   return "bubble.left.and.bubble.right"
        case .about:     return "bolt.fill"
        }
    }

}

private final class SettingsTabState: ObservableObject {
    @Published var activeTab: SettingsTab = .general
}

private final class GeneralState: ObservableObject {
    @Published var disableQuitTips: Bool = false
    @Published var autoQuitUnit: String = "hour"
    @Published var autoQuitValue: Int = 1
}

private final class ShortcutsState: ObservableObject {
    @Published var activateMenuEnabled = true
    @Published var quitAllEnabled = false
    @Published var forceQuitAllEnabled = false
}

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var tabState = SettingsTabState()

    var body: some View {
        VStack(spacing: 0) {
            // Custom Toolbar Tabs (Matching Quit All)
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        tabState.activeTab = tab
                        updateWindowTitle(tab.rawValue)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 24, weight: tabState.activeTab == tab ? .medium : .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: tabState.activeTab == tab ? .semibold : .medium))
                        }
                        .foregroundStyle(tabState.activeTab == tab ? Color.white.opacity(0.82) : Color.white.opacity(0.32))
                        .frame(width: 64, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(tabState.activeTab == tab ? Color.white.opacity(0.11) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 7)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)

            Divider()
                .background(Color.white.opacity(0.1))

            // Tab Content
            Group {
                switch tabState.activeTab {
                case .general:
                    GeneralTabCloneView()
                case .shortcuts:
                    ShortcutsTabCloneView()
                case .support:
                    SupportTabCloneView()
                case .about:
                    AboutTabCloneView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400)
        .frame(maxHeight: .infinity)
        .background(QuitAllTheme.windowBackground)
        .preferredColorScheme(.dark)
        .onAppear {
            updateWindowTitle(tabState.activeTab.rawValue)
        }
    }

    private func updateWindowTitle(_ title: String) {
        NSApp.windows.first(where: { $0.title == "General" || $0.title == "Shortcuts" || $0.title == "Support" || $0.title == "About" || $0.title == "QuitX Preferences" })?.title = title
    }
}

// MARK: - Tab 1: General (Clone of Quit All General tab)

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = GeneralState()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Startup
                settingRow(label: "Startup:") {
                    checkbox(title: "Open QuitX at login", isOn: Binding(
                        get: { configStore.config.autoUpdate },
                        set: { configStore.config.autoUpdate = $0; configStore.save() }
                    ), info: "Launch QuitX automatically when your Mac turns on.")
                }

                // Sounds
                settingRow(label: "Sounds:") {
                    checkbox(title: "Play cool sounds", isOn: $configStore.config.playSounds, info: "Play satisfying audio feedback when quitting apps.")
                }

                // Advanced
                settingRow(label: "Advanced:") {
                    VStack(alignment: .leading, spacing: 8) {
                        checkbox(title: "View background apps", isOn: $configStore.config.includeBackground, info: "Show background and windowless processes in list.")
                        checkbox(title: "Group background instances", isOn: $configStore.config.groupBackground, info: "Keep background processes visually grouped.")
                        checkbox(title: "Never quit music apps", isOn: $configStore.config.neverQuitMusic, info: "Protect Spotify, Apple Music, and other music players.")
                        checkbox(title: "Deselect apps by default", isOn: $configStore.config.defaultSelectAll, info: "Start with apps unchecked when opening QuitX.")
                        checkbox(title: "Disable quit tips", isOn: $state.disableQuitTips, info: "Turn off motivational footer quotes.")
                    }
                }

                // Extras
                settingRow(label: "Extras:") {
                    VStack(alignment: .leading, spacing: 8) {
                        checkbox(title: "Include Finder Windows in list", isOn: $configStore.config.includeFinder, info: "Allow closing Finder windows.")
                        checkbox(title: "Include Empty Trash in list", isOn: $configStore.config.includeTrash, info: "Allow emptying trash from QuitX.")
                    }
                }

                // Auto Quit
                settingRow(label: "Auto Quit:") {
                    VStack(alignment: .leading, spacing: 6) {
                        checkbox(title: "Quit inactive apps after", isOn: Binding(
                            get: { configStore.config.quitInactiveAfterMinutes > 0 },
                            set: { enabled in
                                configStore.config.quitInactiveAfterMinutes = enabled ? (state.autoQuitUnit == "hour" ? state.autoQuitValue * 60 : state.autoQuitValue) : 0
                                configStore.save()
                            }
                        ), info: "Automatically close applications when left untouched.")

                        if configStore.config.quitInactiveAfterMinutes > 0 {
                            HStack(spacing: 8) {
                                Picker("", selection: $state.autoQuitValue) {
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                    Text("4").tag(4)
                                    Text("8").tag(8)
                                    Text("15").tag(15)
                                    Text("30").tag(30)
                                }
                                .frame(width: 58)
                                .labelsHidden()

                                Picker("", selection: $state.autoQuitUnit) {
                                    Text("minute").tag("min")
                                    Text("hour").tag("hour")
                                    Text("day").tag("day")
                                }
                                .frame(width: 76)
                                .labelsHidden()
                            }
                            .padding(.leading, 22)
                            .onChange(of: state.autoQuitValue) { updateAutoQuitMinutes() }
                            .onChange(of: state.autoQuitUnit) { updateAutoQuitMinutes() }
                        }
                    }
                }

                // Sort
                settingRow(label: "Sort:") {
                    HStack(spacing: 8) {
                        Picker("", selection: Binding(
                            get: { configStore.config.sortBy == .memory ? "RAM Usage" : "A-Z Alphabetical" },
                            set: { configStore.config.sortBy = ($0 == "RAM Usage" ? .memory : nil); configStore.save() }
                        )) {
                            Text("A-Z Alphabetical").tag("A-Z Alphabetical")
                            Text("RAM Usage").tag("RAM Usage")
                            Text("CPU Usage").tag("CPU Usage")
                        }
                        .frame(width: 145)
                        .labelsHidden()

                        infoIcon("Sort apps by name or memory usage.")
                    }
                }

                // Default
                settingRow(label: "Default:") {
                    HStack(spacing: 8) {
                        Picker("", selection: $configStore.config.force) {
                            Text("⏻ Normal quit").tag(QuitXConfig.ForceMode.normal)
                            Text("⚡ Force quit").tag(QuitXConfig.ForceMode.force)
                        }
                        .frame(width: 145)
                        .labelsHidden()
                        .onChange(of: configStore.config.force) { configStore.save() }

                        infoIcon("Choose whether standard click performs Graceful or Force quit.")
                    }
                }

                // Reset
                settingRow(label: "Reset:") {
                    Button("Reset all") {
                        configStore.config = QuitXConfig.default
                        configStore.save()
                    }
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func updateAutoQuitMinutes() {
        let multiplier = (state.autoQuitUnit == "hour" ? 60 : (state.autoQuitUnit == "day" ? 1440 : 1))
        configStore.config.quitInactiveAfterMinutes = state.autoQuitValue * multiplier
        configStore.save()
    }

    // Helper: 2-column row
    @ViewBuilder
    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 70, alignment: .trailing)

            content()

            Spacer(minLength: 0)
        }
    }

    // Helper: checkbox with info icon
    @ViewBuilder
    private func checkbox(title: String, isOn: Binding<Bool>, info: String) -> some View {
        HStack(spacing: 8) {
            Button {
                isOn.wrappedValue.toggle()
                configStore.save()
            } label: {
                HStack(spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5)
                            .stroke(isOn.wrappedValue ? QuitAllTheme.accent : Color.white.opacity(0.3), lineWidth: 1.2)
                            .background(
                                RoundedRectangle(cornerRadius: 3.5)
                                    .fill(isOn.wrappedValue ? QuitAllTheme.accent : Color.clear)
                            )
                            .frame(width: 14, height: 14)

                        if isOn.wrappedValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black.opacity(0.9))
                        }
                    }

                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            infoIcon(info)
        }
    }

    @ViewBuilder
    private func infoIcon(_ text: String) -> some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(0.35))
            .help(text)
    }
}

// MARK: - Tab 2: Shortcuts

struct ShortcutsTabCloneView: View {
    @StateObject private var state = ShortcutsState()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                shortcutRow(
                    title: "Activate menu:",
                    isEnabled: $state.activateMenuEnabled,
                    keys: ["⌃", "⌥", "A"]
                )
                shortcutRow(
                    title: "Quit all:",
                    isEnabled: $state.quitAllEnabled,
                    keys: ["⌃", "⌥", "Q"]
                )
                shortcutRow(
                    title: "Force quit all:",
                    isEnabled: $state.forceQuitAllEnabled,
                    keys: ["⌃", "⌥", "⌘", "Q"]
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

            HStack(spacing: 9) {
                Text("⌥")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 25, height: 25)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))

                Text("Hold down Option to toggle “Quit” and “Force Quit”.")
                    .font(.system(size: 12.5, weight: .medium))

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.55))
            .padding(.horizontal, 14)

            Spacer()
        }
    }

    private func shortcutRow(title: String, isEnabled: Binding<Bool>, keys: [String]) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 105, alignment: .trailing)

            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(isEnabled.wrappedValue ? 0.18 : 0.08))
                        .frame(width: 22, height: 22)
                    if isEnabled.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.86))
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    Text(key)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(isEnabled.wrappedValue ? 0.82 : 0.24))
                        .frame(minWidth: 22, minHeight: 24)
                        .padding(.horizontal, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(isEnabled.wrappedValue ? 0.19 : 0.08))
                        )
                }
                Spacer(minLength: 0)
            }
            .padding(3)
            .frame(width: 110, height: 30)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            Button {
                isEnabled.wrappedValue = false
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(isEnabled.wrappedValue ? 0.36 : 0.16))
                    .frame(width: 20, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled.wrappedValue)
        }
        .frame(height: 30)
    }
}

// MARK: - Tab 3: Support

struct SupportTabCloneView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundStyle(QuitAllTheme.accent)

            Text("Need Help or Have Feedback?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Text("QuitX is built for macOS speed and minimalism.\nFeel free to explore our documentation or report an issue on GitHub.")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 14) {
                Link("Documentation", destination: URL(string: "https://quitx.coreify.io")!)
                Text("•").foregroundStyle(.secondary)
                Link("GitHub Issues", destination: URL(string: "https://github.com/coreify/quitx-app/issues")!)
            }
            .font(.system(size: 12, weight: .medium))

            Spacer()
        }
        .padding()
    }
}

// MARK: - Tab 4: About

struct AboutTabCloneView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            if let img = NSImage(contentsOfFile: "Support/Icons/icon_128x128.png") ?? Bundle.main.image(forResource: "AppIcon") {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }

            VStack(spacing: 4) {
                Text("QuitX for macOS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text("Version 1.0.0 (Build 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Text("© 2026 Coreify / Toufiq Hasan Kiron\nInspired by Setapp Quit All.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Link("GitHub Repo", destination: URL(string: "https://github.com/coreify/quitx-app")!)
                Text("•").foregroundStyle(.secondary)
                Link("Website", destination: URL(string: "https://quitx.coreify.io")!)
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding()
    }
}
