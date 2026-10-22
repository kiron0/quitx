import AppKit
import SwiftUI
import Foundation

final class AutomationTabState: ObservableObject {
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

struct AutomationTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = AutomationTabState()
    @ObservedObject private var lastWindowQuitService = LastWindowQuitService.shared

    private var systemMaxGB: Int {
        max(1, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    private var minMemoryGB: Int {
        max(1, min(systemMaxGB, Int((Double(systemMaxGB) * 0.25).rounded())))
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

            let sleepOn = configStore.config.quitOnSleep
            row(label: "Sleep:") {
                toggle("Quit apps when Mac sleeps", isOn: Binding(
                    get: { configStore.config.quitOnSleep },
                    set: { enabled in
                        let wasOn = configStore.config.quitOnSleep
                        configStore.config.quitOnSleep = enabled
                        configStore.config.quitOnScreenLock = false
                        if enabled && !wasOn {
                            configStore.config.sleepLockStartMinutes = 0
                            configStore.config.sleepLockEndMinutes = 360
                        }
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Night-shift janitor for your Mac! Only kicks apps out when your Mac sleeps between scheduled hours (defaults 12 AM to 6 AM). Sneak naps during the day guilt-free. 🌙😴")
            }

            let subsOn = sleepOn
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
            }

            row(label: "Windows:") {
                toggle("Quit app when its last window closes", isOn: Binding(
                    get: { configStore.config.quitWhenLastWindowClosed },
                    set: { enabled in
                        lastWindowQuitService.refreshAccessibilityTrust()
                        if enabled && !lastWindowQuitService.accessibilityTrusted {
                            LastWindowQuitService.requestAccessibilityPermission()
                            LastWindowQuitService.openAccessibilitySettings()
                            return
                        }
                        configStore.config.quitWhenLastWindowClosed = enabled
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Grant Accessibility below, then enable this option. QuitX directly force-quits an app after its last window closes via the red close button (x) or ⌘W. Minimized, hidden, and off-Space windows never trigger it. 🪟🔴")
            }

            row(label: "") {
                if lastWindowQuitService.accessibilityTrusted {
                    HStack(spacing: 10) {
                        Label("Accessibility allowed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)

                        Button("Remove Access…") {
                            configStore.config.quitWhenLastWindowClosed = false
                            configStore.save()
                            LastWindowQuitService.openAccessibilitySettings()
                        }
                        .font(.system(size: 11.5))
                        .help("Disables this automation and opens macOS Accessibility settings. Turn off QuitX there to remove the system permission.")
                    }
                } else {
                    Button("Allow Accessibility…") {
                        LastWindowQuitService.requestAccessibilityPermission()
                        LastWindowQuitService.openAccessibilitySettings()
                    }
                    .font(.system(size: 11.5))
                }
            }

            row(label: "Health:") {
                toggle("Warn & rescue CPU hogs", isOn: Binding(
                    get: { configStore.config.hogAlertEnabled },
                    set: { configStore.config.hogAlertEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "Keep your Mac cool and responsive! Watches CPU hogs and memory pressure, gently evicting background freeloaders when limits trip. 🔥🧠")
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
            }

            row(label: "") {
                toggle("Rescue on memory pressure", isOn: Binding(
                    get: { configStore.config.memoryPressureQuitEnabled },
                    set: { configStore.config.memoryPressureQuitEnabled = $0; configStore.save() }
                ))
            } help: {
                HelpPopoverButton(text: "When greedy apps eat all your memory, QuitX gently escorts background freeloaders to the exit — never the app in front of you. Regret it? Reopen from the gear menu. 🧠🚪")
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
            lastWindowQuitService.refreshAccessibilityTrust()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lastWindowQuitService.refreshAccessibilityTrust()
        }
        .task {
            while !Task.isCancelled {
                lastWindowQuitService.refreshAccessibilityTrust()
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
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
