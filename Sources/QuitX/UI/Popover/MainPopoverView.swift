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
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)

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
        .background(
            QuitXTheme.popoverBackground
                .clipShape(PopoverContainerShape(arrowX: vm.arrowX, cornerRadius: 10))
        )
        .overlay(
            PopoverContainerShape(arrowX: vm.arrowX, cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(PopoverContainerShape(arrowX: vm.arrowX, cornerRadius: 10))
        .onChange(of: vm.filteredApps.count) {
            StatusItemController.shared?.updatePopoverSize()
        }
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(message: vm.toastMessage, isError: vm.toastIsError)
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
            Text("This will close \(vm.selectedVisibleCount) applications.")
        }
    }

    private var quitAllButton: some View {
        let isForced = vm.isOptionKeyPressed || configStore.config.force == .force
        let count = vm.selectedVisibleCount
        let isAll = vm.isAllSelected
        let title: String
        if isForced {
            title = isAll ? "Force Quit All" : "Force Quit Selected"
        } else {
            title = isAll ? "Quit All" : "Quit Selected"
        }
        let isActive = count > 0
        let canStart = isActive && !vm.hasPendingOperations

        return Button {
            if count >= 4 && configStore.config.confirmQuitAll {
                uiState.showConfirmQuitAll = true
            } else {
                Task { await vm.quitAll(force: isForced) }
            }
        } label: {
            HStack(spacing: 5) {
                if vm.isBatchQuitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isForced ? Color.white : Color.black.opacity(0.88))
                        .scaleEffect(0.65)
                    Text("Quitting…")
                        .font(.system(size: 12, weight: .bold))
                } else if isForced {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(
                isActive
                    ? (isForced ? Color.white : Color.black.opacity(0.88))
                    : Color.primary.opacity(0.35)
            )
            .opacity(canStart || vm.isBatchQuitting ? 1 : 0.55)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isActive
                    ? goldGradient
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isActive ? goldColor.opacity(uiState.isQuitAllHovered ? 0.3 : 0.12) : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .onHover { uiState.isQuitAllHovered = $0 }
    }

    private var searchBarRow: some View {
        HStack(spacing: 8) {

            Button {
                vm.toggleSelectAll()
            } label: {
                QuitXSelectionCheckbox(
                    isSelected: vm.isAllSelected,
                    isPartial: vm.isPartiallySelected
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                TextField("", text: $vm.searchQuery, prompt: Text("Search").foregroundColor(Color.secondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
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
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private var footerRow: some View {
        HStack {
            if !configStore.config.disableQuitTips {
                Text(vm.currentQuote)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            PopoverOptionsButton(
                showsBackgroundApps: vm.showBackgroundApps,
                onToggleBackgroundApps: {
                    vm.showBackgroundApps.toggle()
                    Task { await vm.refresh() }
                }
            )
            .frame(width: 22, height: 22)
        }
    }
}

private struct PopoverOptionsButton: NSViewRepresentable {
    var showsBackgroundApps: Bool
    var onToggleBackgroundApps: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        if let img = AssetImages.load("settings") {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 17, height: 17)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        } else if let sym = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Options") {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let copy = (sym.withSymbolConfiguration(config) ?? sym).copy() as? NSImage ?? sym
            copy.size = NSSize(width: 17, height: 17)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        }
        button.contentTintColor = NSColor.secondaryLabelColor
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

            let bgTitle = parent.showsBackgroundApps ? "Hide background apps" : "View background apps"
            let bgAsset = parent.showsBackgroundApps ? "settings-background-apps-hide" : "settings-background-apps-show"
            let bgSymbol = parent.showsBackgroundApps ? "eye.slash" : "eye"

            menu.addItem(MenuHelper.makeItem(
                title: bgTitle,
                action: #selector(toggleBackgroundApps),
                target: self,
                keyEquivalent: "b",
                assetName: bgAsset,
                systemSymbolName: bgSymbol
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Settings",
                action: #selector(openSettings),
                target: self,
                keyEquivalent: ",",
                assetName: "settings-preferences",
                systemSymbolName: "gearshape"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Help",
                action: #selector(openHelp),
                target: self,
                keyEquivalent: "h",
                assetName: "settings-help",
                systemSymbolName: "questionmark.circle"
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Quit",
                action: #selector(quitApp),
                target: self,
                keyEquivalent: "q",
                assetName: "settings-quit",
                systemSymbolName: "power"
            ))

            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY), in: button)
        }

        @objc private func toggleBackgroundApps() { parent.onToggleBackgroundApps() }

        @objc private func openSettings() {
            StatusItemController.shared?.closePopover()
            SettingsWindowController.shared.show()
        }

        @objc private func openHelp() {
            StatusItemController.shared?.closePopover()
            HelpWindowController.shared.show()
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
