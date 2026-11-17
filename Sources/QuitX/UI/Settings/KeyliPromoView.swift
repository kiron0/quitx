import AppKit
import SwiftUI

enum KeyliPromo {
    static let name = "Keyli"
    static let bundleIdentifier = "io.coreify.keyli"
    static let tagline = "An on-screen keyboard for your menu bar."
    static let summary = "A free, open-source on-screen keyboard that types into any app without taking its focus. Latching modifiers, keycap sounds, live input-source labels and 52 themes. 100% offline."
    static let author = "Toufiq Hasan Kiron"
    static let repositoryURL = URL(string: "https://github.com/kiron0/keyli")!
    static let downloadURL = URL(string: "https://github.com/kiron0/keyli/releases/latest")!
    static let amber = Color(red: 0.910, green: 0.639, blue: 0.239)
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.110)
    static let badges = ["Free", "Open source", "Offline", "macOS 14+"]

    struct Feature: Identifiable {
        let title: String
        let symbol: String
        let detail: String
        var id: String { title }
    }

    static let features: [Feature] = [
        Feature(title: "Keeps Your Focus", symbol: "keyboard", detail: "Click keys to type into the app you're using. Keyli never steals its focus."),
        Feature(title: "Latching Modifiers", symbol: "command", detail: "Shift, Option, Control and Command latch for one key or stay on."),
        Feature(title: "Mac Function Row", symbol: "sun.max", detail: "Brightness, Mission Control, media and volume. Latch fn for F1–F12."),
        Feature(title: "Every Layout", symbol: "globe", detail: "ANSI, ISO, JIS and compact layouts with labels that follow your input source."),
        Feature(title: "Keycap Sounds", symbol: "speaker.wave.2", detail: "Built-in and community sound packs, on screen and on your Mac's keyboard."),
        Feature(title: "52 Themes", symbol: "paintpalette", detail: "Native, mechanical and retro looks, plus Theme Studio to make your own."),
        Feature(title: "Snippet Keys", symbol: "text.cursor", detail: "One-click keys that type a phrase or send a shortcut."),
        Feature(title: "Global Shortcuts", symbol: "command.square", detail: "Show the keyboard, switch themes, toggle sounds and more from anywhere."),
        Feature(title: "Offline & Private", symbol: "lock.shield", detail: "No account, no tracking. Nothing you type is recorded or stored.")
    ]

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct KeyliIconView: View {
    var size: CGFloat

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255).opacity(a)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 824
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -100, y: -100)

            let plate = Path(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 184, style: .continuous)
            context.fill(
                plate,
                with: .linearGradient(
                    Gradient(colors: [Self.rgb(243, 239, 231), Self.rgb(217, 210, 196)]),
                    startPoint: CGPoint(x: 512, y: 100),
                    endPoint: CGPoint(x: 512, y: 924)
                )
            )
            context.fill(
                plate,
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0)]),
                    center: CGPoint(x: 300, y: 160),
                    startRadius: 0,
                    endRadius: 650
                )
            )
            context.stroke(plate, with: .color(Color.white.opacity(0.3)), lineWidth: 5)

            let panelRect = CGRect(x: 196, y: 318, width: 632, height: 388)
            let panel = Path(roundedRect: panelRect, cornerRadius: 64, style: .continuous)
            context.fill(
                panel,
                with: .linearGradient(
                    Gradient(colors: [Self.rgb(58, 59, 64), Self.rgb(30, 31, 35)]),
                    startPoint: CGPoint(x: 512, y: panelRect.minY),
                    endPoint: CGPoint(x: 512, y: panelRect.maxY)
                )
            )
            context.stroke(
                Path(roundedRect: panelRect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 63, style: .continuous),
                with: .color(Color.white.opacity(0.14)),
                lineWidth: 3
            )

            let key: CGFloat = 92
            let gap: CGFloat = 18
            let keyHeight = key * 0.86
            let rowWidth = 5 * key + 4 * gap
            let rowX = panelRect.midX - rowWidth / 2
            for row in 0..<2 {
                for column in 0..<5 {
                    let rect = CGRect(
                        x: rowX + CGFloat(column) * (key + gap),
                        y: panelRect.minY + 52 + CGFloat(row) * (key + gap),
                        width: key,
                        height: keyHeight
                    )
                    let lit = row == 0 && column == 3
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 22, style: .continuous),
                        with: .color(lit ? KeyliPromo.amber : Color.white.opacity(0.13))
                    )
                }
            }

            let barWidth = 3 * key + 2 * gap
            let bar = CGRect(x: panelRect.midX - barWidth / 2, y: panelRect.minY + 52 + 2 * (key + gap), width: barWidth, height: keyHeight)
            context.fill(Path(roundedRect: bar, cornerRadius: 22, style: .continuous), with: .color(Color.white.opacity(0.13)))

            let caret = CGRect(x: 488, y: 180, width: 48, height: 112)
            context.fill(Path(roundedRect: caret, cornerRadius: 24, style: .continuous), with: .color(KeyliPromo.amber))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(size > 30 ? 0.18 : 0), radius: size > 30 ? 4 : 0, y: size > 30 ? 2 : 0)
        .accessibilityHidden(true)
    }
}

@MainActor
final class KeyliPromoState: ObservableObject {
    @Published var hoveredLink: String?
}

struct KeyliPromoView: View {
    @StateObject private var state = KeyliPromoState()

    private static let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHAT IT DOES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)

                    LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                        ForEach(KeyliPromo.features) { feature in
                            FeatureCard(
                                symbol: feature.symbol,
                                tint: KeyliPromo.amber,
                                title: feature.title,
                                detail: feature.detail,
                                detailLines: 3
                            )
                        }
                    }
                }

                footer
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
            .frame(width: SettingsTab.contentWidth, alignment: .leading)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                KeyliIconView(size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(KeyliPromo.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.primary)
                    Text(KeyliPromo.tagline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                    HStack(spacing: 5) {
                        ForEach(KeyliPromo.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.75))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.primary.opacity(0.07), in: Capsule())
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }

            Text(KeyliPromo.summary)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                linkButton("Explore on GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: KeyliPromo.repositoryURL, primary: true)
                linkButton("Download", symbol: "arrow.down.circle", url: KeyliPromo.downloadURL, primary: false)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [KeyliPromo.amber.opacity(0.20), KeyliPromo.amber.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KeyliPromo.amber.opacity(0.4), lineWidth: 0.6)
        )
    }

    private func linkButton(_ title: String, symbol: String, url: URL, primary: Bool) -> some View {
        let hovered = state.hoveredLink == title
        return Button {
            KeyliPromo.open(url)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(primary ? KeyliPromo.ink : (hovered ? KeyliPromo.amber : Color.primary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(primary ? KeyliPromo.amber.opacity(hovered ? 1 : 0.92) : Color.primary.opacity(hovered ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(primary ? Color.clear : Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
        .onHover { hovering in
            if hovering {
                state.hoveredLink = title
            } else if state.hoveredLink == title {
                state.hoveredLink = nil
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(KeyliPromo.amber)
            Text("Made by \(KeyliPromo.author). MIT licensed, free forever.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }
}
