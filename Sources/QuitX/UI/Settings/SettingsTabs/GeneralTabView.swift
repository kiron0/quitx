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

    private var systemMaxGB: Int {
        max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    private var minMemoryGB: Int {
        max(1, min(systemMaxGB, Int((Double(systemMaxGB) * 0.6).rounded())))
    }

    private var cpuThreshold: Binding<Int> {
        Binding(
            get: { max(80, min(100, Int(configStore.config.hogCpuThreshold))) },
            set: {
                configStore.config.hogCpuThreshold = Double(min(100, max(80, $0)))
                configStore.save()
            }
        )
    }

    private var memoryGB: Binding<Int> {
        Binding(
            get: { min(systemMaxGB, max(minMemoryGB, (configStore.config.memoryPressureThresholdMB + 512) / 1024)) },
            set: {
                configStore.config.memoryPressureThresholdMB = min(systemMaxGB, max(minMemoryGB, $0)) * 1024
                configStore.save()
            }
        )
    }

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
                HelpPopoverButton(text: "Tidy up before nap time! Tucks your Mac into bed by gently closing safe apps when it nods off. 😴🌙")
            }

            row(label: "") {
                toggle("Quit apps on screen lock", isOn: Binding(
                    get: { configStore.config.quitOnScreenLock },
                    set: { configStore.config.quitOnScreenLock = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Lock and roll: walk away knowing stray apps get quietly dismissed behind you. Safe and sound. 🔒💨")
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
                HelpPopoverButton(text: "Live pulse of your machine: glanceable CPU load beside the QuitX icon, synced every 2 seconds. 🏎️💨")
            }

            row(label: "") {
                toggle("Save power on battery", isOn: Binding(
                    get: { configStore.config.batterySaverEnabled },
                    set: { configStore.config.batterySaverEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Sip power like fine wine! Auto-quit timers cut in half and CPU checks slow to 10s to spare your battery. 🔋🍷")
            }

            row(label: "Health:") {
                toggle("Warn & rescue CPU hogs", isOn: Binding(
                    get: { configStore.config.hogAlertEnabled },
                    set: { configStore.config.hogAlertEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Catch runaway apps roasting your lap! Slaps a spicy flame badge on anything over your CPU limit, then force quits inactive apps only. Your active app never touched. 🔥🍳")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("CPU over")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)

                    Text("\(cpuThreshold.wrappedValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(minWidth: 20, alignment: .trailing)

                    Stepper("", value: cpuThreshold, in: 80...100, step: 5)
                        .labelsHidden()

                    Text("%")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                }
                .disabled(!configStore.config.hogAlertEnabled)
                .opacity(configStore.config.hogAlertEnabled ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Your CPU tripwire: load over this percent immediately triggers Smart Rescue. Force quits inactive apps only.")
            }

            row(label: "") {
                toggle("Rescue on memory pressure", isOn: Binding(
                    get: { configStore.config.memoryPressureQuitEnabled },
                    set: { configStore.config.memoryPressureQuitEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "When RAM runs dry past your memory limit, QuitX force quits inactive apps only — never the one you're using. Change your mind? Reopen from the gear menu. 🧠🚪")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("Memory over")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)

                    Text("\(memoryGB.wrappedValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(minWidth: 16, alignment: .trailing)

                    Stepper("", value: memoryGB, in: minMemoryGB...systemMaxGB)
                        .labelsHidden()

                    Text("GB of \(systemMaxGB)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                }
                .disabled(!configStore.config.memoryPressureQuitEnabled)
                .opacity(configStore.config.memoryPressureQuitEnabled ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Your memory tripwire in gigabytes, capped at this Mac's total RAM. When macOS reports pressure and any app exceeds it, Smart Rescue force quits inactive apps only.")
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
                    Text("\(state.autoQuitValue)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(minWidth: 20, alignment: .trailing)

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
        .frame(width: 400, height: 481, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
        .onAppear {
            state.syncFromMinutes(configStore.config.quitInactiveAfterMinutes)
            if configStore.config.hogCpuThreshold < 80 {
                configStore.config.hogCpuThreshold = 80
                configStore.save()
            }
            let currentMemGB = (configStore.config.memoryPressureThresholdMB + 512) / 1024
            if currentMemGB < minMemoryGB {
                configStore.config.memoryPressureThresholdMB = minMemoryGB * 1024
                configStore.save()
            }
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
                HelpPopoverButton(text: "Some like 'em all checked, some like a clean slate. You do you — pick your starting flavor! 🍦🙌")
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
                HelpPopoverButton(text: "Look before you leap! Adds a friendly 'Are you sure?' safety net before kicking out individual apps. 🛡️🦺")
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
