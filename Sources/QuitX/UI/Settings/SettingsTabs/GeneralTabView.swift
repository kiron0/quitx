import SwiftUI
import AppKit

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

fileprivate let labelColumnWidth: CGFloat = 90

fileprivate func row<Content: View, Help: View>(
    label: String,
    @ViewBuilder content: () -> Content,
    @ViewBuilder help: () -> Help
) -> some View {
    ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: labelColumnWidth, alignment: .trailing)

            content().fixedSize()

            Spacer(minLength: 0)

            help()
        }
        .frame(height: 25)

        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)

            HStack(alignment: .center, spacing: 10) {
                content().fixedSize()

                Spacer(minLength: 0)

                help()
            }
            .frame(height: 25)
        }
    }
}

fileprivate func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
    Button {
        isOn.wrappedValue.toggle()
    } label: {
        HStack(spacing: 8) {
            QuitXSelectionCheckbox(isSelected: isOn.wrappedValue)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
    }
    .buttonStyle(.plain)
}

struct GeneralTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared
    @StateObject private var state = GeneralTabState()

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

            row(label: "Sleep & Lock:") {
                toggle("Quit apps when Mac sleeps", isOn: Binding(
                    get: { configStore.config.quitOnSleep },
                    set: { configStore.config.quitOnSleep = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Tidy up before nap time. Gracefully quits safe apps on sleep, skipping excluded, music, and protected apps. No confirmation shown.")
            }

            row(label: "") {
                toggle("Quit apps on screen lock", isOn: Binding(
                    get: { configStore.config.quitOnScreenLock },
                    set: { configStore.config.quitOnScreenLock = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Lock and leave: same safe-app quit runs when the screen locks. 🔒")
            }

            row(label: "Menu & Power:") {
                toggle("Show CPU in menu bar", isOn: Binding(
                    get: { configStore.config.showMenuBarStats },
                    set: {
                        configStore.config.showMenuBarStats = $0
                        configStore.save()
                        StatusItemController.shared?.updateMenuBarStats()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Glanceable load: total CPU percent lives next to the QuitX icon, refreshed every 2 seconds (slowed to 10 seconds on battery saver).")
            }

            row(label: "") {
                toggle("Save power on battery", isOn: Binding(
                    get: { configStore.config.batterySaverEnabled },
                    set: { configStore.config.batterySaverEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "On battery: auto-quit timeouts halve and live stats refresh every 10 seconds instead of 2. 🔋")
            }

            row(label: "Health:") {
                toggle("Warn about CPU hogs", isOn: Binding(
                    get: { configStore.config.hogAlertEnabled },
                    set: { configStore.config.hogAlertEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Flags apps holding 80%+ CPU for 5+ minutes with a flame badge plus one notification per offender. 🔥")
            }

            row(label: "") {
                toggle("Quit memory hogs under pressure", isOn: Binding(
                    get: { configStore.config.memoryPressureQuitEnabled },
                    set: { configStore.config.memoryPressureQuitEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "When macOS reports memory pressure, gracefully quits regular apps using over 1 GB. Excluded, music, and Never-ruled apps stay safe. 🧠")
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
                HelpPopoverButton(text: "Keep your apps in line: sort alphabetically, by heavy CPU hogs, or by memory gobblers. 📊🧭")
            }

            row(label: "Default:") {
                Picker("", selection: Binding(
                    get: { configStore.config.force == .force ? "Force quit" : "Normal quit" },
                    set: { configStore.config.force = ($0 == "Force quit" ? .force : .normal); configStore.save(refreshAppList: true) }
                )) {
                    Text("Normal quit").tag("Normal quit")
                    Text("Force quit").tag("Force quit")
                }
                .frame(width: 175, alignment: .leading)
                .labelsHidden()
            } help: {
                HelpPopoverButton(text: "Choose how aggressive QuitX should be by default. Tip: hold ⌥ (Option) anytime to flip modes on the fly. ⚡️")
            }

            row(label: "Reset:") {
                Button("Reset all") {
                    SettingsResetService.shared.resetAllSettings()
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
        .frame(width: 400, height: 421, alignment: .topLeading)
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
}

struct AdvancedTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            row(label: "Background:") {
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

            row(label: "Protection:") {
                toggle("Never quit music apps", isOn: Binding(
                    get: { configStore.config.neverQuitMusic },
                    set: { configStore.config.neverQuitMusic = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Don't stop believin', hold on to that feelin' — and your music! Exclude Spotify and Apple Music from auto or manual Quit actions. 🎵")
            }

            row(label: "Behavior:") {
                toggle("Deselect apps by default", isOn: Binding(
                    get: { !configStore.config.defaultSelectAll },
                    set: {
                        configStore.config.defaultSelectAll = !$0
                        configStore.save(refreshAppList: true)
                        AppListViewModel.shared.applyDefaultSelection()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Some like the whole app list selected, some like ‘em all deselected. Now you get to choose. 🙌")
            }

            row(label: "") {
                toggle("Disable quit tips", isOn: Binding(
                    get: { configStore.config.disableQuitTips },
                    set: { configStore.config.disableQuitTips = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "The rotating tips at the bottom of the QuitX dropdown will cease to show. It’s okay. We can still be friends. 🤗")
            }

            row(label: "") {
                toggle("Confirm single app quit & restart", isOn: Binding(
                    get: { configStore.config.confirmIndividualAction },
                    set: { configStore.config.confirmIndividualAction = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Look before you leap. Adds an 'Are you sure?' safety net before kicking out individual apps. 🛡️")
            }

            row(label: "Extras:") {
                toggle("Include Finder Windows in list", isOn: Binding(
                    get: { configStore.config.includeFinder },
                    set: { configStore.config.includeFinder = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "Find yourself finding Finder windows too often? Close every single one in one fell swoop. 📁🗂️")
            }

            row(label: "") {
                toggle("Include Empty Trash in list", isOn: Binding(
                    get: { configStore.config.includeTrash },
                    set: { configStore.config.includeTrash = $0; configStore.save(refreshAppList: true) }
                ))
            } help: {
                HelpPopoverButton(text: "A truly fresh start without a restart. Take out the trash at the same time you take out the apps! 🗑️🧹")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 400, height: 271, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
    }
}
