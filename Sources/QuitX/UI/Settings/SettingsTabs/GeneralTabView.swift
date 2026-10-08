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

fileprivate func appearanceRadio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        selected ? Color.accentColor : Color.secondary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .frame(width: 14, height: 14)
                if selected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
            }
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

            row(label: "Menu Bar:") {
                toggle("Show CPU & memory in menu bar", isOn: Binding(
                    get: { configStore.config.showMenuBarStats },
                    set: {
                        configStore.config.showMenuBarStats = $0
                        configStore.save()
                        StatusItemController.shared?.updateMenuBarStats()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Live pulse of your machine: a separate usage item beside the QuitX icon shows whole-system CPU percent and memory use in GB or percentage. Click it for a blurred detail panel. Refreshes every second (5 seconds on battery saver). 🏎️💨")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("Style format")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(width: 86, alignment: .leading)

                    HStack(spacing: 16) {
                        appearanceRadio("Icon", selected: configStore.config.menuBarStatStyle == .icon) {
                            configStore.config.menuBarStatStyle = .icon
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                        appearanceRadio("Text", selected: configStore.config.menuBarStatStyle == .text) {
                            configStore.config.menuBarStatStyle = .text
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    }
                }
                .disabled(!configStore.config.showMenuBarStats)
                .opacity(configStore.config.showMenuBarStats ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Symbols or letters? Flaunt tiny sleek icons or spell it out loud with CPU and MEM tags. 🏷️✨")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("Memory format")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(width: 86, alignment: .leading)

                    HStack(spacing: 16) {
                        appearanceRadio("GB", selected: configStore.config.menuBarMemoryUnit == .gb) {
                            configStore.config.menuBarMemoryUnit = .gb
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                        appearanceRadio("Percentage", selected: configStore.config.menuBarMemoryUnit == .percentage) {
                            configStore.config.menuBarMemoryUnit = .percentage
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    }
                }
                .disabled(!configStore.config.showMenuBarStats)
                .opacity(configStore.config.showMenuBarStats ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Gigabytes for raw numbers or percentages for drama! Pick how your memory flexes in the menu bar. 🏋️‍♂️📈")
            }

            if #available(macOS 26.0, *) {
                row(label: "Appearance:") {
                    HStack(spacing: 18) {
                        appearanceRadio("Classic", selected: !configStore.config.liquidGlassEnabled) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                configStore.config.liquidGlassEnabled = false
                            }
                            SettingsWindowController.shared.applyWindowChrome()
                            configStore.save()
                        }
                        appearanceRadio("Liquid Glass", selected: configStore.config.liquidGlassEnabled) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                configStore.config.liquidGlassEnabled = true
                            }
                            SettingsWindowController.shared.applyWindowChrome()
                            configStore.save()
                        }
                    }
                    .fixedSize()
                } help: {
                    HelpPopoverButton(text: "Classic retro solidity or futuristic translucent Liquid Glass drip. Dress your windows for success. 🔮🪞")
                }
            }

            row(label: "Sort:") {
                Picker("", selection: Binding(
                    get: { configStore.config.sortBy },
                    set: { configStore.config.sortBy = $0; configStore.save() }
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
                    set: { configStore.config.force = ($0 == "Force quit" ? .force : .normal); configStore.save() }
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
                }
                .font(.system(size: 11.5))
            } help: {
                HelpPopoverButton(text: "The nuclear option! Wipes your preferences clean back to factory fresh. No hard feelings. 🧼💥")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: SettingsTab.general.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
    }
}

struct AutomationTabCloneView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = GeneralTabState()

    private var systemMaxGB: Int {
        max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    private var minMemoryGB: Int {
        max(1, min(systemMaxGB, Int((Double(systemMaxGB) * 0.8).rounded())))
    }

    private var cpuThreshold: Binding<Int> {
        Binding(
            get: { Int(configStore.config.effectiveHogCpuThreshold) },
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

            row(label: "Power:") {
                toggle("Save power on battery", isOn: Binding(
                    get: { configStore.config.batterySaverEnabled },
                    set: { configStore.config.batterySaverEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Sip power like fine wine! Auto-quit timers cut in half and CPU checks slow to 10s to spare your battery. 🔋🍷")
            }

            let sleepLockOn = configStore.config.quitOnSleep || configStore.config.quitOnScreenLock
            row(label: "Sleep & Lock:") {
                toggle("Quit apps when Mac sleeps or locks", isOn: Binding(
                    get: { sleepLockOn },
                    set: { both in
                        let wasOn = configStore.config.quitOnSleep || configStore.config.quitOnScreenLock
                        configStore.config.quitOnSleep = both
                        configStore.config.quitOnScreenLock = both
                        if both && !wasOn {
                            configStore.config.sleepLockStartMinutes = 0
                            configStore.config.sleepLockEndMinutes = 360
                        }
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Night-shift janitor for your Mac! Only kicks apps out between your sleep hours (defaults 12 AM to 6 AM). Sneak naps during the day guilt-free. 🌙😴")
            }

            let subsOn = sleepLockOn
            row(label: "") {
                HStack(spacing: 6) {
                    Text("Time format")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(width: 86, alignment: .leading)

                    HStack(spacing: 16) {
                        appearanceRadio("24-hour", selected: configStore.config.sleepLockUse24Hour) {
                            configStore.config.sleepLockUse24Hour = true
                            configStore.save()
                        }
                        appearanceRadio("12-hour", selected: !configStore.config.sleepLockUse24Hour) {
                            configStore.config.sleepLockUse24Hour = false
                            configStore.save()
                        }
                    }
                }
                .disabled(!subsOn)
                .opacity(subsOn ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Military precision or morning-coffee casual? Pick 24-hour or 12-hour AM/PM dials for your sleep schedule. ⏰☕️")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("From:")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(width: 86, alignment: .leading)

                    timePickers(start: true)
                }
                .disabled(!subsOn)
                .opacity(subsOn ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Bedtime curfew begins! Unattended apps take a hike starting from this hour. 🌜🛌")
            }

            row(label: "") {
                HStack(spacing: 6) {
                    Text("To:")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary)
                        .frame(width: 86, alignment: .leading)

                    timePickers(start: false)
                }
                .disabled(!subsOn)
                .opacity(subsOn ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Morning call! Night patrol clocks out and your day resumes without automated quits. ☀️☕️")
            }

            row(label: "Health:") {
                toggle("Warn & rescue CPU hogs", isOn: Binding(
                    get: { configStore.config.hogAlertEnabled },
                    set: { configStore.config.hogAlertEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Catch runaway apps roasting your lap! Watches whole-system CPU. After you flip this on, QuitX waits 15 seconds to arm, then acts only when load stays over your limit 15 seconds. No instant ambush. Force quits inactive apps only. 🔥🍳")
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
                HelpPopoverButton(text: "Set the panic meter! If whole-system CPU cooks past this mark for 15 solid seconds, inactive culprits get escorted out. 🚨🍳")
            }

            row(label: "") {
                toggle("Rescue on memory pressure", isOn: Binding(
                    get: { configStore.config.memoryPressureQuitEnabled },
                    set: { configStore.config.memoryPressureQuitEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "When memory runs dry past your limit, QuitX force quits inactive apps only — never the one you're using. Change your mind? Reopen from the gear menu. 🧠🚪")
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
                HelpPopoverButton(text: "Memory lifeguard on duty! When memory gets swampy past your limit, inactive freeloaders get shown the door. 🏊‍♂️🛟")
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
                HelpPopoverButton(text: "Ghostbusters for idle apps! Automatically boots dormant apps into the sunset when you wander away. 👻👋")
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
                HelpPopoverButton(text: "The patience dial! How long an unused app gets to loiter before QuitX gently gives it the boot. ⏳👋")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: SettingsTab.automation.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
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

    private func storedMinutes(start: Bool) -> Int {
        start ? configStore.config.sleepLockStartMinutes : configStore.config.sleepLockEndMinutes
    }

    private func setStoredMinutes(start: Bool, _ value: Int) {
        let clamped = min(1439, max(0, value))
        if start {
            configStore.config.sleepLockStartMinutes = clamped
        } else {
            configStore.config.sleepLockEndMinutes = clamped
        }
        configStore.save()
    }

    private var hourChoices: [Int] {
        configStore.config.sleepLockUse24Hour ? Array(0...23) : Array(1...12)
    }

    private func hourBinding(start: Bool) -> Binding<Int> {
        Binding(
            get: {
                let hour = storedMinutes(start: start) / 60
                if configStore.config.sleepLockUse24Hour { return hour }
                let hour12 = hour % 12
                return hour12 == 0 ? 12 : hour12
            },
            set: { newHour in
                let current = storedMinutes(start: start)
                let minutePart = current % 60
                let new24: Int
                if configStore.config.sleepLockUse24Hour {
                    new24 = newHour
                } else {
                    let isPM = (current / 60) >= 12
                    new24 = (newHour % 12) + (isPM ? 12 : 0)
                }
                setStoredMinutes(start: start, new24 * 60 + minutePart)
            }
        )
    }

    private func minuteBinding(start: Bool) -> Binding<Int> {
        Binding(
            get: { storedMinutes(start: start) % 60 },
            set: { newMinute in
                setStoredMinutes(start: start, (storedMinutes(start: start) / 60) * 60 + newMinute)
            }
        )
    }

    private func meridiemBinding(start: Bool) -> Binding<Bool> {
        Binding(
            get: { (storedMinutes(start: start) / 60) >= 12 },
            set: { wantPM in
                let current = storedMinutes(start: start)
                var hour = current / 60
                let isPM = hour >= 12
                if wantPM != isPM {
                    hour = wantPM ? hour + 12 : hour - 12
                }
                setStoredMinutes(start: start, hour * 60 + current % 60)
            }
        )
    }

    private func timePickers(start: Bool) -> some View {
        HStack(spacing: 4) {
            Picker("", selection: hourBinding(start: start)) {
                ForEach(hourChoices, id: \.self) { hour in
                    Text(configStore.config.sleepLockUse24Hour ? String(format: "%02d", hour) : "\(hour)")
                        .tag(hour)
                }
            }
            .frame(width: 58)
            .labelsHidden()

            Text(":")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary)

            Picker("", selection: minuteBinding(start: start)) {
                ForEach(0..<60, id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .frame(width: 62)
            .labelsHidden()

            if !configStore.config.sleepLockUse24Hour {
                Picker("", selection: meridiemBinding(start: start)) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .frame(width: 58)
                .labelsHidden()
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
                HelpPopoverButton(text: "Herd the digital clones! Bundles duplicate processes of the same app into a single neat row instead of an army. 👯‍♂️📦")
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
                toggle("Select apps by default", isOn: Binding(
                    get: { configStore.config.defaultSelectAll },
                    set: {
                        configStore.config.defaultSelectAll = $0
                        configStore.save()
                        AppListViewModel.shared.applyDefaultSelection()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Some like 'em all checked, some like a clean slate. You do you — pick your starting flavor! 🍦🙌")
            }

            row(label: "") {
                toggle("Disable quit tips", isOn: Binding(
                    get: { configStore.config.disableQuitTips },
                    set: { configStore.config.disableQuitTips = $0; configStore.save() }
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
        .frame(width: 480, height: SettingsTab.advanced.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
    }
}
