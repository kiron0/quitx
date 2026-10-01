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

    var contentHeight: CGFloat {
        switch self {
        case .general:   return 443
        case .shortcuts: return 215
        case .support:   return 139
        case .about:     return 130
        }
    }
}

// MARK: - Help Popover Button (Working ? popover matching QuitAll)

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
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(state.isShowing ? Color.white.opacity(0.9) : Color.white.opacity(0.35))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $state.isShowing, arrowEdge: .trailing) {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(2.5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: 235)
                .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root SettingsView

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        GeneralTabCloneView()
            .environmentObject(configStore)
            .background(QuitAllTheme.windowBackground)
            .preferredColorScheme(.dark)
    }
}

// MARK: - Tab 1: General (Exact 1:1 Clone of QuitAll General Tab)

final class GeneralTabState: ObservableObject {
    @Published var disableQuitTips: Bool = false
    @Published var autoQuitValue: Int = 1
    @Published var autoQuitUnit: String = "hours"
}

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = GeneralTabState()

    private let gold = QuitAllTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Startup
            row(label: "Startup:") {
                toggle("Open QuitX at login", isOn: Binding(
                    get: { configStore.config.autoUpdate },
                    set: { configStore.config.autoUpdate = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Keep things running in ship-shape by setting an automatic Quit for inactive apps. 🛳")
            }

            // Sounds
            row(label: "Sounds:") {
                toggle("Play cool sounds", isOn: Binding(
                    get: { configStore.config.playSounds },
                    set: { configStore.config.playSounds = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "A deeply satisfying laser sound will play when quitting apps. 👾🔫")
            }

            // Advanced
            row(label: "Advanced:") {
                toggle("View background apps", isOn: Binding(
                    get: { configStore.config.includeBackground },
                    set: { configStore.config.includeBackground = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Heads up, some background apps will immediately restart after quitting them. It’s sorcery beyond our control. 🧙‍♂️")
            }

            row(label: "") {
                toggle("Group background instances", isOn: Binding(
                    get: { configStore.config.groupBackground },
                    set: { configStore.config.groupBackground = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Check this box to group multiple instances of the same background app into a single line item. Leave it unchecked to give each app instance its own line. 👨‍👨‍👦‍👦 -> 👨👨👨👨")
            }

            row(label: "") {
                toggle("Never quit music apps", isOn: Binding(
                    get: { configStore.config.neverQuitMusic },
                    set: { configStore.config.neverQuitMusic = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Don't stop believin', hold on to that feelin' — and your music! Exclude Spotify and Apple Music from auto or manual Quit actions. 🎵")
            }

            row(label: "") {
                toggle("Deselect apps by default", isOn: Binding(
                    get: { configStore.config.defaultSelectAll },
                    set: { configStore.config.defaultSelectAll = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Some like the whole app list selected, some like ‘em all deselected. Now you get to choose. 🙌")
            }

            row(label: "") {
                toggle("Disable quit tips", isOn: $state.disableQuitTips)
            } help: {
                HelpPopoverButton(text: "The rotating tips at the bottom of the QuitAll dropdown will cease to show. It’s okay. We can still be friends. 🤗")
            }

            // Extras
            row(label: "Extras:") {
                toggle("Include Finder Windows in list", isOn: Binding(
                    get: { configStore.config.includeFinder },
                    set: { configStore.config.includeFinder = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Find yourself finding Finder windows too often? Enable this to easily close them all when you QuitAll.")
            }

            row(label: "") {
                toggle("Include Empty Trash in list", isOn: Binding(
                    get: { configStore.config.includeTrash },
                    set: { configStore.config.includeTrash = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "A truly fresh start without a restart. Take out the trash at the same time you take out the apps! 🗑️🧹")
            }

            // Auto Quit
            row(label: "Auto Quit:") {
                toggle("Quit inactive apps after", isOn: Binding(
                    get: { configStore.config.quitInactiveAfterMinutes > 0 },
                    set: { enabled in
                        configStore.config.quitInactiveAfterMinutes = enabled ? (state.autoQuitUnit == "hours" ? state.autoQuitValue * 60 : state.autoQuitValue) : 0
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Keep things running in ship-shape by setting an automatic Quit for inactive apps. 🛳")
            }

            // Auto Quit Stepper Row
            row(label: "") {
                HStack(spacing: 6) {
                    TextField("", value: $state.autoQuitValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)

                    Stepper("", value: $state.autoQuitValue, in: 1...60)
                        .labelsHidden()

                    Picker("", selection: $state.autoQuitUnit) {
                        Text("minutes").tag("minutes")
                        Text("hours").tag("hours")
                        Text("days").tag("days")
                    }
                    .frame(width: 90)
                    .labelsHidden()
                }
            } help: {
                Color.clear.frame(width: 22, height: 22)
            }

            // Sort
            row(label: "Sort:") {
                Picker("", selection: Binding(
                    get: { configStore.config.sortBy },
                    set: { configStore.config.sortBy = $0; configStore.save() }
                )) {
                    ForEach(QuitXConfig.SortBy.allCases, id: \.self) { sortOpt in
                        Text(sortOpt.rawValue).tag(sortOpt)
                    }
                }
                .frame(width: 175)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Sort the list of apps alphabetically or by CPU usage. Made possible by this magical sorting unicorn. ✨🦄")
            }

            // Default
            row(label: "Default:") {
                Picker("", selection: Binding(
                    get: { configStore.config.force == .force ? "Force quit" : "Normal quit" },
                    set: { configStore.config.force = ($0 == "Force quit" ? .force : .normal); configStore.save() }
                )) {
                    Text("Normal quit").tag("Normal quit")
                    Text("Force quit").tag("Force quit")
                }
                .frame(width: 175)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "This one is pretty self explanatory, so here’s an easter egg instead of a helpful tooltip. 🐇🍳")
            }

            // Reset
            row(label: "Reset:") {
                Button("Reset all") {
                    configStore.config = QuitXConfig.default
                    configStore.save()
                }
                .font(.system(size: 11.5))
            } help: {
                Color.clear.frame(width: 22, height: 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 400, height: 443, alignment: .topLeading)
        .background(QuitAllTheme.windowBackground)
    }

    private func row<Content: View, Help: View>(
        label: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder help: () -> Help
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn.wrappedValue ? gold : Color.white.opacity(0.12))
                        .frame(width: 14, height: 14)

                    if isOn.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab 2: Shortcuts (Exact 1:1 Clone of QuitAll Shortcuts Tab)

final class ShortcutsTabState: ObservableObject {
    @Published var activateMenuEnabled = true
    @Published var quitAllEnabled = true
    @Published var forceQuitAllEnabled = true
}

struct ShortcutsTabCloneView: View {
    @StateObject private var state = ShortcutsTabState()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                shortcutLine(
                    label: "Activate menu:",
                    isEnabled: $state.activateMenuEnabled,
                    shortcut: "⌥Q"
                )
                shortcutLine(
                    label: "Quit all:",
                    isEnabled: $state.quitAllEnabled,
                    shortcut: "⌥⌘Q"
                )
                shortcutLine(
                    label: "Force quit all:",
                    isEnabled: $state.forceQuitAllEnabled,
                    shortcut: "⌥⇧⌘Q"
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 16)

            HStack(spacing: 10) {
                Text("⌥")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

                Text("Hold down Option to toggle “Quit” and “Force Quit”.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.55))

                Spacer()
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(width: 400, height: 215)
        .background(QuitAllTheme.windowBackground)
    }

    private func shortcutLine(label: String, isEnabled: Binding<Bool>, shortcut: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 94, alignment: .trailing)

            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isEnabled.wrappedValue ? QuitAllTheme.accent : Color.white.opacity(0.12))
                        .frame(width: 14, height: 14)

                    if isEnabled.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                    }
                }
            }
            .buttonStyle(.plain)

            Text(shortcut)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(isEnabled.wrappedValue ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))

            Button {
                // Clear shortcut action
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Tab 3: Support (Exact 1:1 Clone of QuitAll Support Tab)

struct SupportTabCloneView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get in touch for any feedback, questions or feature requests!")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(3)
                .padding(.top, 24)

            Button("Contact") {
                if let url = URL(string: "https://github.com/coreify/quitx/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(width: 400, height: 139, alignment: .topLeading)
        .background(QuitAllTheme.windowBackground)
    }
}

// MARK: - Tab 4: About (Exact 1:1 Clone of QuitAll About Tab)

struct AboutTabCloneView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // 70x70 app icon matching QuitAll
            if let img = NSImage(contentsOfFile: "Support/Icons/icon_128x128.png") ?? NSImage(contentsOfFile: "Support/Icons/AppIcon.icns") ?? Bundle.main.image(forResource: "AppIcon") {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 70, height: 70)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("QuitX")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Text("⚡️ Version 1.0.0")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                Text("Copyright © 2026 Coreify")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.42))

                HStack(spacing: 10) {
                    Button("Say hi") {
                        if let url = URL(string: "https://quitx.coreify.io") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11.5))

                    Button("Check Updates") {
                        if let url = URL(string: "https://github.com/coreify/quitx/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11.5))
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .frame(width: 400, height: 130)
        .background(QuitAllTheme.windowBackground)
    }
}
