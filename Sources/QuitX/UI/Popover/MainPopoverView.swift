import SwiftUI
import AppKit

private final class PopoverUIState: ObservableObject {
    @Published var isQuitAllHovered = false
    var cachedOptionsMenu: NSMenu? = nil
    var cachedMenuBgState: Bool? = nil
    var cachedMenuRecentKey: String? = nil
}

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared
    @ObservedObject private var portsVM = PortListViewModel.shared
    @StateObject private var uiState = PopoverUIState()

    private static let goldColor = QuitXTheme.accent
    private static let goldGradient = LinearGradient(
        colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)],
        startPoint: .top,
        endPoint: .bottom
    )
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)

            if configStore.config.portsEnabled {
                PopoverTabBar(selection: Binding(
                    get: { vm.activeTab },
                    set: { vm.selectTab($0) }
                ))
                .padding(.horizontal, 8)
                .padding(.top, 5)
            }

            Group {
                if isPortsTab {
                    portsActionButton
                } else {
                    quitAllButton
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)
            .padding(.bottom, 4)

            searchBarRow
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            if isPortsTab {
                portsContent
            } else if vm.isLoading && vm.apps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if vm.filteredApps.isEmpty {
                emptyAppsView
                    .frame(maxHeight: .infinity)
            } else {
                AppListView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)

            footerRow
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .padding(.bottom, 6)
        }
        .frame(width: StatusItemController.popoverWidth)
        .frame(minHeight: 220)
        .frame(maxHeight: .infinity)
        .arrowPopoverChrome(arrowX: vm.popoverArrowX, classicBackground: AnyView(QuitXTheme.popoverBackground))
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(
                    message: vm.toastMessage,
                    isError: vm.toastIsError,
                    actionTitle: vm.toastActionTitle,
                    action: { vm.performToastAction() }
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showToast)
        .overlay {
            if isPortsTab, let request = portsVM.pendingKillConfirmation {
                QuitConfirmationOverlay(
                    title: request.title,
                    subtitle: request.message,
                    confirmTitle: request.confirmButtonTitle,
                    systemImage: request.isForced ? "bolt.trianglebadge.exclamationmark.fill" : "questionmark.circle.fill",
                    isForced: request.isForced,
                    onConfirm: {
                        portsVM.confirmPending()
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            portsVM.pendingKillConfirmation = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if vm.showConfirmQuitAll {
                QuitConfirmationOverlay(
                    count: vm.confirmationTargetCount,
                    isAll: vm.confirmationTargetsAreEverything,
                    isForced: vm.isConfirmQuitAllForced,
                    onConfirm: {
                        vm.confirmQuitAllAction()
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.cancelConfirmQuitAll()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let action = vm.pendingIndividualAction {
                switch action {
                case .quit(let app, let force):
                    QuitConfirmationOverlay(
                        title: force ? "Force Quit \(app.name)?" : "Quit \(app.name)?",
                        subtitle: "This will close \(app.name).",
                        confirmTitle: force ? "Force Quit" : "Quit",
                        systemImage: force ? "bolt.trianglebadge.exclamationmark.fill" : "questionmark.circle.fill",
                        isForced: force,
                        onConfirm: {
                            vm.confirmIndividualAction()
                        },
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.cancelIndividualAction()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .restart(let app):
                    QuitConfirmationOverlay(
                        title: "Restart \(app.name)?",
                        subtitle: "This will close and reopen \(app.name).",
                        confirmTitle: "Restart",
                        systemImage: "arrow.clockwise.circle.fill",
                        isForced: false,
                        onConfirm: {
                            vm.confirmIndividualAction()
                        },
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                vm.cancelIndividualAction()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: vm.showConfirmQuitAll)
        .animation(.easeInOut(duration: 0.18), value: vm.pendingIndividualAction)
        .clipShape(popoverShape(arrowX: vm.popoverArrowX))
        .animation(.easeInOut(duration: 0.18), value: portsVM.pendingKillConfirmation != nil)
        .onChange(of: portsVM.visibleCount) {
            StatusItemController.shared?.scheduleUpdatePopoverSize()
        }
        .onChange(of: vm.activeTab) {
            StatusItemController.shared?.scheduleUpdatePopoverSize()
        }
        .onChange(of: vm.filteredApps.count) {
            StatusItemController.shared?.updatePopoverSize()
        }
    }

    private var quitAllButton: some View {
        let isForced = vm.isOptionKeyPressed ? (configStore.config.force != .force) : (configStore.config.force == .force)
        let count = vm.selectedTotalCount
        let isAll = vm.isEverythingSelected
        let title: String
        if isForced {
            title = isAll ? "Force Quit All" : "Force Quit Selected"
        } else {
            title = isAll ? "Quit All" : "Quit Selected"
        }
        let isActive = count > 0
        let canStart = isActive && !vm.hasPendingOperations

        return Button {
            let shouldConfirm: Bool
            if count == 1 {
                shouldConfirm = configStore.config.confirmIndividualAction
            } else {
                shouldConfirm = configStore.config.confirmQuitAll
            }

            if shouldConfirm {
                if count == 1, let singleApp = vm.apps.first(where: { vm.selected.contains($0.id) }) ?? vm.filteredApps.first(where: { vm.selected.contains($0.id) }) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        vm.pendingIndividualAction = .quit(app: singleApp, force: isForced)
                    }
                } else {
                    vm.isConfirmQuitAllForced = isForced
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        vm.showConfirmQuitAll = true
                    }
                }
            } else {
                Task { await vm.quitAll(force: isForced) }
            }
        } label: {
            HStack(spacing: 5) {
                if vm.isBatchQuitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.black.opacity(0.88))
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
                    ? Color.black.opacity(0.88)
                    : Color.primary.opacity(0.35)
            )
            .opacity(canStart || vm.isBatchQuitting ? 1 : 0.55)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isActive
                    ? Self.goldGradient
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isActive ? Self.goldColor.opacity(uiState.isQuitAllHovered ? 0.3 : 0.12) : Color.clear,
                radius: 2,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .onHover { uiState.isQuitAllHovered = $0 }
    }

    private var isPortsTab: Bool {
        configStore.config.portsEnabled && vm.activeTab == .ports
    }

    private var searchBinding: Binding<String> {
        isPortsTab ? $portsVM.searchQuery : $vm.searchQuery
    }

    private var searchText: String {
        isPortsTab ? portsVM.searchQuery : vm.searchQuery
    }

    @ViewBuilder
    private var portsContent: some View {
        if !portsVM.hasLoadedOnce {
            PortsLoadingView()
                .frame(maxHeight: .infinity)
        } else if portsVM.filteredPorts.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "network")
                    .font(.system(size: 30))
                    .foregroundStyle(Self.goldColor)
                Text(portsVM.searchQuery.isEmpty ? "No listening ports. All clear!" : "No ports match '\(portsVM.searchQuery)'")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxHeight: .infinity)
        } else {
            PortListView(vm: portsVM, needsScrolling: vm.listNeedsScrolling)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var portsActionButton: some View {
        let isForced = portsVM.isForceMode
        let count = portsVM.selectedVisibleCount
        let isActive = count > 0
        let canStart = isActive && !portsVM.isBatchKilling
        let isAll = portsVM.isEverythingSelected
        let title: String
        if isForced {
            title = isAll ? "Force Kill All Ports" : (isActive ? "Force Kill \(count) \(count == 1 ? "Port" : "Ports")" : "Force Kill Selected Ports")
        } else {
            title = isAll ? "Kill All Ports" : (isActive ? "Kill \(count) \(count == 1 ? "Port" : "Ports")" : "Kill Selected Ports")
        }

        return Button {
            portsVM.confirmAndKillSelectedPorts(force: isForced)
        } label: {
            HStack(spacing: 5) {
                if portsVM.isBatchKilling {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.black.opacity(0.88))
                        .scaleEffect(0.65)
                    Text("Killing…")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    if isForced {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(isActive ? Color.black.opacity(0.88) : Color.primary.opacity(0.35))
            .opacity(canStart || portsVM.isBatchKilling ? 1 : 0.55)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                isActive
                    ? Self.goldGradient
                    : LinearGradient(colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(
                color: isActive ? Self.goldColor.opacity(uiState.isQuitAllHovered ? 0.3 : 0.12) : Color.clear,
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
                if isPortsTab {
                    portsVM.toggleSelectAll()
                } else {
                    vm.toggleSelectAll()
                }
            } label: {
                QuitXSelectionCheckbox(
                    isSelected: isPortsTab ? portsVM.isAllSelected : vm.isAllSelected,
                    isPartial: isPortsTab ? portsVM.isPartiallySelected : vm.isPartiallySelected
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help((isPortsTab ? portsVM.isAllSelected : vm.isAllSelected) ? "Deselect All" : "Select All")

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)

                TextField("", text: searchBinding, prompt: Text(isPortsTab ? "Search ports, apps, folders" : "Search").foregroundColor(Color.secondary))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()

                if !searchText.isEmpty {
                    Button {
                        searchBinding.wrappedValue = ""
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
                .foregroundStyle(Self.goldColor)
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
                Text(isPortsTab ? portsVM.currentQuote : vm.currentQuote)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            QuitXMenuButton(
                assetName: "settings",
                selectedAssetName: "settings-selected",
                systemSymbolName: "gearshape",
                symbolPointSize: 13,
                size: NSSize(width: 17, height: 17),
                toolTip: "Options",
                menu: {
                    optionsMenu()
                }
            )
            .frame(width: 22, height: 22)
        }
    }

    private func buildOptionsMenu() -> NSMenu {
        let vm = AppListViewModel.shared
        let menu = NSMenu()
        menu.autoenablesItems = false

        if isPortsTab {
            let portsVM = PortListViewModel.shared
            menu.addItem(MenuHelper.makeItem(
                title: "Refresh Ports",
                keyEquivalent: "r",
                systemSymbolName: "arrow.clockwise",
                action: {
                    Task { await portsVM.refresh() }
                }
            ))
            if !portsVM.ports.isEmpty {
                menu.addItem(MenuHelper.makeItem(
                    title: "Export Port Diagnostics…",
                    systemSymbolName: "square.and.arrow.up",
                    action: { PortDiagnosticsExporter.export() }
                ))
            }
            if !ListenerHistoryStore.shared.entries.isEmpty {
                menu.addItem(MenuHelper.makeItem(
                    title: "Copy Recent Listener History",
                    systemSymbolName: "clock.arrow.circlepath",
                    action: { PortDiagnosticsExporter.copyHistory() }
                ))
            }
            menu.addItem(MenuHelper.makeItem(
                title: "Port Settings",
                systemSymbolName: "network",
                action: {
                    StatusItemController.shared?.closePopover()
                    SettingsWindowController.shared.show(tab: .ports)
                }
            ))
        } else {
            menu.addItem(MenuHelper.makeItem(
                title: "Refresh Apps",
                keyEquivalent: "r",
                systemSymbolName: "arrow.clockwise",
                action: {
                    Task { await vm.refresh() }
                }
            ))
        }

        let bgTitle = vm.showBackgroundApps ? "Hide Background Apps" : "View Background Apps"
        let bgAsset = vm.showBackgroundApps ? "settings-background-apps-hide" : "settings-background-apps-show"
        let bgSymbol = vm.showBackgroundApps ? "eye.slash" : "eye"

        menu.addItem(MenuHelper.makeItem(
            title: bgTitle,
            keyEquivalent: "b",
            assetName: bgAsset,
            systemSymbolName: bgSymbol,
            action: {
                vm.showBackgroundApps.toggle()
            }
        ))

        let recentEntries = RecentlyQuitService.shared.entries
        if !recentEntries.isEmpty {
            let reopenItem = MenuHelper.makeSubmenuItem(title: "Reopen Recently Quit", systemSymbolName: "arrow.uturn.backward")
            let reopenMenu = reopenItem.submenu ?? NSMenu()
            for entry in recentEntries.prefix(10) {
                let canReopen = entry.bundleId != nil
                let icon: NSImage = {
                    var raw: NSImage?
                    if let bid = entry.bundleId {
                        raw = AppIconCache.icon(for: bid)
                    }
                    if raw == nil {
                        let path = "/Applications/\(entry.name).app"
                        if FileManager.default.fileExists(atPath: path) {
                            raw = NSWorkspace.shared.icon(forFile: path)
                        }
                    }
                    let img = raw ?? NSWorkspace.shared.icon(for: .applicationBundle)
                    let copy = img.copy() as? NSImage ?? img
                    copy.size = NSSize(width: 16, height: 16)
                    return copy
                }()
                reopenMenu.addItem(MenuHelper.makeItem(
                    title: entry.name,
                    customImage: icon,
                    isEnabled: canReopen,
                    action: {
                        StatusItemController.shared?.closePopover()
                        RecentlyQuitService.shared.reopen(entry)
                    }
                ))
            }
            reopenMenu.addItem(.separator())
            reopenMenu.addItem(MenuHelper.makeItem(
                title: "Clear List",
                systemSymbolName: "trash",
                action: {
                    RecentlyQuitService.shared.clear()
                }
            ))
            reopenItem.submenu = reopenMenu
            menu.addItem(reopenItem)
        }

        menu.addItem(MenuHelper.makeItem(
            title: "Uninstall Apps",
            systemSymbolName: "trash",
            action: {
                UninstallWindowController.shared.showPicker()
            }
        ))

        menu.addItem(.separator())

        let updateState = UpdateDownloadService.shared.state
        if let updateTitle = StatusItemController.updateMenuTitle(
            availableVersion: UpdateChecker.shared.availableUpdate?.version,
            state: updateState
        ) {
            let isReady: Bool
            if case .ready = updateState { isReady = true } else { isReady = false }
            menu.addItem(MenuHelper.makeItem(
                title: updateTitle,
                customImage: StatusItemController.redDot,
                action: {
                    StatusItemController.shared?.closePopover()
                    if isReady {
                        UpdateChecker.shared.restartToUpdate()
                    } else {
                        UpdateChecker.shared.presentAvailableUpdate()
                    }
                }
            ))
            menu.addItem(.separator())
        }

        menu.addItem(MenuHelper.makeItem(
            title: "Settings",
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape",
            action: {
                StatusItemController.shared?.closePopover()
                SettingsWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Help",
            keyEquivalent: "?",
            assetName: "settings-help",
            systemSymbolName: "questionmark.circle",
            action: {
                StatusItemController.shared?.closePopover()
                HelpWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "What's New",
            keyEquivalent: "n",
            systemSymbolName: "sparkles",
            action: {
                StatusItemController.shared?.closePopover()
                ChangelogWindowController.shared.show()
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Check for Updates",
            keyEquivalent: "u",
            systemSymbolName: "arrow.triangle.2.circlepath",
            action: {
                StatusItemController.shared?.closePopover()
                Task {
                    await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                }
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About QuitX",
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle",
            action: {
                StatusItemController.shared?.closePopover()
                SettingsWindowController.shared.show(tab: .about)
            }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Buy me a coffee",
            systemSymbolName: "cup.and.saucer.fill",
            action: {
                StatusItemController.shared?.closePopover()
                NSWorkspace.shared.open(QuitXConstants.buyMeACoffeeURL)
            }
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit QuitX",
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power",
            action: {
                NSApplication.shared.terminate(nil)
            }
        ))

        return menu
    }

    private func optionsMenu() -> NSMenu {
        let recentKey = RecentlyQuitService.shared.menuKey
        let tabKey = "\(recentKey)|\(isPortsTab)|\(portsVM.ports.isEmpty)|\(ListenerHistoryStore.shared.entries.isEmpty)"
        if let menu = uiState.cachedOptionsMenu,
           uiState.cachedMenuBgState == vm.showBackgroundApps,
           uiState.cachedMenuRecentKey == tabKey {
            return menu
        }
        let menu = buildOptionsMenu()
        uiState.cachedOptionsMenu = menu
        uiState.cachedMenuBgState = vm.showBackgroundApps
        uiState.cachedMenuRecentKey = tabKey
        return menu
    }
}
