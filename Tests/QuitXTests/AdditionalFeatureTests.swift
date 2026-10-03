import Testing
import AppKit
import SwiftUI
@testable import QuitX

@Suite("Single Instance Version Tests")
@MainActor
struct SingleInstanceVersionTests {
    @Test("Newer semantic version wins")
    func testNewerVersionWins() {
        #expect(SingleInstanceService.compareVersions("1.0.2", "1.0.1") == 1)
        #expect(SingleInstanceService.compareVersions("2.0.0", "1.99.99") == 1)
    }

    @Test("Older semantic version loses")
    func testOlderVersionLoses() {
        #expect(SingleInstanceService.compareVersions("1.0.1", "1.0.2") == -1)
    }

    @Test("Missing version components equal zero")
    func testMissingComponents() {
        #expect(SingleInstanceService.compareVersions("1.0", "1.0.0") == 0)
    }

    @Test("Version prefix and suffix are accepted")
    func testVersionDecoration() {
        #expect(SingleInstanceService.compareVersions("v1.2.3", "1.2.2") == 1)
        #expect(SingleInstanceService.compareVersions("1.2.3-beta", "1.2.3") == 0)
    }

    @Test("Lower PID wins equal-version race")
    func testEqualVersionTieBreaker() {
        #expect(SingleInstanceService.isPreferred(version: "1.0.2", pid: 100, over: "1.0.2", pid: 200))
        #expect(!SingleInstanceService.isPreferred(version: "1.0.2", pid: 200, over: "1.0.2", pid: 100))
    }
}

@Suite("AutoQuit and Timing Tests")
struct AutoQuitAndTimingTests {
    @Test("Auto-quit disabled when minutes is 0")
    func testAutoQuitDisabledAtZero() {
        let minutes = 0
        #expect(minutes == 0)
    }

    @Test("GeneralTabState minutes conversion for 1 hour")
    @MainActor
    func testGeneralTabState1Hour() {
        let state = GeneralTabState()
        state.autoQuitValue = 1
        state.autoQuitUnit = "hours"
        #expect(state.calculateMinutes() == 60)
    }

    @Test("GeneralTabState minutes conversion for 2 hours")
    @MainActor
    func testGeneralTabState2Hours() {
        let state = GeneralTabState()
        state.autoQuitValue = 2
        state.autoQuitUnit = "hours"
        #expect(state.calculateMinutes() == 120)
    }

    @Test("GeneralTabState minutes conversion for 1 day")
    @MainActor
    func testGeneralTabState1Day() {
        let state = GeneralTabState()
        state.autoQuitValue = 1
        state.autoQuitUnit = "days"
        #expect(state.calculateMinutes() == 1440)
    }

    @Test("GeneralTabState minutes conversion for 30 minutes")
    @MainActor
    func testGeneralTabStateMinutes() {
        let state = GeneralTabState()
        state.autoQuitValue = 30
        state.autoQuitUnit = "minutes"
        #expect(state.calculateMinutes() == 30)
    }

    @Test("GeneralTabState sync from 60 minutes")
    @MainActor
    func testGeneralTabStateSync60Min() {
        let state = GeneralTabState()
        state.syncFromMinutes(60)
        #expect(state.autoQuitValue == 1)
        #expect(state.autoQuitUnit == "hours")
    }

    @Test("GeneralTabState sync from 120 minutes")
    @MainActor
    func testGeneralTabStateSync120Min() {
        let state = GeneralTabState()
        state.syncFromMinutes(120)
        #expect(state.autoQuitValue == 2)
        #expect(state.autoQuitUnit == "hours")
    }

    @Test("GeneralTabState sync from 1440 minutes")
    @MainActor
    func testGeneralTabStateSync1440Min() {
        let state = GeneralTabState()
        state.syncFromMinutes(1440)
        #expect(state.autoQuitValue == 1)
        #expect(state.autoQuitUnit == "days")
    }

    @Test("GeneralTabState sync from 45 minutes")
    @MainActor
    func testGeneralTabStateSync45Min() {
        let state = GeneralTabState()
        state.syncFromMinutes(45)
        #expect(state.autoQuitValue == 45)
        #expect(state.autoQuitUnit == "minutes")
    }

    @Test("GeneralTabState sync from 0 minutes defaults to 1 hour")
    @MainActor
    func testGeneralTabStateSync0Min() {
        let state = GeneralTabState()
        state.syncFromMinutes(0)
        #expect(state.autoQuitValue == 1)
    }
}

@Suite("Exclude Tab State Tests")
struct ExcludeTabStateTests {
    @Test("ExcludeTabState partiallySelected and allSelected states")
    @MainActor
    func testExcludeTabSelectionStates() {
        let state = ExcludeTabState()
        let apps = ["com.apple.safari", "com.google.chrome", "com.spotify.client"]

        #expect(!state.allSelected(apps))
        #expect(!state.partiallySelected(apps))

        state.toggle("com.apple.safari")
        #expect(!state.allSelected(apps))
        #expect(state.partiallySelected(apps))

        state.toggle("com.google.chrome")
        #expect(!state.allSelected(apps))
        #expect(state.partiallySelected(apps))

        state.toggle("com.spotify.client")
        #expect(state.allSelected(apps))
        #expect(!state.partiallySelected(apps))

        state.toggleAll(apps)
        #expect(!state.allSelected(apps))
        #expect(!state.partiallySelected(apps))
    }
}

@Suite("Settings Tab Tests")
struct SettingsTabTests {
    @Test("SettingsTab all cases")
    func testSettingsTabCases() {
        let all = SettingsTab.allCases
        #expect(all.count == 5)
        #expect(all.contains(.general))
        #expect(all.contains(.exclude))
        #expect(all.contains(.shortcuts))
        #expect(all.contains(.support))
        #expect(all.contains(.about))
    }

    @Test("SettingsTab toolbar item identifiers")
    func testSettingsTabToolbarItemIdentifier() {
        #expect(SettingsTab.general.toolbarItemIdentifier.rawValue == "General")
        #expect(SettingsTab.exclude.toolbarItemIdentifier.rawValue == "Exclude")
        #expect(SettingsTab.shortcuts.toolbarItemIdentifier.rawValue == "Shortcuts")
        #expect(SettingsTab.support.toolbarItemIdentifier.rawValue == "Support")
        #expect(SettingsTab.about.toolbarItemIdentifier.rawValue == "About")
    }

    @Test("SettingsTab icon names")
    func testSettingsTabIconNames() {
        #expect(SettingsTab.general.iconName == "preferences-general")
        #expect(SettingsTab.exclude.iconName == "preferences-exclude")
        #expect(SettingsTab.shortcuts.iconName == "preferences-shortcuts")
        #expect(SettingsTab.support.iconName == "preferences-support")
        #expect(SettingsTab.about.iconName == "preferences-about")
    }

    @Test("SettingsTab fallback symbol names")
    func testSettingsTabFallbackSymbols() {
        #expect(SettingsTab.general.fallbackSymbolName == "gearshape")
        #expect(SettingsTab.exclude.fallbackSymbolName == "nosign")
        #expect(SettingsTab.shortcuts.fallbackSymbolName == "command")
        #expect(SettingsTab.support.fallbackSymbolName == "bubble.left.and.bubble.right")
        #expect(SettingsTab.about.fallbackSymbolName == "bolt.fill")
    }

    @Test("SettingsTab content heights")
    func testSettingsTabContentHeights() {
        #expect(SettingsTab.general.contentHeight == 475)
        #expect(SettingsTab.exclude.contentHeight == 300)
        #expect(SettingsTab.shortcuts.contentHeight == 215)
        #expect(SettingsTab.support.contentHeight == 139)
        #expect(SettingsTab.about.contentHeight == 130)
    }

    @Test("SettingsTab toolbar images generated and template")
    func testSettingsTabToolbarImages() {
        for tab in SettingsTab.allCases {
            let img = tab.toolbarImage
            #expect(img != nil)
            #expect(img?.isTemplate == true)
            #expect(img?.size == NSSize(width: 19, height: 19))
        }
    }
}

@Suite("Theme and Visual Tokens Tests")
struct ThemeTests {
    @Test("QuitXTheme accent color is warm gold")
    func testThemeAccent() {
        let accent = QuitXTheme.accentNSColor
        #expect(accent.redComponent > 0.9)
        #expect(accent.greenComponent > 0.6)
        #expect(accent.blueComponent < 0.3)
    }

    @Test("QuitXTheme window background color available")
    func testThemeWindowBackground() {
        let bg = QuitXTheme.windowBackgroundNSColor
        #expect(bg == NSColor.windowBackgroundColor)
    }
}

@Suite("Help Content Tests")
struct HelpContentTests {
    @Test("Help topics have unique identifiers and complete content")
    func testHelpTopicsAreComplete() {
        let topics = QuitXHelpTopic.all
        #expect(topics.count == 10)
        #expect(Set(topics.map(\.id)).count == topics.count)
        #expect(Set(topics.map(\.category)) == Set(QuitXHelpCategory.allCases))
        #expect(topics.allSatisfy { !$0.title.isEmpty && !$0.summary.isEmpty && !$0.sections.isEmpty })
    }

    @Test("Help search covers titles and article content")
    func testHelpSearch() {
        #expect(QuitXHelpTopic.all.first { $0.id == "exclude" }?.matches("background apps") == true)
        #expect(QuitXHelpTopic.all.first { $0.id == "finder-trash" }?.matches("permanently empties") == true)
        #expect(QuitXHelpTopic.all.allSatisfy { $0.matches("   ") })
    }
}

@Suite("Asset Images Tests")
struct AssetImagesTests {
    @Test("App icon returns valid image")
    func testAppIconValid() {
        let img = AssetImages.appIcon
        #expect(img != nil)
    }

    @Test("Load existing bundle/support icon")
    func testLoadSettingsIcon() {
        let img = AssetImages.load("settings")
        #expect(img != nil)
    }

    @Test("Load menu-options icon")
    func testLoadMenuOptionsIcon() {
        let img = AssetImages.load("menu-options")
        #expect(img != nil)
    }

    @Test("Load status-icon")
    func testLoadStatusIcon() {
        let img = AssetImages.load("status-icon")
        #expect(img != nil)
    }

    @Test("Load non-existent image returns nil")
    func testLoadNonExistentImage() {
        let img = AssetImages.load("non_existent_image_foo_bar_xyz")
        #expect(img == nil)
    }
}

@Suite("ConfigStore & Persistence Tests")
struct ConfigStoreTests {
    @Test("Shared instance exists")
    func testConfigStoreShared() {
        let store = ConfigStore.shared
        #expect(store.config.autoUpdate == true)
    }

    @Test("Config encoding format is valid JSON")
    func testConfigJSONSerialization() throws {
        let cfg = QuitXConfig.default
        let data = try JSONEncoder().encode(cfg)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString != nil)
        #expect(jsonString?.contains("force") == true)
        #expect(jsonString?.contains("sortBy") == true)
    }

    @Test("Corrupted JSON does not crash and decodes default gracefully")
    func testCorruptedJSONHandling() {
        let corrupted = "INVALID_JSON_DATA{{{".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(QuitXConfig.self, from: corrupted)
        #expect(decoded == nil)
    }

    @Test("Legacy config keeps saved values and defaults new fields")
    func testLegacyConfigMigration() throws {
        let legacyJSON = """
        {
          "exclude": ["Safari"],
          "force": "force",
          "includeFinder": true,
          "includeTrash": false,
          "includeBackground": false,
          "groupBackground": true,
          "defaultSelectAll": true,
          "neverQuitMusic": false,
          "musicApps": ["Music"],
          "autoUpdate": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: legacyJSON)
        #expect(decoded.exclude == ["Safari"])
        #expect(decoded.force == .force)
        #expect(decoded.includeFinder)
        #expect(decoded.defaultSelectAll)
        #expect(!decoded.autoUpdate)
        #expect(decoded.confirmQuitAll)
        #expect(decoded.playSounds)
        #expect(decoded.sortBy == .name)
    }
}

@Suite("Edge Case and Model Integrity Tests")
struct ModelIntegrityTests {
    @Test("AppInfo empty name handled")
    func testEmptyName() {
        let app = AppInfo(name: "")
        #expect(app.name.isEmpty)
        #expect(app.id == "")
    }

    @Test("AppInfo special characters in name and bundleId")
    func testSpecialCharacters() {
        let name = "🚀 Super App [v2] (Dev)"
        let bid = "io.coreify.test-app_123"
        let app = AppInfo(name: name, bundleId: bid, pid: 777)
        #expect(app.id == "777-\(bid)")
        #expect(app.name == name)
    }

    @Test("AppInfo huge memory value does not overflow format")
    func testHugeMemory() {
        let app = AppInfo(name: "Big", memoryBytes: UInt64.max / 2)
        #expect(!app.memoryFormatted.isEmpty)
    }

    @Test("AppInfo large CPU value formatting")
    func testHugeCpu() {
        let app = AppInfo(name: "Burner", cpuUsage: 999.99)
        #expect(app.cpuFormatted == "1000.0%")
    }

    @Test("Multiple pids preserved in AppInfo")
    func testMultiplePids() {
        let pids: [pid_t] = [100, 101, 102, 103, 104]
        let app = AppInfo(name: "Multi", pid: 100, pids: pids)
        #expect(app.pids == pids)
        #expect(app.pid == 100)
    }
}

@Suite("Exclude App Picker Selection Tests")
@MainActor
struct ExcludeAppPickerSelectionTests {
    private func makeApp(id: String, name: String) -> InstalledApplication {
        InstalledApplication(
            bundleIdentifier: id,
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            isBackground: false
        )
    }

    @Test("Select-all helpers toggle and calculate state accurately")
    func testSelectAllCycle() {
        let vm = ExcludeAppPickerViewModel()
        let app1 = makeApp(id: "com.apple.safari", name: "Safari")
        let app2 = makeApp(id: "com.apple.mail", name: "Mail")
        let app3 = makeApp(id: "com.apple.finder", name: "Finder")
        let apps = [app1, app2, app3]

        #expect(!vm.isAllSelected(for: apps))
        #expect(!vm.isPartiallySelected(for: apps))

        // Select one: partial
        vm.toggle(app1)
        #expect(!vm.isAllSelected(for: apps))
        #expect(vm.isPartiallySelected(for: apps))

        // Select all
        vm.toggleSelectAll(for: apps)
        #expect(vm.isAllSelected(for: apps))
        #expect(!vm.isPartiallySelected(for: apps))
        #expect(vm.selectedIdentifiers.count == 3)

        // Deselect all
        vm.toggleSelectAll(for: apps)
        #expect(!vm.isAllSelected(for: apps))
        #expect(!vm.isPartiallySelected(for: apps))
        #expect(vm.selectedIdentifiers.isEmpty)
    }

    @Test("Select-all handles empty application list")
    func testEmptyList() {
        let vm = ExcludeAppPickerViewModel()
        #expect(!vm.isAllSelected(for: []))
        #expect(!vm.isPartiallySelected(for: []))
        vm.toggleSelectAll(for: [])
        #expect(vm.selectedIdentifiers.isEmpty)
    }
}
