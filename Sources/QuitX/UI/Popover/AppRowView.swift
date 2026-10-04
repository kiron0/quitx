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
    let onToggle: () -> Void
    let onQuit: (_ force: Bool) -> Void
    let onRestart: () -> Void
    let onExclude: () -> Void

    @StateObject private var state = RowState()
    @ObservedObject private var configStore = ConfigStore.shared

    private let goldColor = QuitXTheme.accent
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    var body: some View {
        HStack(spacing: 8) {

            QuitXSelectionCheckbox(isSelected: isSelected)

            AppIconView(bundleId: app.bundleId, pid: app.pid, size: 18, cornerRadius: 3)

            Text(app.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Text(usageText)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.secondary)
                .frame(width: 56, alignment: .trailing)

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

            let isForced = isOptionKeyPressed ? (configStore.config.force != .force) : (configStore.config.force == .force)

            Button {
                onQuit(isForced)
            } label: {
                quitButtonIcon(isForced: isForced)
            }
            .buttonStyle(.plain)
            .disabled(isPending)
            .help(isPending ? "Operation in progress" : (isForced ? "Force quit \(app.name)" : "Quit \(app.name)"))
            .accessibilityLabel(isPending ? "Operation in progress" : (isForced ? "Force quit \(app.name)" : "Quit \(app.name)"))
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
        switch configStore.config.sortBy {
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

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Add to Exclude List",
            keyEquivalent: "e",
            systemSymbolName: "nosign",
            action: { onExclude() }
        ))

        let appUrl = (app.bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
            ?? (app.pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleURL })
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
}

