import SwiftUI
import AppKit

private final class PopoverUIState: ObservableObject {
    @Published var showConfirmQuitAll = false
    @Published var isQuitAllHovered = false
}

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared
    @StateObject private var uiState = PopoverUIState()

    private let goldColor = QuitXTheme.accent
    private let goldGradient = LinearGradient(
        colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let forceGradient = LinearGradient(
        colors: [Color(red: 240/255, green: 70/255, blue: 50/255), Color(red: 210/255, green: 40/255, blue: 30/255)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 0) {
            quitAllButton
                .padding(.horizontal, 8)
                .padding(.top, 5)
                .padding(.bottom, 4)

            searchBarRow
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            if vm.isLoading && vm.apps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if vm.filteredApps.isEmpty {
                emptyAppsView
            } else {
                AppListView(vm: vm)
            }

            footerRow
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .padding(.bottom, 6)
        }
        .frame(width: 270)
        .frame(maxHeight: .infinity)
        .background(QuitXTheme.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .preferredColorScheme(.dark)
        .onChange(of: vm.filteredApps.count) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(count: vm.lastQuitCount)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showToast)
        .alert("Quit selected apps?", isPresented: $uiState.showConfirmQuitAll) {
            let isAll = vm.isAllSelected
            let confirmTitle = vm.isOptionKeyPressed ? (isAll ? "Force Quit All" : "Force Quit Selected") : (isAll ? "Quit All" : "Quit Selected")
            Button(confirmTitle, role: .destructive) {
                Task {
                    await vm.quitAll(force: vm.isOptionKeyPressed || configStore.config.force == .force)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will close \(vm.selected.count) applications.")
        }
    }

    private var quitAllButton: some View {
        let isForced = vm.isOptionKeyPressed || configStore.config.force == .force
        let count = vm.selected.count
        let isAll = vm.isAllSelected
        let title: String
        if isForced {
            title = isAll ? "Force Quit All" : "Force Quit Selected"
        } else {
            title = isAll ? "Quit All" : "Quit Selected"
        }
        let isEnabled = count > 0

        return Button {
            if count >= 4 && configStore.config.confirmQuitAll {
                uiState.showConfirmQuitAll = true
            } else {
                Task { await vm.quitAll(force: isForced) }
            }
        } label: {
            HStack(spacing: 5) {
                if isForced {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isEnabled
                    ? goldGradient
                    : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(
                color: isEnabled ? goldColor.opacity(uiState.isQuitAllHovered ? 0.3 : 0.12) : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { uiState.isQuitAllHovered = $0 }
    }

    private var searchBarRow: some View {
        HStack(spacing: 8) {

            Button {
                vm.toggleSelectAll()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(vm.isAllSelected || vm.isPartiallySelected ? goldColor : Color.white.opacity(0.12))
                        .frame(width: 14, height: 14)

                    if vm.isAllSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                    } else if vm.isPartiallySelected {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.9))
                            .frame(width: 6, height: 2)
                    }
                }
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))

                TextField("", text: $vm.searchQuery, prompt: Text("Search").foregroundColor(Color.white.opacity(0.35)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .focusable(false)

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private var emptyAppsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(goldColor)
            Text(vm.searchQuery.isEmpty ? "All clean! No apps to quit." : "No running apps match '\(vm.searchQuery)'")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private var footerRow: some View {
        HStack {
            Text(vm.currentQuote)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)

            Spacer()

            PopoverOptionsButton(
                showsBackgroundApps: vm.showBackgroundApps,
                hasStash: vm.hasStash,
                onToggleBackgroundApps: {
                    vm.showBackgroundApps.toggle()
                    Task { await vm.refresh() }
                },
                onStash: { Task { await vm.stash() } },
                onRestore: { Task { await vm.restore() } }
            )
            .frame(width: 22, height: 22)
        }
    }
}

private struct PopoverOptionsButton: NSViewRepresentable {
    var showsBackgroundApps: Bool
    var hasStash: Bool
    var onToggleBackgroundApps: () -> Void
    var onStash: () -> Void
    var onRestore: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.image = NSImage(
            systemSymbolName: "line.3.horizontal",
            accessibilityDescription: "Options"
        )
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        button.toolTip = "Options"
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PopoverOptionsButton

        init(parent: PopoverOptionsButton) {
            self.parent = parent
        }

        @objc func showMenu(_ button: NSButton) {
            let menu = NSMenu()
            addItem(
                to: menu,
                title: parent.showsBackgroundApps ? "Hide background apps" : "View background apps",
                symbol: parent.showsBackgroundApps ? "eye.slash" : "eye",
                action: #selector(toggleBackgroundApps)
            )
            menu.addItem(.separator())
            addItem(to: menu, title: "Stash session", symbol: "tray.and.arrow.down", action: #selector(stash))
            addItem(
                to: menu,
                title: "Restore session",
                symbol: "tray.and.arrow.up",
                action: #selector(restore),
                enabled: parent.hasStash
            )
            menu.addItem(.separator())
            addItem(to: menu, title: "Settings", symbol: "gearshape", action: #selector(openSettings))
            addItem(to: menu, title: "Help", symbol: "questionmark.circle", action: #selector(openHelp))
            menu.addItem(.separator())
            addItem(to: menu, title: "Quit QuitX", symbol: "power", action: #selector(quitApp))

            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY), in: button)
        }

        private func addItem(
            to menu: NSMenu,
            title: String,
            symbol: String,
            action: Selector,
            enabled: Bool = true
        ) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            item.isEnabled = enabled
            menu.addItem(item)
        }

        @objc private func toggleBackgroundApps() { parent.onToggleBackgroundApps() }
        @objc private func stash() { parent.onStash() }
        @objc private func restore() { parent.onRestore() }

        @objc private func openSettings() {
            StatusItemController.shared?.closePopover()
            SettingsWindowController.shared.show()
        }

        @objc private func openHelp() {
            StatusItemController.shared?.closePopover()
            guard let url = URL(string: "https://github.com/coreify/quitx") else { return }
            NSWorkspace.shared.open(url)
        }

        @objc private func quitApp() {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
