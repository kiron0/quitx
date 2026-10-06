import SwiftUI
import AppKit

private final class AboutTabState: ObservableObject {
    @Published var hoveredButtonId: String? = nil
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @StateObject private var state = AboutTabState()

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            QuitXAppIconView(size: 68, cornerRadius: 15)
                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1.5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 7) {
                    Text(QuitXConstants.appName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)

                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8.5))
                            .foregroundStyle(QuitXTheme.accent)
                        Text("v\(updateChecker.currentVersion)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                }

                Text(QuitXConstants.copyright)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 7) {
                    actionButton(
                        id: "updates",
                        title: updateChecker.isChecking ? "Checking…" : "Check Updates",
                        systemImage: updateChecker.isChecking ? nil : "arrow.triangle.2.circlepath",
                        isLoading: updateChecker.isChecking,
                        isDisabled: updateChecker.isChecking
                    ) {
                        Task {
                            await updateChecker.checkForUpdates(isUserInitiated: true)
                        }
                    }

                    actionButton(
                        id: "sayhi",
                        title: "Say hi 👋",
                        systemImage: nil,
                        isLoading: false,
                        isDisabled: false
                    ) {
                        if let url = QuitXConstants.sayHiURL() {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(.top, 1)

                // Modern Contact & Support Card
                HStack(spacing: 6) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(QuitXTheme.accent)

                    Text("Questions or ideas?")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)

                    Spacer(minLength: 4)

                    contactButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(width: 400, height: 124, alignment: .center)
        .background(QuitXTheme.windowBackground)
    }

    private func actionButton(
        id: String,
        title: String,
        systemImage: String?,
        isLoading: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = state.hoveredButtonId == id
        return Button(action: action) {
            HStack(spacing: 4.5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isHovered ? QuitXTheme.accent : Color.secondary)
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? Color.primary : Color.primary.opacity(0.85))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.07) : QuitXTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.primary.opacity(0.16) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovered in
            if isHovered {
                state.hoveredButtonId = id
            } else if state.hoveredButtonId == id {
                state.hoveredButtonId = nil
            }
        }
    }

    private var contactButton: some View {
        let isHovered = state.hoveredButtonId == "contact"
        return Button {
            if let url = QuitXConstants.contactURL() {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 3) {
                Text("Contact Support")
                    .font(.system(size: 10.5, weight: .semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(isHovered ? QuitXTheme.accent : Color.primary.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? QuitXTheme.accent.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                state.hoveredButtonId = "contact"
            } else if state.hoveredButtonId == "contact" {
                state.hoveredButtonId = nil
            }
        }
    }
}
