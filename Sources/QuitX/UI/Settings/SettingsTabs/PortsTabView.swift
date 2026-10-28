import SwiftUI

struct PortsTabView: View {
    @EnvironmentObject private var configStore: ConfigStore


    private var enabled: Bool { configStore.config.portsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row(label: "Port Killing:") {
                toggle("Enable port killing", isOn: Binding(
                    get: { configStore.config.portsEnabled },
                    set: { value in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            configStore.config.portsEnabled = value
                        }
                        configStore.save()
                    }
                ))
            } help: {
                HelpPopoverButton(text: "Port bouncer mode! Sniffs out every rogue process holding port 3000 or 8080 hostage, and frees it in a single click. 🚪🔌")
            }

            Group {
                row(label: "Refresh:") {
                    SettingsChoiceTiles(
                        selection: binding(\.portsRefreshSeconds),
                        options: QuitXConfig.portRefreshChoices.map {
                            SettingsChoiceOption(value: $0, title: "\($0) sec", symbol: refreshSymbol($0))
                        },
                        width: 390
                    )
                } help: {
                    HelpPopoverButton(text: "Port surveillance radar! Faster scans catch runaway dev servers instantly; slower scans let your Mac take a leisurely coffee break. ⏱️☕️")
                }

                row(label: "Discovery:") {
                    toggle("Include UDP listeners", isOn: binding(\.portsIncludeUDP))
                } help: {
                    HelpPopoverButton(text: "Cast a wider net! Sniffs UDP packets alongside TCP. Be warned: local network chatter and system gremlins will lengthen your list! 🎣📻")
                }

                row(label: "Group By:") {
                    SettingsChoiceTiles(selection: binding(\.portsGrouping), options: [
                        SettingsChoiceOption(value: .none, title: "None", symbol: "list.bullet"),
                        SettingsChoiceOption(value: .project, title: "Project", symbol: "folder"),
                        SettingsChoiceOption(value: .docker, title: "Docker", symbol: "shippingbox", iconStyle: .dockerOutline),
                        SettingsChoiceOption(value: .process, title: "Process", symbol: "arrow.triangle.branch")
                    ], width: 390)
                } help: {
                    HelpPopoverButton(text: "Organize the chaos! Tidy up listeners by their parent project, container ship, or process family tree so nobody gets lost. 📦🌲")
                }

                row(label: "Sort:") {
                    SettingsChoiceTiles(selection: Binding(
                        get: { configStore.config.portsSortBy },
                        set: {
                            configStore.config.portsSortBy = $0
                            configStore.save()
                            PortListViewModel.shared.resort()
                        }
                    ), options: [
                        SettingsChoiceOption(value: .portAsc, title: "Port Low", symbol: "arrow.up"),
                        SettingsChoiceOption(value: .portDesc, title: "Port High", symbol: "arrow.down"),
                        SettingsChoiceOption(value: .name, title: "Name", symbol: "textformat.abc"),
                        SettingsChoiceOption(value: .memoryDesc, title: "Memory", symbol: "memorychip"),
                        SettingsChoiceOption(value: .cpuDesc, title: "CPU", symbol: "cpu")
                    ])
                } help: {
                    HelpPopoverButton(text: "Line up the offenders: order by port number, name, or shame the greediest CPU and memory hogs right at the top. 📋🐷")
                }

                row(label: "Default:") {
                    SettingsChoiceTiles(selection: binding(\.portsForceKill), options: [
                        SettingsChoiceOption(value: false, title: "Kill", symbol: "power"),
                        SettingsChoiceOption(value: true, title: "Force Kill", symbol: "bolt.fill")
                    ])
                } help: {
                    HelpPopoverButton(text: "Diplomacy or brute force? Standard Kill asks nicely first; Force Kill pulls the plug immediately. Hold ⌥ to override anytime! 🥊🔌")
                }

                row(label: "Safety:") {
                    toggle("Confirm before killing ports", isOn: binding(\.portsConfirmKill))
                } help: {
                    HelpPopoverButton(text: "Think twice before pulling the plug! Gives you a handy 'Wait, really?' confirmation so you don't nuke production by accident. 🦺⚠️")
                }

                row(label: "Selection:") {
                    toggle("Select all ports by default", isOn: binding(\.portsSelectAllByDefault))
                } help: {
                    HelpPopoverButton(text: "Going nuclear! Checks every box right out of the gate so you can liberate all your ports with a single glorious tap. 💣🎯")
                }

                row(label: "Exclude:") {
                    Button {
                        UserDefaults.standard.set(ExcludeSection.ports.rawValue, forKey: ExcludeSection.defaultsKey)
                        SettingsWindowController.shared.show(tab: .exclude)
                    } label: {
                        Label("Manage Excluded Ports…", systemImage: "nosign")
                    }
                    .font(.system(size: 11.5))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } help: {
                    HelpPopoverButton(text: "Diplomatic immunity! Grants protected status to your local database or Redis server so you never accidentally kill your sanity. 🏛️🛡️")
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.42)

            Spacer(minLength: 0)
        }
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<QuitXConfig, T>) -> Binding<T> {
        Binding(
            get: { configStore.config[keyPath: keyPath] },
            set: {
                configStore.config[keyPath: keyPath] = $0
                configStore.save()
            }
        )
    }

    private func refreshSymbol(_ seconds: Int) -> String {
        switch seconds {
        case 1: return "hare"
        case 2, 3: return "speedometer"
        case 5: return "gauge.with.dots.needle.50percent"
        default: return "tortoise"
        }
    }
}
