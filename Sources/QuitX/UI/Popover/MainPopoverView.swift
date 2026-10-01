import SwiftUI
import AppKit

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared

    private let goldColor = QuitAllTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            // Search bar & Select All checkbox
            searchBarRow
                .padding(.horizontal, 9)
                .padding(.top, 8)
                .padding(.bottom, 5)

            // Apps list
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
                    .frame(maxHeight: .infinity)
            }

            Spacer(minLength: 0)

            // Footer
            footerRow
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .frame(width: 270)
        .frame(maxHeight: .infinity)
        .background(QuitAllTheme.popoverBackground)
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
        .task {
            await vm.refresh()
        }
    }

    // MARK: - Search & Select All Row

    private var searchBarRow: some View {
        HStack(spacing: 10) {
            // Select All Checkbox
            Button {
                vm.toggleSelectAll()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(vm.isAllSelected ? goldColor : Color.white.opacity(0.3), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(vm.isAllSelected ? goldColor : Color.clear)
                        )
                        .frame(width: 16, height: 16)

                    if vm.isAllSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                    } else if !vm.selected.isEmpty {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(goldColor)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            // Search input field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))

                TextField("", text: $vm.searchQuery, prompt: Text("Search").foregroundColor(Color.white.opacity(0.35)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.white.opacity(0.92))

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    // MARK: - Empty State

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

    // MARK: - Footer Row

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

// NSMenu tracks correctly inside an NSPopover. SwiftUI Menu can close a
// transient popover before the first click reaches the menu.
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
            addItem(to: menu, title: "Welcome Guide...", symbol: "hand.wave", action: #selector(openWelcome))
            addItem(to: menu, title: "Preferences...", symbol: "gearshape", action: #selector(openPreferences))
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

        @objc private func openWelcome() {
            WelcomeWindowController.shared.show()
        }

        @objc private func openPreferences() {
            SettingsWindowController.shared.show()
        }

        @objc private func openHelp() {
            guard let url = URL(string: "https://github.com/coreify/quitx") else { return }
            NSWorkspace.shared.open(url)
        }

        @objc private func quitApp() {
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Blur helper

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
