import SwiftUI
import AppKit

private final class RowState: ObservableObject {
    @Published var isHovered = false
    @Published var isQuitHovered = false
}

struct AppRowView: View {
    let app: AppInfo
    let isSelected: Bool
    let isOptionKeyPressed: Bool
    let isPending: Bool
    let sortBy: QuitXConfig.SortBy
    let forceMode: QuitXConfig.ForceMode
    let onToggle: () -> Void
    let onQuit: (_ force: Bool) -> Void
    let onRestart: () -> Void
    let onExclude: () -> Void
    let onQuitOthers: (_ force: Bool) -> Void

    @StateObject private var state = RowState()

    private let goldColor = QuitXTheme.accent
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    var body: some View {
        HStack(spacing: 5) {

            QuitXSelectionCheckbox(isSelected: isSelected)

            AppIconView(bundleId: app.bundleId, pid: app.pid, size: 18, cornerRadius: 3)

            Text(app.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
                .help(app.displayName)

            if let instanceLabel = app.instanceLabel {
                Text(instanceLabel)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .help(app.displayName)
            }

            Spacer(minLength: 4)

            if app.isUnresponsive {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .help("\(app.name) ignored a previous quit request — force quit may be needed")
            }

            if app.isCpuHog {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .help("\(app.name) exceeded CPU limit")
            }

            Text(usageText)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 52, alignment: .trailing)

            QuitXMenuButton(
                assetName: "menu-options",
                systemSymbolName: "ellipsis",
                symbolPointSize: 12,
                size: NSSize(width: 14, height: 14),
                toolTip: "Options",
                isEnabled: !isPending,
                menu: {
                    buildMenu()
                }
            )
            .frame(width: 16, height: 16)

            let isForced = isOptionKeyPressed ? (forceMode != .force) : (forceMode == .force)

            Button {
                onQuit(isForced)
            } label: {
                quitButtonIcon(isForced: isForced)
            }
            .buttonStyle(.plain)
            .disabled(isPending)
            .help(isPending ? "Operation in progress" : (isForced ? "Force quit \(app.displayName)" : "Quit \(app.displayName)"))
            .accessibilityLabel(isPending ? "Operation in progress" : (isForced ? "Force quit \(app.displayName)" : "Quit \(app.displayName)"))
            .onHover { h in state.isQuitHovered = h }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPending {
                onToggle()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { h in state.isHovered = h }
        .opacity(isPending ? 0.72 : 1)
        .accessibilityValue(isPending ? "Operation in progress" : "")
    }

    private var usageText: String {
        switch sortBy {
        case .memoryDesc, .memoryAsc:
            return app.memoryFormatted
        case .cpuDesc, .cpuAsc, .name, .nameDesc:
            return app.cpuFormatted
        }
    }

    @ViewBuilder
    private func quitButtonIcon(isForced: Bool) -> some View {
        let activeColor = isForced ? forceColor : goldColor

        ZStack {
            Color.clear
                .frame(width: 18, height: 18)

            if isPending {
                ProgressView()
                    .controlSize(.small)
                    .tint(goldColor)
                    .scaleEffect(0.55)
                    .frame(width: 18, height: 18)
            } else if isForced {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(activeColor)
            } else {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.isQuitHovered ? activeColor : Color.secondary)
            }
        }
        .frame(width: 18, height: 18)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            keyEquivalent: "q",
            keyEquivalentModifierMask: [.command],
            assetName: "settings-quit",
            systemSymbolName: "power",
            action: { onQuit(false) }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Force Quit",
            keyEquivalent: "q",
            keyEquivalentModifierMask: [.command, .option],
            assetName: "settings-force-quit",
            systemSymbolName: "bolt.fill",
            action: { onQuit(true) }
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Restart",
            keyEquivalent: "r",
            systemSymbolName: "arrow.clockwise",
            action: { onRestart() }
        ))

        if !app.isBackground {
            menu.addItem(buildAutoQuitItem())
            menu.addItem(buildQuitTimerItem())
            if let pid = app.pid, let windowsItem = buildWindowsItem(pid: pid) {
                menu.addItem(windowsItem)
            }
        }

        menu.addItem(MenuHelper.makeItem(
            title: "Quit Other Apps",
            systemSymbolName: "rectangle.stack.fill.badge.minus",
            action: { onQuitOthers(isOptionKeyPressed) }
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Add to Exclude List",
            keyEquivalent: "e",
            systemSymbolName: "nosign",
            action: { onExclude() }
        ))

        let appUrl = (app.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL })
            ?? (app.bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        if let url = appUrl {
            menu.addItem(MenuHelper.makeItem(
                title: "Reveal in Finder",
                keyEquivalent: "f",
                systemSymbolName: "folder",
                action: {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            ))
        }

        return menu
    }

    private func buildAutoQuitItem() -> NSMenuItem {
        let item = MenuHelper.makeSubmenuItem(title: "Auto-quit", systemSymbolName: "timer")
        let submenu = item.submenu ?? NSMenu()
        let key = PerAppQuitRule.ruleKey(bundleId: app.bundleId, name: app.name)
        let stored = ConfigStore.shared.perAppQuitMinutes(bundleId: app.bundleId, name: app.name)
        let globalMinutes = ConfigStore.shared.config.quitInactiveAfterMinutes
        let defaultTitle = globalMinutes > 0 ? "Use Default (\(globalMinutes) min)" : "Use Default (Off)"

        let defaultItem = MenuHelper.makeItem(
            title: defaultTitle,
            action: { ConfigStore.shared.removePerAppQuitRule(identifier: key) }
        )
        defaultItem.state = stored == nil ? .on : .off
        submenu.addItem(defaultItem)
        submenu.addItem(.separator())

        for preset in PerAppQuitRule.presets.dropFirst() {
            guard let minutes = preset.minutes else { continue }
            let presetItem = MenuHelper.makeItem(
                title: preset.title,
                action: { ConfigStore.shared.setPerAppQuitRule(identifier: key, minutes: minutes) }
            )
            presetItem.state = stored == minutes ? .on : .off
            submenu.addItem(presetItem)
        }

        item.submenu = submenu
        return item
    }

    private func buildWindowsItem(pid: pid_t) -> NSMenuItem? {
        let trusted = AppWindowControl.isTrusted
        let windows = trusted ? AppWindowControl.windows(pid: pid) : []
        guard Self.showsWindowsMenu(trusted: trusted, axWindowCount: windows.count, visibleWindowCount: app.windowCount) else {
            return nil
        }

        let item = MenuHelper.makeSubmenuItem(title: "Windows", systemSymbolName: "macwindow.on.rectangle")
        let submenu = item.submenu ?? NSMenu()
        defer { item.submenu = submenu }

        guard trusted else {
            submenu.addItem(MenuHelper.makeItem(
                title: "Needs Accessibility Access",
                isEnabled: false,
                action: {}
            ))
            submenu.addItem(MenuHelper.makeItem(
                title: "Open Automation Settings…",
                systemSymbolName: "gearshape",
                action: {
                    StatusItemController.shared?.closePopover()
                    SettingsWindowController.shared.show(tab: .automation)
                }
            ))
            return item
        }

        let profileNames = ChromiumProfiles.profileNames(pid: pid)
        if let groups = WindowGrouping.groups(titles: windows.map(\.title), profileNames: profileNames) {
            for group in groups {
                let members = group.indices.compactMap { windows.indices.contains($0) ? windows[$0] : nil }
                guard !members.isEmpty else { continue }
                let groupItem = MenuHelper.makeSubmenuItem(
                    title: "\(group.name) (\(members.count))",
                    systemSymbolName: group.name == WindowGrouping.otherGroupName ? "macwindow" : "person.crop.circle"
                )
                let groupMenu = groupItem.submenu ?? NSMenu()
                groupMenu.addItem(closeWindowsItem(members, label: group.name))
                groupMenu.addItem(.separator())
                for window in members {
                    groupMenu.addItem(windowItem(window, pid: pid, profile: group.name))
                }
                groupItem.submenu = groupMenu
                submenu.addItem(groupItem)
            }
        } else {
            for window in windows {
                submenu.addItem(windowItem(window, pid: pid, profile: nil))
            }
            submenu.addItem(.separator())
            submenu.addItem(closeWindowsItem(windows, label: nil))
        }
        return item
    }

    static func showsWindowsMenu(trusted: Bool, axWindowCount: Int, visibleWindowCount: Int) -> Bool {
        trusted ? axWindowCount > 1 : visibleWindowCount > 1
    }

    private func closeWindowsItem(_ windows: [AppWindowControl.Window], label: String?) -> NSMenuItem {
        let noun = windows.count == 1 ? "Window" : "Windows"
        let title = label.map { "Close \($0) \(noun) (\(windows.count))" } ?? "Close All \(noun) (\(windows.count))"
        return MenuHelper.makeItem(
            title: title,
            systemSymbolName: "xmark.rectangle",
            action: {
                AppWindowControl.close(windows)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await AppListViewModel.shared.refresh(force: true)
                }
            }
        )
    }

    private func windowItem(_ window: AppWindowControl.Window, pid: pid_t, profile: String?) -> NSMenuItem {
        let title = WindowGrouping.displayTitle(window.title, profile: profile)
        let item = MenuHelper.makeSubmenuItem(
            title: window.isMinimized ? "\(title) (Minimized)" : title,
            systemSymbolName: "macwindow"
        )
        let windowMenu = item.submenu ?? NSMenu()
        windowMenu.addItem(MenuHelper.makeItem(
            title: "Show",
            systemSymbolName: "eye",
            action: {
                StatusItemController.shared?.closePopover()
                AppWindowControl.show(window, pid: pid)
            }
        ))
        windowMenu.addItem(MenuHelper.makeItem(
            title: "Close",
            systemSymbolName: "xmark",
            action: {
                AppWindowControl.close([window])
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await AppListViewModel.shared.refresh(force: true)
                }
            }
        ))
        item.submenu = windowMenu
        return item
    }

    private func buildQuitTimerItem() -> NSMenuItem {
        let item = MenuHelper.makeSubmenuItem(title: "Quit In", systemSymbolName: "alarm")
        let submenu = item.submenu ?? NSMenu()
        let key = QuitTimerDue.timerKey(bundleId: app.bundleId, name: app.name, instanceLabel: app.instanceLabel)
        if let remaining = QuitTimerService.shared.remainingMinutes(identifier: key) {
            submenu.addItem(MenuHelper.makeItem(
                title: "Cancel Timer (\(remaining) min left)",
                action: { QuitTimerService.shared.cancelTimer(identifier: key) }
            ))
            submenu.addItem(.separator())
        }
        for minutes in [15, 30, 60] {
            let title = minutes == 60 ? "1 hour" : "\(minutes) minutes"
            submenu.addItem(MenuHelper.makeItem(
                title: title,
                action: { QuitTimerService.shared.setTimer(identifier: key, minutes: minutes) }
            ))
        }
        item.submenu = submenu
        return item
    }
}
