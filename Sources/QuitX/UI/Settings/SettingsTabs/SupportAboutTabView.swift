import SwiftUI
import AppKit

struct SupportTabCloneView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get in touch for any feedback, questions or feature requests!")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary)
                .lineSpacing(3)
                .padding(.top, 24)

            Button("Contact") {
                if let url = QuitXConstants.contactURL() {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 12))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(width: 400, height: 139, alignment: .topLeading)
        .background(QuitXTheme.windowBackground)
    }
}

struct AboutTabCloneView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
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
        .frame(width: 400, height: 130)
        .background(QuitXTheme.windowBackground)
    }
}
