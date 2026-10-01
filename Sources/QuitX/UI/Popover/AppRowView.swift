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
    private let forceColor = Color(red: 245/255, green: 75/255, blue: 45/255)

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? goldColor : Color.white.opacity(0.35), lineWidth: 1.5)
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
            }
            .buttonStyle(.plain)

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
                .onTapGesture(perform: onToggle)

            Spacer()

            // Memory / usage text
            Text(app.memoryFormatted)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))

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
                if let dotsImg = AssetImages.load("menu-options") {
                    Image(nsImage: dotsImg)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(width: 14, height: 12)
                } else {
                    Text("•••")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 16)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(state.isHovered ? Color.white.opacity(0.06) : Color.clear)
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
