import AppKit
import SwiftUI

enum MarqueePromo {
    static let name = "Marquee"
    static let tagline = "Capture the screen. Keep the clipboard."
    static let summary = "A free, open-source menu bar app for screenshots, screen recordings, measuring, color picking and clipboard history. Everything stays on your Mac."
    static let author = "Nahid Hassan Bulbul"
    static let repositoryURL = URL(string: "https://github.com/Treposting/marquee")!
    static let downloadURL = URL(string: "https://github.com/Treposting/marquee/releases/latest")!
    static let websiteURL = URL(string: "https://treposting.github.io/marquee/")!
    static let yellow = Color(red: 1.0, green: 0.812, blue: 0.102)
    static let ink = Color(red: 0.114, green: 0.114, blue: 0.122)
    static let badges = ["Free", "Open source", "macOS 13+", "Apple silicon & Intel"]

    struct Feature: Identifiable {
        let title: String
        let symbol: String
        let detail: String
        var id: String { title }
    }

    static let features: [Feature] = [
        Feature(title: "All-in-One", symbol: "square.grid.3x3.square", detail: "One shortcut, one toolbar: shoot, record, copy text, pin and pick colors."),
        Feature(title: "Capture", symbol: "camera.viewfinder", detail: "Area, window, full screen or scrolling, with annotations and redaction."),
        Feature(title: "Copy Text (OCR)", symbol: "text.viewfinder", detail: "Grab text from anything on screen with Apple's Vision framework."),
        Feature(title: "Record", symbol: "record.circle", detail: "MP4 at 30 or 60 fps with mic, desktop audio, a camera bubble and GIF export."),
        Feature(title: "Measure", symbol: "ruler", detail: "Edge distances, snapping, guides and multi-display support."),
        Feature(title: "Color Picker", symbol: "eyedropper.halffull", detail: "Copy any color as HEX, RGB, HSL or SwiftUI code. Keeps your last 48."),
        Feature(title: "Clipboard History", symbol: "list.clipboard", detail: "Search text, links, images and files. Pin favorites, click to paste."),
        Feature(title: "Private by Design", symbol: "lock.shield", detail: "No account, no cloud. Password-manager items are never recorded."),
        Feature(title: "Native & Light", symbol: "swift", detail: "Built in Swift for macOS 13 to 27, with Liquid Glass on macOS 26.")
    ]

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct MarqueeIconView: View {
    var size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let tile = dark ? Color(red: 0.165, green: 0.165, blue: 0.176) : MarqueePromo.yellow
        let mark = dark ? MarqueePromo.yellow : MarqueePromo.ink
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 512
            context.scaleBy(x: scale, y: scale)
            let tileRect = CGRect(x: 16, y: 16, width: 480, height: 480)
            let tilePath = Path(roundedRect: tileRect, cornerRadius: 116, style: .continuous)
            context.fill(tilePath, with: .color(tile))
            if dark {
                context.stroke(tilePath, with: .color(Color.white.opacity(0.1)), lineWidth: 3)
            }

            var brackets = Path()
            brackets.move(to: CGPoint(x: 112, y: 196))
            brackets.addLine(to: CGPoint(x: 112, y: 128))
            brackets.addArc(tangent1End: CGPoint(x: 112, y: 112), tangent2End: CGPoint(x: 128, y: 112), radius: 16)
            brackets.addLine(to: CGPoint(x: 196, y: 112))
            brackets.move(to: CGPoint(x: 400, y: 316))
            brackets.addLine(to: CGPoint(x: 400, y: 384))
            brackets.addArc(tangent1End: CGPoint(x: 400, y: 400), tangent2End: CGPoint(x: 384, y: 400), radius: 16)
            brackets.addLine(to: CGPoint(x: 316, y: 400))
            context.stroke(brackets, with: .color(mark), style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))

            let outline = Path(roundedRect: CGRect(x: 166, y: 166, width: 124, height: 124), cornerRadius: 20, style: .continuous)
            context.stroke(outline, with: .color(mark), lineWidth: 26)
            let filled = Path(roundedRect: CGRect(x: 222, y: 222, width: 124, height: 124), cornerRadius: 20, style: .continuous)
            context.fill(filled, with: .color(mark))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(size > 30 ? 0.18 : 0), radius: size > 30 ? 4 : 0, y: size > 30 ? 2 : 0)
        .accessibilityHidden(true)
    }
}

@MainActor
final class MarqueePromoState: ObservableObject {
    @Published var hoveredLink: String?
}

struct MarqueePromoView: View {
    @StateObject private var state = MarqueePromoState()

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
                        ForEach(MarqueePromo.features) { feature in
                            FeatureCard(
                                symbol: feature.symbol,
                                tint: MarqueePromo.yellow,
                                title: feature.title,
                                detail: feature.detail,
                                detailLines: 3,
                                symbolColor: MarqueePromo.ink
                            )
                        }
                    }
                }

                footer
            }
            .padding(.bottom, 24)
            .frame(width: SettingsTab.contentWidth, alignment: .leading)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                MarqueeIconView(size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(MarqueePromo.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.primary)
                    Text(MarqueePromo.tagline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                    HStack(spacing: 5) {
                        ForEach(MarqueePromo.badges, id: \.self) { badge in
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

            Text(MarqueePromo.summary)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                linkButton("Explore on GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: MarqueePromo.repositoryURL, primary: true)
                linkButton("Download", symbol: "arrow.down.circle", url: MarqueePromo.downloadURL, primary: false)
                linkButton("Website", symbol: "safari", url: MarqueePromo.websiteURL, primary: false)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [MarqueePromo.yellow.opacity(0.22), MarqueePromo.yellow.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarqueePromo.yellow.opacity(0.4), lineWidth: 0.6)
        )
    }

    private func linkButton(_ title: String, symbol: String, url: URL, primary: Bool) -> some View {
        let hovered = state.hoveredLink == title
        return Button {
            MarqueePromo.open(url)
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
            .foregroundStyle(primary ? Color.black.opacity(0.85) : (hovered ? MarqueePromo.yellow : Color.primary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(primary ? MarqueePromo.yellow.opacity(hovered ? 1 : 0.92) : Color.primary.opacity(hovered ? 0.1 : 0.06))
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
                .foregroundStyle(MarqueePromo.yellow)
            Text("Made by \(MarqueePromo.author). MIT licensed, free forever.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }
}
