import AppKit
import SwiftUI

struct PermissionsTabView: View {
    @ObservedObject private var center = PermissionCenter.shared

    private var requiredKinds: [PermissionKind] { PermissionKind.allCases.filter(\.isRequired) }
    private var optionalKinds: [PermissionKind] { PermissionKind.allCases.filter { !$0.isRequired } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsInlineNote(
                symbol: "hand.raised.fill",
                title: "macOS stays in control",
                detail: "QuitX only asks for what a feature needs. Turn any permission off in System Settings > Privacy & Security at any time."
            )

            section(title: "Needed for Features", symbol: "checkmark.shield", kinds: requiredKinds)
            section(title: "Optional", symbol: "slider.horizontal.3", kinds: optionalKinds)

            HStack(spacing: 10) {
                Button("Show QuitX in Finder") {
                    center.revealAppInFinder()
                }
                .buttonStyle(UninstallSecondaryButtonStyle())
                .help("Drag QuitX into a System Settings list if it isn't shown there.")

                Button("Open Privacy & Security") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(UninstallSecondaryButtonStyle())

                Spacer(minLength: 0)
            }
        }
        .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        .task {
            center.startObserving()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                center.refresh()
            }
        }
    }

    private func section(title: String, symbol: String, kinds: [PermissionKind]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: title, symbol: symbol)
            VStack(spacing: 8) {
                ForEach(kinds) { kind in
                    PermissionCard(kind: kind, status: center.status(of: kind), isBusy: center.busy.contains(kind)) { action in
                        center.perform(action, for: kind)
                    }
                }
            }
        }
    }
}

private struct PermissionCard: View {
    let kind: PermissionKind
    let status: PermissionStatus
    let isBusy: Bool
    let perform: (PermissionAction) -> Void

    private var primary: PermissionAction { PermissionAction.primary(for: kind, status: status) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QuitXTheme.accent)
                .frame(width: 32, height: 32)
                .background(QuitXTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(kind.title)
                        .font(.system(size: 12.5, weight: .semibold))
                    PermissionStatusBadge(status: status)
                }
                Text(kind.purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Used by: \(kind.usedBy.joined(separator: ", "))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                if let hint {
                    Label(hint, systemImage: "info.circle")
                        .font(.system(size: 10.5))
                        .foregroundStyle(status.needsAttention ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.small)
                } else if primary != .none {
                    Button(primary.title(for: kind)) { perform(primary) }
                        .buttonStyle(UninstallPrimaryButtonStyle(isEnabled: true))
                }
                if !isBusy, status != .unavailable, primary != .openSettings {
                    Button(status == .granted ? "Manage" : "Settings") { perform(.openSettings) }
                        .buttonStyle(UninstallSecondaryButtonStyle())
                        .help("Opens the \(kind.title) list in System Settings.")
                }
                if !isBusy, status == .denied, kind.tccService != nil {
                    Button("Reset") { perform(.repair) }
                        .buttonStyle(UninstallSecondaryButtonStyle())
                        .help("Clears the macOS decision for QuitX and asks again.")
                }
            }
        }
        .padding(12)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(status.needsAttention ? Color.orange.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title), \(status.label)")
    }

    private var hint: String? {
        switch (kind, status) {
        case (.accessibility, .needsRepair):
            return "macOS reset access after an update. Repair clears the old entry, then turn QuitX on again."
        case (.fullDiskAccess, .notGranted):
            return "Turn on QuitX in the list. If it's missing, drag QuitX in from Finder."
        case (.finderAutomation, .denied):
            return "Turn on Finder under QuitX in Automation, or Reset to be asked again."
        case (.notifications, .denied):
            return "Turn on Allow Notifications for QuitX."
        case (.loginItem, .requiresApproval):
            return "Turn on QuitX under Login Items & Extensions."
        case (_, .unavailable):
            return "Only available when QuitX runs as an installed app."
        default:
            return nil
        }
    }
}

struct PermissionStatusBadge: View {
    let status: PermissionStatus

    private var color: Color {
        switch status {
        case .granted: .green
        case .denied: .red
        case .needsRepair, .requiresApproval: .orange
        case .notGranted, .unavailable: .secondary
        }
    }

    private var symbol: String {
        switch status {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .needsRepair, .requiresApproval: "exclamationmark.triangle.fill"
        case .notGranted: "circle.dashed"
        case .unavailable: "minus.circle"
        }
    }

    var body: some View {
        Label(status.label, systemImage: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}
