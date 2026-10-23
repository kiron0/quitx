import Foundation
import IOKit.ps
import Testing
@testable import QuitX

@Suite("Uninstaller")
struct UninstallerTests {
    private let bid = "com.example.coolapp"

    private func target(_ bundleURL: URL = URL(fileURLWithPath: "/Applications/Cool App.app")) -> UninstallTarget {
        UninstallTarget(name: "Cool App", bundleIdentifier: bid, bundleURL: bundleURL, executableName: "CoolApp")
    }

    @Test("System, Apple, nested and QuitX bundles can't be uninstalled")
    func eligibility() {
        #expect(AppUninstaller.canUninstall(bundleIdentifier: bid, bundleURL: URL(fileURLWithPath: "/Applications/Cool App.app")))
        #expect(AppUninstaller.canUninstall(bundleIdentifier: bid, bundleURL: URL(fileURLWithPath: "/Users/me/Applications/Cool App.app")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: "com.apple.Safari", bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: "com.example.x", bundleURL: URL(fileURLWithPath: "/System/Applications/X.app")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: "com.example.helper", bundleURL: URL(fileURLWithPath: "/Applications/Cool App.app/Contents/Helpers/Helper.app")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: bid, bundleURL: URL(fileURLWithPath: "/usr/local/bin/coolapp")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: nil, bundleURL: URL(fileURLWithPath: "/Applications/Cool App.app")))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: bid, bundleURL: nil))
        #expect(!AppUninstaller.canUninstall(bundleIdentifier: bid, bundleURL: URL(fileURLWithPath: "/private/var/folders/x/T/AppTranslocation/ABC/d/Cool App.app")))
        if let quitx = QuitXConstants.supportedBundleIdentifiers.first {
            #expect(!AppUninstaller.canUninstall(bundleIdentifier: quitx, bundleURL: URL(fileURLWithPath: "/Applications/QuitX.app")))
        }
    }

    @Test("Name matching skips short and generic names")
    func matchNames() {
        #expect(AppUninstaller.matchNames(for: target()) == ["coolapp"])
        let generic = UninstallTarget(name: "Notes", bundleIdentifier: "com.example.notes", bundleURL: URL(fileURLWithPath: "/Applications/Notes.app"), executableName: "App")
        #expect(AppUninstaller.matchNames(for: generic).isEmpty)
        let short = UninstallTarget(name: "Zed", bundleIdentifier: "dev.zed.Zed", bundleURL: URL(fileURLWithPath: "/Applications/Zed.app"), executableName: "zed")
        #expect(AppUninstaller.matchNames(for: short).isEmpty)
    }

    @Test("Entry matching follows each root's rule")
    func entryMatching() {
        let names: Set<String> = ["coolapp"]
        #expect(AppUninstaller.matches(fileName: "com.example.coolapp.plist", rule: .bundleOnly, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "com.example.coolapp.helper.plist", rule: .bundleOnly, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "com.example.coolapp.savedState", rule: .bundleOnly, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "com.example.coolappsync.plist", rule: .bundleOnly, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "Cool App", rule: .bundleOnly, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "Cool App", rule: .bundleOrName, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "CoolApp", rule: .bundleOrName, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "CoolAppPro", rule: .bundleOrName, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "ABCDE12345.com.example.coolapp", rule: .groupContainer, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "group.com.example.coolapp.shared", rule: .groupContainer, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "group.com.example.other", rule: .groupContainer, bundleIdentifier: bid, names: names))
        #expect(AppUninstaller.matches(fileName: "CoolApp-2026-10-01-101010.ips", rule: .diagnosticReport, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "CoolAppPro-2026-10-01-101010.ips", rule: .diagnosticReport, bundleIdentifier: bid, names: names))
        #expect(!AppUninstaller.matches(fileName: "anything", rule: .bundleOrName, bundleIdentifier: "x", names: names))
    }

    @Test("Never searches Documents, Desktop or the home folder itself")
    func searchRootsStayInLibrary() {
        let home = URL(fileURLWithPath: "/Users/me")
        let roots = AppUninstaller.searchRoots(home: home, temporaryDirectory: URL(fileURLWithPath: "/private/var/folders/x/T"))
        for root in roots {
            #expect(root.url.path != home.path)
            #expect(!root.url.path.hasPrefix("/Users/me/Documents"))
            #expect(!root.url.path.hasPrefix("/Users/me/Desktop"))
            #expect(!root.url.path.hasPrefix("/Users/me/Downloads"))
        }
    }

    @Test("Scan finds leftovers in a fake home and sizes them")
    func scanFakeHome() async throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("quitx-uninstall-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: home) }
        let lib = home.appendingPathComponent("Library")
        let support = lib.appendingPathComponent("Application Support/Cool App")
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try Data(count: 10_000).write(to: support.appendingPathComponent("db.sqlite"))
        try fm.createDirectory(at: lib.appendingPathComponent("Preferences"), withIntermediateDirectories: true)
        try Data(count: 10).write(to: lib.appendingPathComponent("Preferences/com.example.coolapp.plist"))
        try Data(count: 10).write(to: lib.appendingPathComponent("Preferences/com.example.other.plist"))
        try fm.createDirectory(at: lib.appendingPathComponent("Caches/com.example.coolapp"), withIntermediateDirectories: true)
        try fm.createDirectory(at: home.appendingPathComponent("Documents/Cool App"), withIntermediateDirectories: true)
        let tmp = home.appendingPathComponent("tmp")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        let app = home.appendingPathComponent("Applications/Cool App.app")
        try fm.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)

        let items = await AppUninstaller.scan(target: target(app), home: home, temporaryDirectory: tmp)
        let names = Set(items.map(\.name))
        #expect(names.contains("Cool App.app"))
        #expect(names.contains("Cool App"))
        #expect(names.contains("com.example.coolapp.plist"))
        #expect(names.contains("com.example.coolapp"))
        #expect(!names.contains("com.example.other.plist"))
        #expect(!items.contains { $0.url.path.contains("/Documents/") })
        let supportItem = try #require(items.first { $0.name == "Cool App" })
        #expect(supportItem.category == .applicationSupport)
        #expect(supportItem.bytes >= 10_000)
        #expect(supportItem.fileCount == 1)
        #expect(supportItem.isDirectory)
        #expect(items.first { $0.name == "com.example.coolapp.plist" }?.category == .preferences)
    }

    @Test("Admin trash command quotes paths")
    func adminCommandQuoting() {
        let command = AppUninstaller.adminTrashCommand(
            for: [URL(fileURLWithPath: "/Library/Application Support/It's Cool")],
            trash: URL(fileURLWithPath: "/Users/me/.Trash"),
            stamp: "10.00.00"
        )
        #expect(command == "/bin/mv -f '/Library/Application Support/It'\\''s Cool' '/Users/me/.Trash/It'\\''s Cool 10.00.00'")
        let app = AppUninstaller.adminTrashCommand(
            for: [URL(fileURLWithPath: "/Applications/Cool App.app")],
            trash: URL(fileURLWithPath: "/Users/me/.Trash"),
            stamp: "10.00.00"
        )
        #expect(app == "/bin/mv -f '/Applications/Cool App.app' '/Users/me/.Trash/Cool App 10.00.00.app'")
    }
}

@Suite("Hardware capabilities")
struct HardwareCapabilitiesTests {
    @Test("Battery detection reads the internal battery type")
    func batteryDetection() {
        let typeKey = kIOPSTypeKey as String
        #expect(HardwareCapabilities.hasInternalBattery(descriptions: [[typeKey: kIOPSInternalBatteryType as String]]))
        #expect(!HardwareCapabilities.hasInternalBattery(descriptions: [[typeKey: "UPS"]]))
        #expect(!HardwareCapabilities.hasInternalBattery(descriptions: []))
    }

    @Test("Config hides battery and GPU options the Mac doesn't have")
    func hardwareAdjusted() {
        var config = QuitXConfig.default
        config.showMenuBarStats = true
        config.menuBarShowCpu = false
        config.menuBarShowMemory = false
        config.menuBarShowGpu = false
        config.batteryMenuBarEnabled = true
        config.batterySaverEnabled = true
        #expect(config.menuBarStatsEnabled(hasBattery: true, hasGpu: true))
        #expect(!config.menuBarStatsEnabled(hasBattery: false, hasGpu: true))
        let desktop = config.adjustedForHardware(hasBattery: false, hasGpu: false)
        #expect(!desktop.batteryMenuBarEnabled)
        #expect(!desktop.batterySaverEnabled)
        let laptop = config.adjustedForHardware(hasBattery: true, hasGpu: true)
        #expect(laptop.batteryMenuBarEnabled)
        #expect(laptop.batterySaverEnabled)
    }
}
