import SwiftUI
import AppKit

private final class WelcomeState: ObservableObject {
    @Published var openAtLogin: Bool = false
    @Published var globalShortcutEnabled: Bool = false
}

struct WelcomeView: View {
    @EnvironmentObject private var configStore: ConfigStore
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    @StateObject private var state = WelcomeState()

    var body: some View {
        VStack(spacing: 16) {
            // App icon with subtle shadow
            if let img = NSImage(contentsOfFile: "Support/Icons/icon_128x128.png") ?? Bundle.main.image(forResource: "AppIcon") {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .padding(.top, 10)
            }

            // Heading & Subtitle
            VStack(spacing: 6) {
                Text("Howdy Quitter 👋")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("QuitX is now accessible from the icon in your taskbar above. Here are some settings to personalize your experience.\nHappy quitting!")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
            }

            // Quick toggles card
            VStack(spacing: 12) {
                HStack {
                    Text("Open at login")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Toggle("", isOn: $state.openAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                HStack {
                    Text("Shortcut (^⌥A)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Toggle("", isOn: $state.globalShortcutEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                HStack {
                    Text("Play Cool Sounds")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Toggle("", isOn: $configStore.config.playSounds)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: configStore.config.playSounds) {
                            configStore.save()
                        }
                }

                HStack {
                    Text("Default:")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Picker("", selection: $configStore.config.force) {
                        Text("Normal Quit").tag(QuitXConfig.ForceMode.normal)
                        Text("Force Quit").tag(QuitXConfig.ForceMode.force)
                    }
                    .frame(width: 120)
                    .labelsHidden()
                    .onChange(of: configStore.config.force) {
                        configStore.save()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            // View all settings link
            Button {
                onOpenSettings()
            } label: {
                Text("View All Settings")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .underline()
            }
            .buttonStyle(.plain)

            // Primary action button
            Button {
                onDismiss()
            } label: {
                Text("Got it!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(width: 300, height: 420)
        .background(
            ZStack {
                Color(red: 0.14, green: 0.14, blue: 0.15).opacity(0.96)
                VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .preferredColorScheme(.dark)
    }
}
