import AppKit
import SwiftUI
import Testing
@testable import QuitX

extension PortListViewModelTests {
    private static let snapshotDirectory: URL? = {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let qa = root.appendingPathComponent(".qa")
        guard FileManager.default.fileExists(atPath: qa.path) else { return nil }
        let dir = qa.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func snapshot<V: View>(_ view: V, size: NSSize, name: String, dark: Bool) async throws {
        guard let dir = Self.snapshotDirectory else { return }
        let hosting = NSHostingView(rootView: view.environmentObject(ConfigStore.shared))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 600_000_000)
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let data = rep.representation(using: .png, properties: [:])
        try data?.write(to: dir.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
        window.contentView = nil
    }

    @Test("Render popover tabs, ports settings and exclude window")
    func render() async throws {
        guard Self.snapshotDirectory != nil else { return }
        _ = NSApplication.shared
        let store = ConfigStore.shared
        let saved = store.config
        let savedTab = PopoverTab.stored()
        defer {
            store.config = saved
            savedTab.store()
            PortListViewModel.shared.ports = []
            PortListViewModel.shared.hasLoadedOnce = false
        }
        store.config.portsEnabled = true
        store.config.portsExcluded = [5432, 9229]
        store.config.liquidGlassEnabled = false
        let ports = PortListViewModel.shared
        ports.ports = [
            PortInfo(port: 3000, pid: 4101, processName: "node", command: "next dev", bindAddress: "127.0.0.1", memoryBytes: 182_000_000, cpuUsage: 3.2, cwd: "/Users/me/web", isDevServer: true),
            PortInfo(port: 5173, pid: 4102, processName: "node", command: "vite", bindAddress: "*", memoryBytes: 96_000_000, cpuUsage: 0.4, cwd: "/Users/me/app", isDevServer: true),
            PortInfo(port: 6379, pid: 4103, processName: "redis-server", bindAddress: "127.0.0.1", memoryBytes: 12_000_000),
            PortInfo(port: 8080, pid: 4104, processName: "com.docker.backend", docker: DockerInfo(containerId: "abc", name: "api", image: "api:dev", ports: "0.0.0.0:8080->80/tcp", publishedPort: 8080)),
        ]
        ports.hasLoadedOnce = true
        let popover = NSSize(width: StatusItemController.popoverWidth, height: 300)
        for dark in [true, false] {
            AppListViewModel.shared.selectTab(.ports)
            try await snapshot(MainPopoverView(), size: popover, name: "popover-ports", dark: dark)
            AppListViewModel.shared.selectTab(.apps)
            try await snapshot(MainPopoverView(), size: popover, name: "popover-apps", dark: dark)
            try await snapshot(PortsTabView(), size: NSSize(width: SettingsTab.contentWidth, height: 520), name: "settings-ports", dark: dark)
            try await snapshot(ExcludePortPickerView(onClose: {}), size: NSSize(width: 500, height: 540), name: "exclude-ports", dark: dark)
            UserDefaults.standard.set(ExcludeSection.ports.rawValue, forKey: ExcludeSection.defaultsKey)
            try await snapshot(ExcludeTabView(), size: NSSize(width: SettingsTab.contentWidth, height: ExcludeTabView.contentHeight), name: "settings-exclude-ports", dark: dark)
            let navigation = SettingsNavigationModel()
            for tab in SettingsTab.allCases {
                navigation.select(tab)
                try await snapshot(SettingsRootView(navigation: navigation), size: SettingsTab.windowSize, name: "settings-window-\(tab.rawValue.lowercased())", dark: dark)
            }
        }
        #expect(ports.hasLoadedOnce)
    }
}
