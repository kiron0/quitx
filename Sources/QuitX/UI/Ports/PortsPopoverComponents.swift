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

struct PortsLoadingView: View {
    var body: some View {
        QuitXLoadingView(text: "Scanning listening ports…", symbol: "network")
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
