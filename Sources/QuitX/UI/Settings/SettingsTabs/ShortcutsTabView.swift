import SwiftUI
import AppKit

@MainActor
final class ShortcutsViewState: ObservableObject {
    @Published var recordingRow: String? = nil
    var localMonitor: Any? = nil

    func startMonitor(sm: ShortcutManager) {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return event }
            guard event.window == NSApp.keyWindow else { return event }
            if self.processEvent(event, row: row, sm: sm) {
                return nil
            }
            return event
        }
    }

    func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
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
        let slot: ShortcutManager.Slot?
        switch row {
        case "activate": slot = .activateMenu
        case "quit": slot = .quitAll
        case "force": slot = .forceQuitAll
        case "settings": slot = .openSettings
        case "refresh": slot = .refreshApps
        case "help": slot = .openHelp
        case "changelog": slot = .openChangelog
        case "uninstaller": slot = .openUninstaller
        default: slot = nil
        }
        if let slot {
            sm.setKeys(keys, for: slot)
        }
    }
}

struct ShortcutsTabView: View {
    @ObservedObject private var sm = ShortcutManager.shared
    @StateObject private var viewState = ShortcutsViewState()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                SettingsSectionHeader(title: "Menu Access", symbol: "command.square")

                shortcutRow(
                    id: "activate",
                    symbol: "menubar.rectangle",
                    title: "Open QuitX",
                    detail: "Bring the menu forward from anywhere.",
                    isEnabled: $sm.activateMenuEnabled,
                    keys: $sm.activateMenuKeys,
                    help: "Summon QuitX like a wizard! Pops open the menu instantly so you don't have to haul your mouse all the way to the top menu bar. 🪄🎩"
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                SettingsSectionHeader(title: "App Actions", symbol: "power")

                shortcutRow(
                    id: "quit",
                    symbol: "power",
                    title: "Quit Selected Apps",
                    detail: "Run the normal Quit action immediately.",
                    isEnabled: $sm.quitAllEnabled,
                    keys: $sm.quitAllKeys,
                    help: "Polite eviction notice! Gently asks selected apps to save their work, pack their bags, and exit gracefully. 🚪👋"
                )

                Divider()
                    .opacity(0.35)
                    .padding(.leading, 42)

                shortcutRow(
                    id: "force",
                    symbol: "exclamationmark.octagon",
                    title: "Force Quit Selected Apps",
                    detail: "Stop unresponsive apps without waiting.",
                    isEnabled: $sm.forceQuitAllEnabled,
                    keys: $sm.forceQuitAllKeys,
                    help: "No more Mr. Nice Guy. Instantly vaporizes frozen or rebellious apps that refuse to take a hint. ⚡️💥"
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                SettingsSectionHeader(title: "Navigation", symbol: "arrow.triangle.turn.up.right.diamond")

                shortcutRow(
                    id: "settings",
                    symbol: "gearshape",
                    title: "Open Settings",
                    detail: "Jump straight to QuitX settings.",
                    isEnabled: $sm.openSettingsEnabled,
                    keys: $sm.openSettingsKeys,
                    help: "Beam straight to mission control! Jump into QuitX preferences from anywhere without clicking around. 🛸🎛️"
                )

                shortcutDivider

                shortcutRow(
                    id: "refresh",
                    symbol: "arrow.clockwise",
                    title: "Refresh App List",
                    detail: "Rescan running apps immediately.",
                    isEnabled: $sm.refreshAppsEnabled,
                    keys: $sm.refreshAppsKeys,
                    help: "Radar sweep! Forces QuitX to recount all your running apps in a flash so you always see what's actually running. 📡👀"
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                SettingsSectionHeader(title: "QuitX Tools", symbol: "square.grid.2x2")

                shortcutRow(
                    id: "help",
                    symbol: "questionmark.circle",
                    title: "Open Help",
                    detail: "Open guides and feature explanations.",
                    isEnabled: $sm.openHelpEnabled,
                    keys: $sm.openHelpKeys,
                    help: "SOS distress beacon! Pulls up guides, secrets, and answers right when you're scratching your head. 🆘📖"
                )

                shortcutDivider

                shortcutRow(
                    id: "changelog",
                    symbol: "sparkles",
                    title: "Open What's New",
                    detail: "See the latest improvements and fixes.",
                    isEnabled: $sm.openChangelogEnabled,
                    keys: $sm.openChangelogKeys,
                    help: "Catch up on the gossip! Spills all the juicy details on new features, speedups, and bug fixes fresh out of the oven. 🗞️✨"
                )

                shortcutDivider

                shortcutRow(
                    id: "uninstaller",
                    symbol: "trash.slash",
                    title: "Open Uninstall Apps",
                    detail: "Choose an app and remove its leftovers.",
                    isEnabled: $sm.openUninstallerEnabled,
                    keys: $sm.openUninstallerKeys,
                    help: "The spring cleaning shortcut! Jumps straight to uninstaller so you can purge unwanted apps and their sneaky leftover files. 🧹🗑️"
                )
            }

            if let error = sm.shortcutError ?? sm.registrationError {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.red)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text((sm.shortcutError?.contains("already assigned") == true) ? "Shortcut Conflict" : "Shortcut Invalid")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.red)

                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
            } else {
                SettingsInlineNote(
                    symbol: "option",
                    title: "Hold Option for a one-time mode switch",
                    detail: "In the QuitX menu, ⌥ temporarily switches between Quit and Force Quit."
                )
            }
        }
        .padding(.top, 14)
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        .onAppear {
            viewState.startMonitor(sm: sm)
        }
        .onDisappear {
            viewState.stopMonitor()
        }
    }

    private var shortcutDivider: some View {
        Divider()
            .opacity(0.35)
            .padding(.leading, 42)
    }

    private func shortcutRow(
        id: String,
        symbol: String,
        title: String,
        detail: String,
        isEnabled: Binding<Bool>,
        keys: Binding<[String]>,
        help: String
    ) -> some View {
        let active = isEnabled.wrappedValue
        let isRecording = (viewState.recordingRow == id)
        let keyList = keys.wrappedValue

        return HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isEnabled.wrappedValue.toggle()
                }
            } label: {
                SettingsSwitchIndicator(isOn: active)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enable \(title)")
            .accessibilityValue(active ? "On" : "Off")

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? QuitXTheme.accent.opacity(0.11) : Color.primary.opacity(0.05))
                    .frame(width: 28, height: 28)

                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? QuitXTheme.accent : Color.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(active ? Color.primary : Color.secondary)

                    HelpPopoverButton(text: help)
                }

                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isRecording {
                Button {
                    viewState.recordingRow = nil
                } label: {
                    HStack(spacing: 5) {
                        Text("Press keys…")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(QuitXTheme.accent)
                        Text("(esc to cancel)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(QuitXTheme.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(QuitXTheme.accent, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            } else if keyList.isEmpty {
                Button {
                    if !active { isEnabled.wrappedValue = true }
                    viewState.recordingRow = id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Record Shortcut")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(QuitXTheme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(QuitXTheme.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(QuitXTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Button {
                        if !active { isEnabled.wrappedValue = true }
                        viewState.recordingRow = id
                    } label: {
                        HStack(spacing: 3) {
                            ForEach(keyList, id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(active ? Color.primary : Color.secondary)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .padding(.horizontal, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .fill(active ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3.5)
                                            .stroke(active ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(active ? 0.06 : 0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Click to change shortcut")

                    Button {
                        viewState.applyKeys([], for: id, sm: sm)
                        if viewState.recordingRow == id { viewState.recordingRow = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary.opacity(active ? 0.65 : 0.3))
                    }
                    .buttonStyle(.plain)
                    .help("Remove shortcut")
                }
            }
        }
        .padding(.leading, 33)
        .padding(.vertical, 3)
        .frame(minHeight: 40)
    }
}
