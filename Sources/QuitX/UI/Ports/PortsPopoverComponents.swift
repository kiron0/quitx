import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PopoverTabBar: View {
    @Binding var selection: PopoverTab

    var body: some View {
        QuitXSegmentedControl(
            segments: [
                QuitXSegment(value: PopoverTab.apps, title: "Apps", symbol: "square.grid.2x2"),
                QuitXSegment(value: PopoverTab.ports, title: "Ports", symbol: "network")
            ],
            selection: $selection
        )
    }
}

private final class PortsLoadingPulse: ObservableObject {
    @Published var active = false
}

struct PortsLoadingView: View {
    @StateObject private var pulse = PortsLoadingPulse()

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(QuitXTheme.accent.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulse.active ? 1.8 : 1)
                    .opacity(pulse.active ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse.active)
                Circle()
                    .fill(QuitXTheme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "network")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(QuitXTheme.accent)
            }
            .frame(width: 64, height: 64)
            Text("Scanning listening ports…")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        .onAppear { pulse.active = true }
    }
}

@MainActor
enum PortDiagnosticsExporter {
    static func export() {
        let vm = PortListViewModel.shared
        StatusItemController.shared?.closePopover()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "QuitX-Port-Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let report = ListenerHistoryStore.shared.diagnostics(
            ports: vm.ports,
            metrics: PortService.shared.lastScanMetrics
        )
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            vm.showToastMessage("Diagnostics exported")
        } catch {
            vm.showToastMessage("Couldn't export diagnostics", isError: true)
        }
    }

    static func copyHistory() {
        let text = ListenerHistoryStore.shared.entries.prefix(50).map {
            "\($0.date) :\($0.port) \($0.event) \($0.detail)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        PortListViewModel.shared.showToastMessage("Listener history copied")
    }
}
