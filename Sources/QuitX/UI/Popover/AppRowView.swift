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
    let onToggle: () -> Void
    let onQuit: (_ force: Bool) -> Void
    let onRestart: () -> Void
    let onExclude: () -> Void

    @StateObject private var state = RowState()
    @StateObject private var iconLoader = IconLoader()

    private let goldColor = QuitXTheme.accent
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    var body: some View {
        HStack(spacing: 8) {

            ZStack {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(isSelected ? goldColor : Color.white.opacity(0.12))
                    .frame(width: 14, height: 14)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black.opacity(0.9))
                }
            }

            Group {
                if let icon = iconLoader.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .cornerRadius(3)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 18, height: 18)
                }
            }
            .onAppear { iconLoader.load(bundleId: app.bundleId) }

            Text(app.name)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Menu {
                Button(isOptionKeyPressed ? "Force Quit" : "Quit") {
                    onQuit(isOptionKeyPressed)
                }
                Button("Restart") {
                    onRestart()
                }
                Divider()
                Button("Add to Exclude List") {
                    onExclude()
                }
                if let bid = app.bundleId, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            } label: {
                Text("•••")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 16)

            Text(app.cpuFormatted)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))

            Button {
                onQuit(isOptionKeyPressed)
            } label: {
                quitButtonIcon
            }
            .buttonStyle(.plain)
            .onHover { h in state.isQuitHovered = h }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.white.opacity(0.07) : Color.clear)
        )
        .onHover { h in state.isHovered = h }
    }

    @ViewBuilder
    private var quitButtonIcon: some View {
        let isForced = isOptionKeyPressed
        let activeColor = isForced ? forceColor : goldColor

        ZStack {
            Color.clear
                .frame(width: 18, height: 18)

            if isForced {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(activeColor)
            } else {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.isQuitHovered ? activeColor : Color.white.opacity(0.45))
            }
        }
        .frame(width: 18, height: 18)
    }
}
