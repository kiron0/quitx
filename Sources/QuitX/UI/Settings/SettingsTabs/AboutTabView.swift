import AppKit
import SwiftUI

private final class AboutTabPresentationState: ObservableObject {
    @Published var hoveredResource: String?
}

private struct AboutHighlight: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(QuitXTheme.accent)
                .frame(width: 28, height: 28)
                .background(QuitXTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AboutTabView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var presentationState = AboutTabPresentationState()

    private static let resourceColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    private var status: (symbol: String, text: String, color: Color) {
        switch updateChecker.checkState {
        case .idle: return ("checkmark.seal", "Ready", .secondary)
        case .checking: return ("arrow.triangle.2.circlepath", "Checking…", QuitXTheme.accent)
        case .available(let version, _, _): return ("arrow.down.circle.fill", "Version \(version) available", QuitXTheme.accent)
        case .upToDate: return ("checkmark.circle.fill", "Up to date", .green)
        case .failed: return ("exclamationmark.circle.fill", "Check unavailable", .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero

            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "Why QuitX", symbol: "sparkles")
                HStack(alignment: .top, spacing: 18) {
                    AboutHighlight(symbol: "swift", title: "Native", detail: "Fast SwiftUI app with a small footprint.")
                    AboutHighlight(symbol: "hand.raised.fill", title: "Private", detail: "No account, tracking or analytics.")
                    AboutHighlight(symbol: "chevron.left.forwardslash.chevron.right", title: "Open Source", detail: "Free forever under the MIT license.")
                }
                .padding(.leading, 33)
            }

            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "Resources", symbol: "lifepreserver")

                LazyVGrid(columns: Self.resourceColumns, alignment: .leading, spacing: 12) {
                    resourceCard(
                        id: "help",
                        symbol: "questionmark.circle.fill",
                        tint: Color(red: 0.24, green: 0.62, blue: 0.96),
                        title: "Help Center",
                        detail: "Guides for every feature.",
                        footer: "Open Help"
                    ) {
                        HelpWindowController.shared.show()
                    }
                    resourceCard(
                        id: "changelog",
                        symbol: "sparkles",
                        tint: Color(red: 0.62, green: 0.45, blue: 0.96),
                        title: "What's New",
                        detail: "Recent features and fixes.",
                        footer: "View Updates"
                    ) {
                        ChangelogWindowController.shared.show()
                    }
                    resourceCard(
                        id: "issues",
                        symbol: "ladybug.fill",
                        tint: Color(red: 0.94, green: 0.38, blue: 0.36),
                        title: "Report an Issue",
                        detail: "Share feedback or a bug.",
                        footer: "Open GitHub"
                    ) {
                        NSWorkspace.shared.open(QuitXConstants.issuesURL)
                    }
                }
                .padding(.leading, 33)
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                Image(systemName: "heart.fill").foregroundStyle(QuitXTheme.accent)
                Text("Designed and built by")
                Button(QuitXConstants.author) {
                    NSWorkspace.shared.open(QuitXConstants.authorURL)
                }
                .buttonStyle(.link)
                Text("•").foregroundStyle(Color.secondary.opacity(0.6))
                Button("GitHub") { NSWorkspace.shared.open(QuitXConstants.repositoryURL) }
                .buttonStyle(.link)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Color.secondary)
        }
        .padding(.top, 14)
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        .frame(minHeight: 470, alignment: .topLeading)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            QuitXAppIconView(size: 72, cornerRadius: 15)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(QuitXConstants.appName).font(.system(size: 21, weight: .bold))
                    Text("VERSION \(updateChecker.currentVersion)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(QuitXTheme.accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(QuitXTheme.accent.opacity(0.11), in: Capsule())
                }
                Text("Quit everything. Keep what matters.").font(.system(size: 12.5, weight: .medium))
                HStack(spacing: 5) {
                    Image(systemName: status.symbol).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(status.color)
                    Text(status.text).font(.system(size: 10.5)).foregroundStyle(Color.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 7) {
                Button(updateChecker.isChecking ? "Checking…" : "Check for Updates") {
                    Task { await updateChecker.checkForUpdates(isUserInitiated: true) }
                }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(QuitXTheme.accent)
                .disabled(updateChecker.isChecking)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [QuitXTheme.accent.opacity(0.12), QuitXTheme.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func resourceCard(
        id: String,
        symbol: String,
        tint: Color,
        title: String,
        detail: String,
        footer: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            FeatureCard(
                symbol: symbol,
                tint: tint,
                title: title,
                detail: detail,
                footer: footer,
                isHovered: presentationState.hoveredResource == id
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .onHover { hovering in
            presentationState.hoveredResource = hovering
                ? id
                : (presentationState.hoveredResource == id ? nil : presentationState.hoveredResource)
        }
    }
}
