import AppKit
import SwiftUI

enum HopiloPromo {
    static let name = "Hopilo"
    static let tagline = "Every AI session, ready to continue."
    static let summary = "A free, open-source app that keeps every AI coding session on your computer with its files. Hit a usage limit or switch agents? Copy any session and continue in another AI. 100% offline."
    static let author = "Toufiq Hasan Kiron"
    static let repositoryURL = URL(string: "https://github.com/kiron0/hopilo")!
    static let downloadURL = URL(string: "https://github.com/kiron0/hopilo/releases/latest")!
    static let websiteURL = URL(string: "https://hopilo.kiron.dev/")!
    static let indigo = Color(red: 0.353, green: 0.388, blue: 1.0)
    static let gradientTop = Color(red: 0.478, green: 0.510, blue: 1.0)
    static let gradientBottom = Color(red: 0.431, green: 0.247, blue: 0.847)
    static let badges = ["Free", "Open source", "Offline", "macOS, Windows & Linux"]

    struct Feature: Identifiable {
        let title: String
        let symbol: String
        let detail: String
        var id: String { title }
    }

    static let features: [Feature] = [
        Feature(title: "One Library", symbol: "books.vertical", detail: "Every AI conversation and its files together in one local library."),
        Feature(title: "Continue Anywhere", symbol: "arrow.triangle.branch", detail: "Copy or export any session, ready to paste into another AI."),
        Feature(title: "19+ Agents", symbol: "terminal", detail: "Indexes sessions from local coding agents like Claude Code, Codex, Gemini and Cursor."),
        Feature(title: "Imports", symbol: "square.and.arrow.down", detail: "Bring in ChatGPT and Claude account exports, one conversation at a time."),
        Feature(title: "Browser Extension", symbol: "puzzlepiece.extension", detail: "Save web chats and insert a session into a chat box as an unsent draft."),
        Feature(title: "Search & Preview", symbol: "magnifyingglass", detail: "Search conversations deeply and preview the files they touched."),
        Feature(title: "Encrypted Backups", symbol: "externaldrive.badge.checkmark", detail: "Password-protected AES-256 backups you can verify and restore."),
        Feature(title: "Offline by Default", symbol: "lock.shield", detail: "Local-first. No account, no cloud. Your sessions stay on your computer."),
        Feature(title: "Native & Fast", symbol: "bolt", detail: "Built in Rust with Tauri 2. Lives in your menu bar with a quick panel.")
    ]

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

struct HopiloIconView: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 824
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -100, y: -100)

            let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
            let tilePath = Path(roundedRect: tileRect, cornerRadius: 184, style: .continuous)
            context.fill(
                tilePath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: HopiloPromo.gradientTop, location: 0),
                        .init(color: HopiloPromo.indigo, location: 0.48),
                        .init(color: HopiloPromo.gradientBottom, location: 1)
                    ]),
                    startPoint: CGPoint(x: 248, y: 100),
                    endPoint: CGPoint(x: 776, y: 924)
                )
            )
            context.fill(
                tilePath,
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0)]),
                    center: CGPoint(x: 331, y: 232),
                    startRadius: 0,
                    endRadius: 593
                )
            )
            context.stroke(tilePath, with: .color(Color.white.opacity(0.18)), lineWidth: 5)

            var mark = Path()
            mark.move(to: CGPoint(x: 360, y: 262))
            mark.addLine(to: CGPoint(x: 360, y: 762))
            mark.move(to: CGPoint(x: 360, y: 560))
            mark.addCurve(to: CGPoint(x: 512, y: 396), control1: CGPoint(x: 360, y: 452), control2: CGPoint(x: 432, y: 396))
            mark.addCurve(to: CGPoint(x: 664, y: 560), control1: CGPoint(x: 592, y: 396), control2: CGPoint(x: 664, y: 452))
            mark.addLine(to: CGPoint(x: 664, y: 712))
            mark.move(to: CGPoint(x: 604, y: 652))
            mark.addLine(to: CGPoint(x: 664, y: 712))
            mark.addLine(to: CGPoint(x: 724, y: 652))

            var markContext = context
            markContext.translateBy(x: 512, y: 512)
            markContext.scaleBy(x: 0.94, y: 0.94)
            markContext.translateBy(x: -548, y: -487)
            markContext.stroke(
                mark,
                with: .linearGradient(
                    Gradient(colors: [Color.white, Color(red: 0.894, green: 0.886, blue: 1.0)]),
                    startPoint: CGPoint(x: 0, y: 262),
                    endPoint: CGPoint(x: 0, y: 762)
                ),
                style: StrokeStyle(lineWidth: 92, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(size > 30 ? 0.18 : 0), radius: size > 30 ? 4 : 0, y: size > 30 ? 2 : 0)
        .accessibilityHidden(true)
    }
}

@MainActor
final class HopiloPromoState: ObservableObject {
    @Published var hoveredLink: String?
}

struct HopiloPromoView: View {
    @StateObject private var state = HopiloPromoState()

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
                        ForEach(HopiloPromo.features) { feature in
                            FeatureCard(
                                symbol: feature.symbol,
                                tint: HopiloPromo.indigo,
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
                HopiloIconView(size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(HopiloPromo.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.primary)
                    Text(HopiloPromo.tagline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                    HStack(spacing: 5) {
                        ForEach(HopiloPromo.badges, id: \.self) { badge in
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

            Text(HopiloPromo.summary)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.85))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                linkButton("Explore on GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: HopiloPromo.repositoryURL, primary: true)
                linkButton("Download", symbol: "arrow.down.circle", url: HopiloPromo.downloadURL, primary: false)
                linkButton("Website", symbol: "safari", url: HopiloPromo.websiteURL, primary: false)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [HopiloPromo.indigo.opacity(0.20), HopiloPromo.gradientBottom.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HopiloPromo.indigo.opacity(0.4), lineWidth: 0.6)
        )
    }

    private func linkButton(_ title: String, symbol: String, url: URL, primary: Bool) -> some View {
        let hovered = state.hoveredLink == title
        return Button {
            HopiloPromo.open(url)
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
            .foregroundStyle(primary ? Color.white : (hovered ? HopiloPromo.indigo : Color.primary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(primary ? HopiloPromo.indigo.opacity(hovered ? 1 : 0.92) : Color.primary.opacity(hovered ? 0.1 : 0.06))
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
                .foregroundStyle(HopiloPromo.indigo)
            Text("Made by \(HopiloPromo.author). Apache 2.0 licensed, free forever.")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
        }
    }
}
