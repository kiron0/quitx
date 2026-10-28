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

    private static func wave(base: Double, amplitude: Double, period: Double, step: Double) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(90)
        for index in 0..<90 {
            let position = Double(index)
            let swing: Double = amplitude * sin(position / period)
            let ripple: Double = step * Double(index % 7)
            values.append(base + swing + ripple)
        }
        return values
    }

    @Test("Render every stats window mode for marketing mockups")
    func renderStatsPanels() async throws {
        guard Self.snapshotDirectory != nil else { return }
        _ = NSApplication.shared
        let store = ConfigStore.shared
        let saved = store.config
        defer { store.config = saved }
        store.config.liquidGlassEnabled = false
        store.config.batteryMenuBarEnabled = true
        let gib: UInt64 = 1_073_741_824
        let model = StatsDetailModel()
        model.cpu = 23
        model.systemPct = 8
        model.userPct = 15
        model.idlePct = 77
        model.perCore = [41, 33, 27, 19, 12, 9, 7, 5]
        model.cpuLevels = [
            SystemUsage.CpuLevel(index: 0, name: "Performance", logicalCores: 4),
            SystemUsage.CpuLevel(index: 1, name: "Efficiency", logicalCores: 4)
        ]
        model.load1 = 2.41
        model.uptime = "3 days, 4 hrs"
        model.cpuHistory = Self.wave(base: 18, amplitude: 9, period: 6, step: 1)
        model.memTotal = 8 * gib
        model.memApp = 3 * gib + gib / 4
        model.memWired = gib + gib / 5
        model.memCompressed = gib / 2
        model.memCached = 2 * gib
        model.memFree = gib / 3
        model.swapUsed = gib / 4
        model.memHistory = Self.wave(base: 62, amplitude: 4, period: 9, step: 0)
        model.gpu = GpuUsageService.Snapshot(
            deviceUtilization: 18,
            rendererUtilization: 15,
            tilerUtilization: 6,
            memoryUsedBytes: 820 * 1_048_576,
            allocatedBytes: 2 * gib,
            coreCount: 7,
            deviceName: "Apple M1",
            isAvailable: true
        )
        model.gpuHistory = Self.wave(base: 14, amplitude: 6, period: 5, step: 0)
        model.battery = BatterySnapshot(
            percent: 82,
            isCharging: false,
            isACPower: false,
            timeToEmptyMin: 237,
            timeToFullMin: nil,
            amperageMA: -1580,
            voltageMV: 11795,
            powerW: 18.6,
            tempC: 31.4,
            chargeMAh: 2886,
            designCapacityMAh: 4382,
            maxCapacityMAh: 3693,
            cycleCount: 223,
            condition: "Normal",
            healthPercent: 82,
            chargingLimitPercent: nil
        )
        for dark in [true, false] {
            for mode in StatsDetailModel.Mode.allCases {
                model.mode = mode
                let name = "stats-\(mode.rawValue.lowercased())"
                try await snapshot(StatsDetailView(model: model), size: NSSize(width: 270, height: 700), name: name, dark: dark)
                try await snapshot(StatsDetailView(model: model), size: NSSize(width: 270, height: 12 + model.contentHeight), name: name, dark: dark)
            }
        }
        #expect(model.contentHeight > 200)
    }

    @Test("Render full settings pages and the app list for marketing mockups")
    func renderPages() async throws {
        guard Self.snapshotDirectory != nil else { return }
        _ = NSApplication.shared
        let store = ConfigStore.shared
        let saved = store.config
        let savedApps = AppListViewModel.shared.apps
        defer {
            store.config = saved
            AppListViewModel.shared.apps = savedApps
        }
        store.config.liquidGlassEnabled = false
        store.config.portsEnabled = false
        store.config.showMenuBarStats = true
        store.config.menuBarShowCpu = true
        store.config.menuBarShowMemory = true
        store.config.quitOnSleep = true
        store.config.hogAlertEnabled = true
        AppListViewModel.shared.apps = [
            AppInfo(name: "Calendar", bundleId: "com.apple.iCal", pid: 9101, windowCount: 1, memoryBytes: 120_000_000, cpuUsage: 1),
            AppInfo(name: "Maps", bundleId: "com.apple.Maps", pid: 9102, windowCount: 1, memoryBytes: 210_000_000, cpuUsage: 2),
            AppInfo(name: "Messages", bundleId: "com.apple.MobileSMS", pid: 9103, windowCount: 1, memoryBytes: 140_000_000, cpuUsage: 1),
            AppInfo(name: "Music", bundleId: "com.apple.Music", pid: 9104, windowCount: 1, memoryBytes: 180_000_000, cpuUsage: 2),
            AppInfo(name: "Notes", bundleId: "com.apple.Notes", pid: 9105, windowCount: 1, memoryBytes: 90_000_000, cpuUsage: 0),
            AppInfo(name: "Safari", bundleId: "com.apple.Safari", pid: 9106, windowCount: 2, memoryBytes: 640_000_000, cpuUsage: 6),
        ]
        let pages: [(String, AnyView)] = [
            ("general", AnyView(GeneralTabView())),
            ("automation", AnyView(AutomationTabView())),
            ("advanced", AnyView(AdvancedTabView())),
            ("shortcuts", AnyView(ShortcutsTabView())),
            ("about", AnyView(AboutTabView())),
        ]
        for dark in [true, false] {
            try await snapshot(MainPopoverView(), size: NSSize(width: StatusItemController.popoverWidth, height: 340), name: "popover-apps-list", dark: dark)
            for (name, view) in pages {
                try await snapshot(VStack(spacing: 0) { view; Spacer(minLength: 0) }.padding(20).background(Color(NSColor.windowBackgroundColor)), size: NSSize(width: SettingsTab.contentWidth + 40, height: 1300), name: "page-\(name)", dark: dark)
            }
        }
        store.config.portsEnabled = true
        try await snapshot(VStack(spacing: 0) { PortsTabView(); Spacer(minLength: 0) }.padding(20).background(Color(NSColor.windowBackgroundColor)), size: NSSize(width: SettingsTab.contentWidth + 40, height: 1300), name: "page-ports", dark: true)
        #expect(!AppListViewModel.shared.apps.isEmpty)
    }
}
