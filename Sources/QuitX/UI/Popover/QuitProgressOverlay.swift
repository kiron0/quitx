import SwiftUI

enum QuitProgressOverlayStyle {
    case standard
    case settings
}

struct QuitProgressOverlay: View {
    let title: String
    let subtitle: String?
    let style: QuitProgressOverlayStyle
    let cardWidth: CGFloat

    init(
        title: String,
        subtitle: String? = nil,
        style: QuitProgressOverlayStyle = .settings,
        cardWidth: CGFloat = 300
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.cardWidth = cardWidth
    }

    var body: some View {
        ZStack {
            (style == .settings ? Color.clear : Color.black.opacity(0.45))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .onHover { _ in }
                .allowsHitTesting(true)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)

                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(width: cardWidth)
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
                        style == .settings ? Color.primary.opacity(0.08) : Color.primary.opacity(LiquidGlass.enabled ? 0.18 : 0.12),
                        lineWidth: 0.8
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }
}
