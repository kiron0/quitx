import SwiftUI

private final class OverlayState: ObservableObject {
    @Published var isCancelHovered = false
    @Published var isConfirmHovered = false
}

enum QuitConfirmationOverlayStyle {
    case standard
    case settings
}

struct QuitConfirmationOverlay: View {
    let title: String
    let subtitle: String
    let confirmTitle: String
    let systemImage: String
    let isForced: Bool
    let style: QuitConfirmationOverlayStyle
    let cardWidth: CGFloat
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @StateObject private var state = OverlayState()

    init(
        title: String,
        subtitle: String,
        confirmTitle: String,
        systemImage: String,
        isForced: Bool,
        style: QuitConfirmationOverlayStyle = .standard,
        cardWidth: CGFloat = 236,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.confirmTitle = confirmTitle
        self.systemImage = systemImage
        self.isForced = isForced
        self.style = style
        self.cardWidth = cardWidth
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    init(
        count: Int,
        isAll: Bool,
        isForced: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let noun = count == 1 ? "App" : "Apps"
        let computedTitle: String
        let computedConfirmTitle: String
        if isForced {
            computedTitle = isAll ? "Force Quit All \(noun)?" : "Force Quit \(count) \(noun)?"
            computedConfirmTitle = isAll ? "Force Quit All" : "Force Quit"
        } else {
            computedTitle = isAll ? "Quit All \(noun)?" : "Quit \(count) \(noun)?"
            computedConfirmTitle = isAll ? "Quit All" : "Quit"
        }
        self.init(
            title: computedTitle,
            subtitle: "This will close \(count) \(count == 1 ? "application." : "applications.")",
            confirmTitle: computedConfirmTitle,
            systemImage: isForced ? "bolt.trianglebadge.exclamationmark.fill" : "questionmark.circle.fill",
            isForced: isForced,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    var body: some View {
        ZStack {
            (style == .settings ? Color.primary.opacity(0.035) : Color.black.opacity(0.45))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .onHover { _ in }
                .allowsHitTesting(true)

            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isForced ? Color.red : QuitXTheme.accent)

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(state.isCancelHovered ? 0.12 : 0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .onHover { state.isCancelHovered = $0 }

                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(isForced ? Color.white : Color.black.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        isForced
                                            ? LinearGradient(colors: [Color.red, Color(red: 210/255, green: 40/255, blue: 40/255)], startPoint: .top, endPoint: .bottom)
                                            : LinearGradient(colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)], startPoint: .top, endPoint: .bottom)
                                    )
                            )
                            .shadow(
                                color: (isForced ? Color.red : QuitXTheme.accent).opacity(state.isConfirmHovered ? 0.35 : 0.15),
                                radius: 2,
                                y: 1
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .onHover { state.isConfirmHovered = $0 }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: cardWidth)
            .frame(minHeight: 132)
            .background {
                let cardShape = RoundedRectangle(cornerRadius: 12)
                if LiquidGlass.enabled {
                    cardShape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LiquidGlassFill(shape: cardShape)
                        }
                        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                } else if style == .settings {
                    cardShape
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.22), radius: 12, y: 5)
                } else {
                    cardShape
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
                }
            }
            .overlay {
                let cardShape = RoundedRectangle(cornerRadius: 12)
                cardShape
                    .stroke(
                        style == .settings ? QuitXTheme.accent.opacity(0.30) : Color.primary.opacity(LiquidGlass.enabled ? 0.18 : 0.12),
                        lineWidth: style == .settings ? 1 : 0.8
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }
}
