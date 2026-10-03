import SwiftUI
import AppKit

struct WelcomeView: View {
    var onDismiss: () -> Void
    var onOpenSettings: () -> Void

    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared

    private let gold = QuitXTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 16)
                .padding(.bottom, 16)


            quickSetup
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                Button("Settings") {
                    onOpenSettings()
                }
                .buttonStyle(WelcomeSecondaryButtonStyle())

                Button("Get Started") {
                    onDismiss()
                }
                .buttonStyle(WelcomePrimaryButtonStyle(color: gold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            QuitXTheme.windowBackground
                .ignoresSafeArea()
        }
    }

    private var quickSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            setupToggle("Open QuitX at login", isOn: $launchService.isEnabled)
            setupToggle("Play sounds", isOn: Binding(
                get: { configStore.config.playSounds },
                set: {
                    configStore.config.playSounds = $0
                    configStore.save()
                }
            ))
            setupToggle("Deselect apps by default", isOn: Binding(
                get: { !configStore.config.defaultSelectAll },
                set: {
                    configStore.config.defaultSelectAll = !$0
                    configStore.save(refreshAppList: true)
                    AppListViewModel.shared.applyDefaultSelection()
                }
            ))

            HStack(spacing: 12) {
                Text("Default quit mode")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .layoutPriority(1)

                Spacer()

                Picker("", selection: Binding(
                    get: { configStore.config.force },
                    set: {
                        configStore.config.force = $0
                        configStore.save(refreshAppList: true)
                    }
                )) {
                    Text("Normal").tag(QuitXConfig.ForceMode.normal)
                    Text("Force Quit").tag(QuitXConfig.ForceMode.force)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 168)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
    }

    private func setupToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                QuitXSelectionCheckbox(isSelected: isOn.wrappedValue)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hero: some View {
        VStack(spacing: 8) {
            QuitXAppIconView(size: 54, cornerRadius: 12)

            Text("Welcome to QuitX")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Quickly quit apps and reclaim memory.")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
    }

    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(gold)
                .frame(width: 28, height: 28)
                .background(gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? 0.55 : 0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Color.primary.opacity(configuration.isPressed ? 0.04 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
