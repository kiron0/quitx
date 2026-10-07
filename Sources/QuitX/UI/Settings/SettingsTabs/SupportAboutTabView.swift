import SwiftUI
import AppKit

private final class AboutTabState: ObservableObject {
    @Published var isContactHovered = false
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var state = AboutTabState()

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 20) {
                QuitXAppIconView(size: 70, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(QuitXConstants.appName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Text("⚡️ Version \(updateChecker.currentVersion)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Text(QuitXConstants.copyright)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)

                    HStack(spacing: 10) {
                        Button("Say hi 👋") {
                            if let url = QuitXConstants.sayHiURL() {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .font(.system(size: 11.5))

                        Button(updateChecker.isChecking ? "Checking..." : "Check Updates") {
                            Task {
                                await updateChecker.checkForUpdates(isUserInitiated: true)
                            }
                        }
                        .disabled(updateChecker.isChecking)
                        .font(.system(size: 11.5))
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)

            HStack(spacing: 11) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(QuitXTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Questions, feedback or ideas?")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.primary)

                    Text("We'd love to hear from you. Get in touch with us.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    if let url = QuitXConstants.contactURL() {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Contact")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundStyle(state.isContactHovered ? QuitXTheme.accent : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(state.isContactHovered ? QuitXTheme.accent.opacity(0.14) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.isContactHovered ? QuitXTheme.accent.opacity(0.35) : Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .onHover { state.isContactHovered = $0 }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 480, height: 186, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
    }
}
