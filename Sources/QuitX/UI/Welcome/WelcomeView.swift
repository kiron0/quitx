import SwiftUI
import AppKit

final class WelcomeViewState: ObservableObject {
    @Published var isAppeared: Bool = false
}

struct WelcomeView: View {
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void
    @StateObject private var state = WelcomeViewState()

    private let gold = QuitXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 36)

            VStack(spacing: 10) {
                guideRow(
                    icon: "menubar.rectangle",
                    title: "Open QuitX",
                    detail: "Click the QuitX icon in your menu bar."
                )
                guideRow(
                    icon: "checklist",
                    title: "Choose apps",
                    detail: "Select one app, several apps, or everything."
                )
                guideRow(
                    icon: "bolt.fill",
                    title: "Quit your way",
                    detail: "Click power to quit. Hold Option to force quit."
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)

            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)

                Text("Use the footer menu to stash a session, show background apps, or open Preferences.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)

            Spacer(minLength: 22)

            HStack(spacing: 10) {
                Button("Preferences") {
                    onOpenSettings()
                }
                .buttonStyle(WelcomeSecondaryButtonStyle())

                Button("Start using QuitX") {
                    onDismiss()
                }
                .buttonStyle(WelcomePrimaryButtonStyle(color: gold))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
        }
        .frame(width: 440, height: 600)
        .background(QuitXTheme.windowBackground)
        .preferredColorScheme(.dark)
        .scaleEffect(state.isAppeared ? 1.0 : 0.88)
        .opacity(state.isAppeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.36, dampingFraction: 0.66, blendDuration: 0), value: state.isAppeared)
        .onAppear {
            state.isAppeared = true
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(gold.opacity(0.16))
                    .frame(width: 100, height: 100)
                    .blur(radius: 18)

                QuitXAppIconView(size: 82, cornerRadius: 18)
            }

            Text("Welcome to QuitX")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Clear apps. Reclaim memory. Keep your flow.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.58))
        }
    }

    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(gold)
                .frame(width: 36, height: 36)
                .background(gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.black.opacity(0.86))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.55 : 0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
    }
}
