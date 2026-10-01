import SwiftUI
import AppKit

private final class RowState: ObservableObject {
    @Published var isHovered = false
    @Published var isQuitHovered = false
}

private final class IconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?) {
        guard let bid = bundleId,
              let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path else { return }
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

    private let goldColor = Color(red: 247/255, green: 181/255, blue: 0/255)
    private let forceColor = Color(red: 240/255, green: 70/255, blue: 50/255)

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox (visual only; click handled by row)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? goldColor : Color.white.opacity(0.3), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? goldColor : Color.clear)
                    )
                    .frame(width: 16, height: 16)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                }
            }

            // App icon
            Group {
                if let icon = iconLoader.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .cornerRadius(5)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 22, height: 22)
                }
            }
            .onAppear { iconLoader.load(bundleId: app.bundleId) }

            // App name
            Text(app.name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)

            Spacer()

            // Memory / usage text
            Text(app.memoryFormatted)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.48))

            // Quit single button
            Button {
                onQuit(isOptionKeyPressed)
            } label: {
                quitButtonIcon
            }
            .buttonStyle(.plain)
            .onHover { h in state.isQuitHovered = h }

            // More options menu (3 dots)
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 18)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(state.isHovered ? Color.white.opacity(0.07) : Color.clear)
        )
        .onHover { h in state.isHovered = h }
    }

    @ViewBuilder
    private var quitButtonIcon: some View {
        let isForced = isOptionKeyPressed
        let activeColor = isForced ? forceColor : goldColor

        if state.isQuitHovered || isForced {
            ZStack {
                Circle()
                    .fill(activeColor)
                    .frame(width: 20, height: 20)

                if isForced {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                } else {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                }
            }
        } else {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                    .background(Circle().fill(Color.white.opacity(0.05)))
                    .frame(width: 20, height: 20)

                Image(systemName: "power")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
    }
}
