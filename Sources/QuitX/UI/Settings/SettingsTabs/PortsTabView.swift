import SwiftUI

struct PortsTabView: View {
    @EnvironmentObject private var configStore: ConfigStore

    static let contentHeight: CGFloat = 360

    private var enabled: Bool { configStore.config.portsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row(label: "Ports:") {
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

            Divider()
                .padding(.vertical, 4)

            Group {
                row(label: "Refresh:") {
                    Picker("", selection: binding(\.portsRefreshSeconds)) {
                        ForEach(QuitXConfig.portRefreshChoices, id: \.self) { seconds in
                            Text("Every \(seconds) seconds").tag(seconds)
                        }
                    }
                    .frame(width: 175, alignment: .leading)
                    .labelsHidden()
                } help: {
                    HelpPopoverButton(text: "How often the Ports tab rescans while it's open. CPU and memory update every 2 seconds in between.")
                }

                row(label: "Discovery:") {
                    toggle("Include UDP listeners", isOn: binding(\.portsIncludeUDP))
                } help: {
                    HelpPopoverButton(text: "Show UDP sockets next to TCP listeners. UDP adds system and local network services, so the list gets longer.")
                }

                row(label: "Menu bar:") {
                    toggle("Show listening port count", isOn: binding(\.portsShowMenuBarCount))
                } help: {
                    HelpPopoverButton(text: "Shows how many ports are listening next to the QuitX icon, kept current in the background.")
                }

                row(label: "Group by:") {
                    Picker("", selection: binding(\.portsGrouping)) {
                        ForEach(ListenerGrouping.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .frame(width: 175, alignment: .leading)
                    .labelsHidden()
                } help: {
                    HelpPopoverButton(text: "Group listeners by project folder, Docker container, or the process tree that started them.")
                }

                row(label: "Sort:") {
                    Picker("", selection: Binding(
                        get: { configStore.config.portsSortBy },
                        set: {
                            configStore.config.portsSortBy = $0
                            configStore.save()
                            PortListViewModel.shared.resort()
                        }
                    )) {
                        ForEach(PortSortBy.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .frame(width: 175, alignment: .leading)
                    .labelsHidden()
                } help: {
                    HelpPopoverButton(text: "Sort by port number, process name, memory or CPU.")
                }

                row(label: "Default:") {
                    Picker("", selection: binding(\.portsForceKill)) {
                        Text("Kill (SIGTERM)").tag(false)
                        Text("Force kill (SIGKILL)").tag(true)
                    }
                    .frame(width: 175, alignment: .leading)
                    .labelsHidden()
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

                row(label: "Docker:") {
                    Stepper(value: Binding(
                        get: { configStore.config.portsDockerStopTimeout },
                        set: { configStore.config.portsDockerStopTimeout = min(max($0, 1), 60); configStore.save() }
                    ), in: 1...60) {
                        Text("Stop timeout: \(configStore.config.portsDockerStopTimeout) s")
                            .font(.system(size: 12))
                            .monospacedDigit()
                    }
                } help: {
                    HelpPopoverButton(text: "How long Docker waits for a container to stop before it kills it. 🐳")
                }

                row(label: "Exclude:") {
                    Button {
                        UserDefaults.standard.set(ExcludeSection.ports.rawValue, forKey: ExcludeSection.defaultsKey)
                        SettingsWindowController.shared.show(tab: .exclude)
                    } label: {
                        Label("Manage Excluded Ports…", systemImage: "nosign")
                    }
                    .font(.system(size: 11.5))
                } help: {
                    HelpPopoverButton(text: "Excluded ports live in the Exclude tab, next to excluded apps. They never show in the Ports tab and are never killed.")
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.42)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(width: SettingsTab.contentWidth, height: Self.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
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
}
