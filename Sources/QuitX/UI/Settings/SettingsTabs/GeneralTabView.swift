import SwiftUI
import AppKit

private final class GeneralTabPresentationState: ObservableObject {
    @Published var showResetConfirmation = false
}
struct GeneralTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared
    @StateObject private var presentationState = GeneralTabPresentationState()

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
                HelpPopoverButton(text: "PEW PEW! A deeply satisfying arcade laser blast fires whenever you vaporize an app. 👾🔫")
            }

            row(label: "Menu Bar:") {
                toggle("Show stats in menu bar", isOn: Binding(
                    get: { configStore.config.showMenuBarStats },
                    set: {
                        configStore.config.showMenuBarStats = $0
                        configStore.config.menuBarShowCpu = $0
                        configStore.config.menuBarShowMemory = $0
                        configStore.config.menuBarShowGpu = $0
                        configStore.config.batteryMenuBarEnabled = $0
                        configStore.save()
                        StatusItemController.shared?.updateMenuBarStats()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Your Mac's vital signs on blast! Shows live CPU, memory, GPU, and battery in your menu bar. Click any stat for its own dedicated window. 🏎️⚡")
            }

            row(label: "") {
                HStack(spacing: 16) {
                    toggle("CPU", isOn: Binding(
                        get: { configStore.config.menuBarShowCpu },
                        set: {
                            configStore.config.menuBarShowCpu = $0
                            configStore.config.showMenuBarStats = configStore.config.menuBarStatsEnabled
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    ))
                    toggle("Memory", isOn: Binding(
                        get: { configStore.config.menuBarShowMemory },
                        set: {
                            configStore.config.menuBarShowMemory = $0
                            configStore.config.showMenuBarStats = configStore.config.menuBarStatsEnabled
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    ))
                    toggle("GPU", isOn: Binding(
                        get: { configStore.config.menuBarShowGpu },
                        set: {
                            configStore.config.menuBarShowGpu = $0
                            configStore.config.showMenuBarStats = configStore.config.menuBarStatsEnabled
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    ))
                    toggle("Battery", isOn: Binding(
                        get: { configStore.config.batteryMenuBarEnabled },
                        set: {
                            configStore.config.batteryMenuBarEnabled = $0
                            configStore.config.showMenuBarStats = configStore.config.menuBarStatsEnabled
                            configStore.save()
                            StatusItemController.shared?.updateMenuBarStats()
                        }
                    ))
                }
                .disabled(!configStore.config.showMenuBarStats)
                .opacity(configStore.config.showMenuBarStats ? 1.0 : 0.42)
            } help: {
                HelpPopoverButton(text: "Pick which stats stay visible. Master switch turns all on or off.")
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
                .disabled(!configStore.config.menuBarStatsEnabled)
                .opacity(configStore.config.menuBarStatsEnabled ? 1.0 : 0.42)
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
                .disabled(!configStore.config.menuBarStatsEnabled)
                .opacity(configStore.config.menuBarStatsEnabled ? 1.0 : 0.42)
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
                HelpPopoverButton(text: "Line up the suspects: alphabetical roll call, sizzling CPU hogs roasting your lap, or greedy memory munchers. 📊🧭")
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
                HelpPopoverButton(text: "Choose your default vibe: polite 'please quit' or ruthless force quit. Pro tip: hold ⌥ (Option) anytime to swap modes on the fly! ⚡️")
            }

            row(label: "Reset:") {
                Button("Reset all") {
                    presentationState.showResetConfirmation = true
                }
                .font(.system(size: 11.5))
            } help: {
                HelpPopoverButton(text: "Restores preferences, shortcuts, and login settings to their defaults. Asks for confirmation first. 🧼")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: 480, height: SettingsTab.general.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
        .alert("Reset all settings?", isPresented: $presentationState.showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                SettingsResetService.shared.resetAllSettings()
            }
        } message: {
            Text("This restores preferences, shortcuts, and launch-at-login to their defaults. It cannot be undone.")
        }
    }
}
