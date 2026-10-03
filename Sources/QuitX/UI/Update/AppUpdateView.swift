import AppKit
import SwiftUI

struct AppUpdateView: View {
    @ObservedObject var service = UpdateDownloadService.shared
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 16) {
                appIconSection

                VStack(alignment: .leading, spacing: 8) {
                    titleSection
                    contentSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            footerActions
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(width: 390)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            QuitXTheme.windowBackground
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        Text("Update")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
    }


    private var appIconSection: some View {
        ZStack(alignment: .bottomTrailing) {
            QuitXAppIconView(size: 60, cornerRadius: 13)

            if case .ready = service.state {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.green)
                    .font(.system(size: 18, weight: .bold))
                    .offset(x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
            } else if case .failed = service.state {
                Image(systemName: "exclamationmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.red)
                    .font(.system(size: 18, weight: .bold))
                    .offset(x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch service.state {
            case .idle:
                Text("Preparing Update...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)

            case .downloading:
                Text("Downloading QuitX v\(service.targetVersion)...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)

            case .extracting:
                Text("Verifying Update...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)

            case .ready:
                Text("QuitX v\(service.targetVersion) Ready to Install")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)

            case .failed:
                Text("Update Failed")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch service.state {
        case .idle:
            Text("Connecting to update server...")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)

        case .downloading(let progress, let bytesDownloaded, let totalBytes, let speed):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(QuitXTheme.accent)

                HStack {
                    if totalBytes > 0 {
                        Text("\(UpdateDownloadService.formatBytes(bytesDownloaded)) of \(UpdateDownloadService.formatBytes(totalBytes))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    } else {
                        Text("\(UpdateDownloadService.formatBytes(bytesDownloaded)) downloaded")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer()

                    if !speed.isEmpty {
                        Text(speed)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .padding(.top, 4)

        case .extracting:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Extracting and verifying package contents...")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.top, 6)

        case .ready:
            VStack(alignment: .leading, spacing: 4) {
                Text("The latest version has been downloaded and verified.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary.opacity(0.85))

                Text("QuitX will restart to finish installing the update.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 4)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .lineLimit(3)
            }
            .padding(.top, 4)
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Spacer()

            switch service.state {
            case .idle, .downloading, .extracting:
                Button("Cancel") {
                    service.cancelDownload()
                    onDismiss()
                }
                .buttonStyle(UpdateSecondaryButtonStyle())

            case .ready(let stagedURL, _):
                Button("Later") {
                    onDismiss()
                }
                .buttonStyle(UpdateSecondaryButtonStyle())

                Button("Restart & Update") {
                    service.installAndRelaunch(stagedURL: stagedURL)
                }
                .buttonStyle(UpdatePrimaryButtonStyle(color: QuitXTheme.accent))

            case .failed:
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(UpdateSecondaryButtonStyle())

                Button("Retry") {
                    service.retryLastDownload()
                }
                .buttonStyle(UpdatePrimaryButtonStyle(color: QuitXTheme.accent))
            }
        }
    }
}

private struct UpdatePrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct UpdateSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primary.opacity(configuration.isPressed ? 0.55 : 0.82))
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Color.primary.opacity(configuration.isPressed ? 0.04 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
