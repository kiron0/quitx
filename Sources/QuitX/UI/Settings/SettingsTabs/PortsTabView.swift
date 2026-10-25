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
                HelpPopoverButton(text: "Adds a Ports tab to the menu. It lists every process listening on a TCP port (and UDP if you want), with its app, folder and Docker container, and lets you free the port in one click. The list refreshes on its own while it's open. 🔌")
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
                    HelpPopoverButton(text: "How often the Ports tab rescans while it's open. CPU and memory update every 2 seconds in between.")
                }

                row(label: "Discovery:") {
                    toggle("Include UDP listeners", isOn: binding(\.portsIncludeUDP))
                } help: {
                    HelpPopoverButton(text: "Show UDP sockets next to TCP listeners. UDP adds system and local network services, so the list gets longer.")
                }

                row(label: "Menu Bar:") {
                    toggle("Show listening port count", isOn: binding(\.portsShowMenuBarCount))
                } help: {
                    HelpPopoverButton(text: "Shows how many ports are listening next to the QuitX icon, kept current in the background.")
                }

                row(label: "Group By:") {
                    SettingsChoiceTiles(selection: binding(\.portsGrouping), options: [
                        SettingsChoiceOption(value: .none, title: "None", symbol: "list.bullet"),
                        SettingsChoiceOption(value: .project, title: "Project", symbol: "folder"),
                        SettingsChoiceOption(value: .docker, title: "Docker", symbol: "shippingbox", appBundleIdentifier: "com.docker.docker"),
                        SettingsChoiceOption(value: .process, title: "Process", symbol: "arrow.triangle.branch")
                    ], width: 390)
                } help: {
                    HelpPopoverButton(text: "Group listeners by project folder, Docker container, or the process tree that started them.")
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
                    HelpPopoverButton(text: "Sort by port number, process name, memory or CPU.")
                }

                row(label: "Default:") {
                    SettingsChoiceTiles(selection: binding(\.portsForceKill), options: [
                        SettingsChoiceOption(value: false, title: "Kill", symbol: "power"),
                        SettingsChoiceOption(value: true, title: "Force Kill", symbol: "bolt.fill")
                    ])
                } help: {
                    HelpPopoverButton(text: "Kill asks the process to stop and escalates only if it won't. Force kill stops it at once. Hold ⌥ (Option) to force kill one time.")
                }

                row(label: "Safety:") {
                    toggle("Confirm before killing ports", isOn: binding(\.portsConfirmKill))
                } help: {
                    HelpPopoverButton(text: "Ask before killing a port or a selection of ports.")
                }

                row(label: "Selection:") {
                    toggle("Select all ports by default", isOn: binding(\.portsSelectAllByDefault))
                } help: {
                    HelpPopoverButton(text: "Start with every listener selected, ready for Kill All.")
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
                    HelpPopoverButton(text: "Excluded ports live in the Exclude tab, next to excluded apps. They never show in the Ports tab and are never killed.")
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
