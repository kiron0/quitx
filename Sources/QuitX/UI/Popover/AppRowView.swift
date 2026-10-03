import SwiftUI
import AppKit

private final class RowState: ObservableObject {
    @Published var isHovered = false
    @Published var isQuitHovered = false
}

private final class IconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?) {
        guard let bid = bundleId else { return }
        if bid == "com.apple.trash" {
            let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Trash")
            img?.isTemplate = true
            self.icon = img
            return
        }
        if bid == "com.apple.finder" {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path {
                let img = NSWorkspace.shared.icon(forFile: path)
                self.icon = img
                return
            }
        }
        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSWorkspace.shared.icon(forFile: path)
            DispatchQueue.main.async { self.icon = img }
        }
    }
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
    @StateObject private var iconLoader = IconLoader()
    @ObservedObject private var configStore = ConfigStore.shared

    private let goldColor = QuitXTheme.accent
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    var body: some View {
        HStack(spacing: 8) {

            QuitXSelectionCheckbox(isSelected: isSelected)

            Group {
                if let icon = iconLoader.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .cornerRadius(3)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 18, height: 18)
                }
            }
            .onAppear { iconLoader.load(bundleId: app.bundleId) }

            Text(app.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            let hasUrl: Bool = {
                if let bid = app.bundleId {
                    return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) != nil
                }
                return false
            }()

            Text(usageText)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.secondary)
                .frame(width: 56, alignment: .trailing)

            AppRowOptionsButton(
                isForced: isOptionKeyPressed,
                isEnabled: !isPending,
                hasBundleUrl: hasUrl,
                onQuit: { onQuit(isOptionKeyPressed) },
                onRestart: { onRestart() },
                onExclude: { onExclude() },
                onReveal: {
                    if let bid = app.bundleId, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            )
            .frame(width: 16, height: 16)

            Button {
                onQuit(isOptionKeyPressed)
            } label: {
                quitButtonIcon
            }
            .buttonStyle(.plain)
            .disabled(isPending)
            .help(isPending ? "Operation in progress" : (isOptionKeyPressed ? "Force quit \(app.name)" : "Quit \(app.name)"))
            .accessibilityLabel(isPending ? "Operation in progress" : (isOptionKeyPressed ? "Force quit \(app.name)" : "Quit \(app.name)"))
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
    private var quitButtonIcon: some View {
        let isForced = isOptionKeyPressed
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
}

private struct AppRowOptionsButton: NSViewRepresentable {
    let isForced: Bool
    let isEnabled: Bool
    let hasBundleUrl: Bool
    let onQuit: () -> Void
    let onRestart: () -> Void
    let onExclude: () -> Void
    let onReveal: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        if let img = AssetImages.load("menu-options") {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 14, height: 14)
            copy.isTemplate = true
            button.image = copy
            button.imagePosition = .imageOnly
        } else {
            button.title = "•••"
            button.font = .systemFont(ofSize: 9.5, weight: .bold)
        }
        button.contentTintColor = NSColor.secondaryLabelColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        button.isEnabled = isEnabled
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.isEnabled = isEnabled
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: AppRowOptionsButton

        init(parent: AppRowOptionsButton) {
            self.parent = parent
        }

        @objc func showMenu(_ button: NSButton) {
            let menu = NSMenu()

            let quitTitle = parent.isForced ? "Force Quit" : "Quit"
            let quitAsset = parent.isForced ? "settings-force-quit" : "settings-quit"
            let quitSymbol = parent.isForced ? "bolt.fill" : "power"
            let quitMask: NSEvent.ModifierFlags = parent.isForced ? [.command, .option] : [.command]

            menu.addItem(MenuHelper.makeItem(
                title: quitTitle,
                action: #selector(handleQuit),
                target: self,
                keyEquivalent: "q",
                keyEquivalentModifierMask: quitMask,
                assetName: quitAsset,
                systemSymbolName: quitSymbol
            ))

            menu.addItem(MenuHelper.makeItem(
                title: "Restart",
                action: #selector(handleRestart),
                target: self,
                keyEquivalent: "r",
                systemSymbolName: "arrow.clockwise"
            ))

            menu.addItem(.separator())

            menu.addItem(MenuHelper.makeItem(
                title: "Add to Exclude List",
                action: #selector(handleExclude),
                target: self,
                keyEquivalent: "e",
                systemSymbolName: "nosign"
            ))

            if parent.hasBundleUrl {
                menu.addItem(MenuHelper.makeItem(
                    title: "Reveal in Finder",
                    action: #selector(handleReveal),
                    target: self,
                    keyEquivalent: "f",
                    systemSymbolName: "folder"
                ))
            }

            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.maxX, y: button.bounds.minY), in: button)
        }

        @objc private func handleQuit() { parent.onQuit() }
        @objc private func handleRestart() { parent.onRestart() }
        @objc private func handleExclude() { parent.onExclude() }
        @objc private func handleReveal() { parent.onReveal() }
    }
}
