import AppKit
import SwiftUI

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

private struct AboutAction: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(QuitXTheme.accent)
                    .frame(width: 24, height: 24)
                    .background(QuitXTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 11.5, weight: .medium))
                    Text(detail).font(.system(size: 9.5)).foregroundStyle(Color.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.75))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(detail)
    }
}

struct AboutTabView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

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

            panel(title: "Resources", symbol: "lifepreserver") {
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 10) {
                        AboutAction(symbol: "questionmark.circle", title: "Help Center", detail: "Learn every QuitX feature") {
                            HelpWindowController.shared.show()
                        }
                        Divider().opacity(0.3)
                        AboutAction(symbol: "sparkles", title: "What's New", detail: "See recent features and fixes") {
                            ChangelogWindowController.shared.show()
                        }
                    }
                    VStack(spacing: 10) {
                        AboutAction(symbol: "safari", title: "Website", detail: "Downloads, guides and details") {
                            NSWorkspace.shared.open(QuitXConstants.websiteURL)
                        }
                        Divider().opacity(0.3)
                        AboutAction(symbol: "ladybug", title: "Report an Issue", detail: "Share feedback or report a bug") {
                            NSWorkspace.shared.open(QuitXConstants.issuesURL)
                        }
                    }
                }
            }

            Spacer(minLength: 16)

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

    private func panel<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11.5, weight: .semibold))
            content()
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}
