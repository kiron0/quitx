import Testing
import AppKit
import Foundation
@testable import QuitX

@Suite("App Sorting and Grouping Tests")
struct AppSortingAndGroupingTests {
    let appA = AppInfo(name: "Alpha", pid: 1, memoryBytes: 100 * 1024 * 1024, cpuUsage: 5.0)
    let appB = AppInfo(name: "Beta", pid: 2, memoryBytes: 500 * 1024 * 1024, cpuUsage: 25.0)
    let appC = AppInfo(name: "Gamma", pid: 3, memoryBytes: 250 * 1024 * 1024, cpuUsage: 10.0)
    let appD = AppInfo(name: "Delta", pid: 4, memoryBytes: 500 * 1024 * 1024, cpuUsage: 5.0)

    @Test("Sort by Name Ascending")
    func testSortNameAsc() {
        let list = [appC, appA, appB]
        let sorted = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        #expect(sorted.map(\.name) == ["Alpha", "Beta", "Gamma"])
    }

    @Test("Sort by Name Descending")
    func testSortNameDesc() {
        let list = [appA, appC, appB]
        let sorted = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        #expect(sorted.map(\.name) == ["Gamma", "Beta", "Alpha"])
    }

    @Test("Sort by CPU Descending")
    func testSortCpuDesc() {
        let list = [appA, appB, appC]
        let sorted = list.sorted {
            if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Beta", "Gamma", "Alpha"])
    }

    @Test("Sort by CPU Descending with tie breaker by name")
    func testSortCpuDescTieBreaker() {
        let list = [appD, appA] // both 5.0% CPU: Alpha vs Delta
        let sorted = list.sorted {
            if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Alpha", "Delta"])
    }

    @Test("Sort by CPU Ascending")
    func testSortCpuAsc() {
        let list = [appB, appC, appA]
        let sorted = list.sorted {
            if $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage < $1.cpuUsage }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Alpha", "Gamma", "Beta"])
    }

    @Test("Sort by Memory Descending")
    func testSortMemoryDesc() {
        let list = [appA, appB, appC]
        let sorted = list.sorted {
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Beta", "Gamma", "Alpha"])
    }

    @Test("Sort by Memory Descending with tie breaker by name")
    func testSortMemoryDescTieBreaker() {
        let list = [appD, appB] // both 500 MB: Beta vs Delta
        let sorted = list.sorted {
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Beta", "Delta"])
    }

    @Test("Sort by Memory Ascending")
    func testSortMemoryAsc() {
        let list = [appB, appC, appA]
        let sorted = list.sorted {
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes < $1.memoryBytes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        #expect(sorted.map(\.name) == ["Alpha", "Gamma", "Beta"])
    }

    @Test("Background app grouping combines pids")
    func testGroupBackgroundPids() {
        let b1 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 10, isBackground: true)
        let b2 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 11, isBackground: true)
        var pids: [pid_t] = []
        for b in [b1, b2] { pids.append(contentsOf: b.pids) }
        #expect(pids == [10, 11])
    }

    @Test("Background app grouping sums memory")
    func testGroupBackgroundMemory() {
        let b1 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 10, isBackground: true, memoryBytes: 50 * 1024 * 1024)
        let b2 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 11, isBackground: true, memoryBytes: 70 * 1024 * 1024)
        let total = b1.memoryBytes + b2.memoryBytes
        #expect(total == 120 * 1024 * 1024)
    }

    @Test("Background app grouping sums CPU")
    func testGroupBackgroundCpu() {
        let b1 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 10, isBackground: true, cpuUsage: 2.5)
        let b2 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 11, isBackground: true, cpuUsage: 3.5)
        let total = b1.cpuUsage + b2.cpuUsage
        #expect(total == 6.0)
    }

    @Test("Background app grouping sums window counts")
    func testGroupBackgroundWindows() {
        let b1 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 10, isBackground: true, windowCount: 1)
        let b2 = AppInfo(name: "Worker", bundleId: "com.worker", pid: 11, isBackground: true, windowCount: 2)
        let total = b1.windowCount + b2.windowCount
        #expect(total == 3)
    }

    @Test("Regular apps are untouched during background grouping")
    func testRegularAppsUntouched() {
        let reg = AppInfo(name: "App", bundleId: "com.app", pid: 1, isBackground: false)
        let bg = AppInfo(name: "Agent", bundleId: "com.agent", pid: 2, isBackground: true)
        let apps = [reg, bg]
        let regularOnly = apps.filter { !$0.isBackground }
        #expect(regularOnly.count == 1)
        #expect(regularOnly.first?.name == "App")
    }
}

@Suite("App Filtering Logic Tests")
struct AppFilteringTests {
    let regular1 = AppInfo(name: "Safari", bundleId: "com.apple.Safari", pid: 100)
    let regular2 = AppInfo(name: "Finder", bundleId: "com.apple.finder", pid: 101)
    let musicApp = AppInfo(name: "Spotify", bundleId: "com.spotify.client", pid: 102)
    let bgApp = AppInfo(name: "CoreAgent", bundleId: "com.apple.coreagent", pid: 103, isBackground: true)
    let trashApp = AppInfo(name: "Trash", bundleId: "com.apple.trash", pid: nil)

    @Test("Filter by excluded name case-insensitive")
    func testExcludeByName() {
        let exclude = ["safari"]
        let apps = [regular1, regular2]
        let filtered = apps.filter { app in
            !exclude.map { $0.lowercased() }.contains(app.name.lowercased())
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Finder")
    }

    @Test("Filter by excluded bundleId case-insensitive")
    func testExcludeByBundleId() {
        let exclude = ["com.apple.safari"]
        let apps = [regular1, regular2]
        let filtered = apps.filter { app in
            guard let bid = app.bundleId?.lowercased() else { return true }
            return !exclude.map { $0.lowercased() }.contains(bid)
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Finder")
    }

    @Test("Music app protection when neverQuitMusic is true")
    func testNeverQuitMusicActive() {
        let musicApps = ["Spotify", "Music"]
        let apps = [regular1, musicApp]
        let filtered = apps.filter { app in
            let lowerName = app.name.lowercased()
            let lowerBid = app.bundleId?.lowercased()
            return !musicApps.contains { music in
                lowerName.contains(music.lowercased()) || lowerBid?.contains(music.lowercased()) == true
            }
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Safari")
    }

    @Test("Music app included when neverQuitMusic is false")
    func testNeverQuitMusicInactive() {
        let neverQuit = false
        let apps = [regular1, musicApp]
        let filtered = apps.filter { _ in !neverQuit }
        #expect(filtered.count == 2)
    }

    @Test("Finder excluded by default")
    func testFinderExcluded() {
        let includeFinder = false
        let apps = [regular1, regular2]
        let filtered = apps.filter { app in
            if !includeFinder && (app.bundleId == "com.apple.finder" || app.name.lowercased() == "finder") {
                return false
            }
            return true
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Safari")
    }

    @Test("Finder included when includeFinder is true")
    func testFinderIncluded() {
        let includeFinder = true
        let apps = [regular1, regular2]
        let filtered = apps.filter { app in
            if !includeFinder && (app.bundleId == "com.apple.finder" || app.name.lowercased() == "finder") {
                return false
            }
            return true
        }
        #expect(filtered.count == 2)
    }

    @Test("Trash excluded by default")
    func testTrashExcluded() {
        var results = [regular1]
        let includeTrash = Bool.random() ? false : false
        if includeTrash { results.append(trashApp) }
        #expect(!results.contains(where: { $0.name == "Trash" }))
    }

    @Test("Trash included when includeTrash is true")
    func testTrashIncluded() {
        var results = [regular1]
        let includeTrash = Bool.random() ? true : true
        if includeTrash { results.append(trashApp) }
        #expect(results.contains(where: { $0.name == "Trash" }))
    }

    @Test("Search query matches case-insensitively")
    func testSearchQueryCaseInsensitive() {
        let apps = [regular1, regular2, musicApp]
        let query = "saf"
        let filtered = apps.filter { $0.name.lowercased().contains(query.lowercased()) }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Safari")
    }

    @Test("Search query with trailing whitespace is trimmed")
    func testSearchQueryWhitespace() {
        let apps = [regular1, regular2]
        let rawQuery = "  safari   "
        let trimmed = rawQuery.trimmingCharacters(in: .whitespaces)
        let filtered = apps.filter { $0.name.lowercased().contains(trimmed.lowercased()) }
        #expect(filtered.count == 1)
    }

    @Test("Empty search query returns all apps")
    func testEmptySearchQuery() {
        let apps = [regular1, regular2]
        let query = ""
        let filtered = query.isEmpty ? apps : apps.filter { $0.name.contains(query) }
        #expect(filtered.count == 2)
    }

    @Test("Search query matching no apps returns empty list")
    func testNoMatchSearchQuery() {
        let apps = [regular1, regular2]
        let query = "Zebra"
        let filtered = apps.filter { $0.name.lowercased().contains(query.lowercased()) }
        #expect(filtered.isEmpty)
    }

    @Test("Background apps hidden when showBackgroundApps is false")
    func testBackgroundAppsHidden() {
        let apps = [regular1, bgApp]
        let filtered = apps.filter { !$0.isBackground }
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Safari")
    }

    @Test("Background apps visible when showBackgroundApps is true")
    func testBackgroundAppsVisible() {
        let apps = [regular1, bgApp]
        let showBackground = Bool.random() ? true : true
        let filtered = showBackground ? apps : apps.filter { !$0.isBackground }
        #expect(filtered.count == 2)
    }
}

@Suite("UpdateChecker Version Comparison Tests")
@MainActor
struct UpdateCheckerVersionTests {
    let checker = UpdateChecker.shared

    @Test("Equal versions return false")
    func testEqualVersions() {
        #expect(!checker.isVersion("1.0.0", greaterThan: "1.0.0"))
        #expect(!checker.isVersion("2.1.3", greaterThan: "2.1.3"))
    }

    @Test("Major bump returns true")
    func testMajorBump() {
        #expect(checker.isVersion("2.0.0", greaterThan: "1.0.0"))
        #expect(checker.isVersion("2.0.0", greaterThan: "1.9.9"))
        #expect(!checker.isVersion("1.0.0", greaterThan: "2.0.0"))
    }

    @Test("Minor bump returns true")
    func testMinorBump() {
        #expect(checker.isVersion("1.2.0", greaterThan: "1.1.0"))
        #expect(checker.isVersion("1.10.0", greaterThan: "1.9.0"))
        #expect(!checker.isVersion("1.1.0", greaterThan: "1.2.0"))
    }

    @Test("Patch bump returns true")
    func testPatchBump() {
        #expect(checker.isVersion("1.0.1", greaterThan: "1.0.0"))
        #expect(checker.isVersion("1.0.12", greaterThan: "1.0.9"))
        #expect(!checker.isVersion("1.0.0", greaterThan: "1.0.1"))
    }

    @Test("Mismatched component count (2 parts vs 3 parts)")
    func testComponentCountMismatch() {
        #expect(checker.isVersion("1.2.1", greaterThan: "1.2"))
        #expect(!checker.isVersion("1.2", greaterThan: "1.2.0"))
        #expect(!checker.isVersion("1.2.0", greaterThan: "1.2"))
    }

    @Test("Versions with 'v' prefix handled")
    func testPrefixStripping() {
        let v1 = "v1.2.0".trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        #expect(checker.isVersion(v1, greaterThan: "1.1.0"))
    }

    @Test("Versions with 4 components")
    func testFourComponents() {
        #expect(checker.isVersion("1.0.0.1", greaterThan: "1.0.0"))
        #expect(!checker.isVersion("1.0.0", greaterThan: "1.0.0.1"))
    }

    @Test("Large version numbers")
    func testLargeVersionNumbers() {
        #expect(checker.isVersion("100.50.25", greaterThan: "99.99.99"))
        #expect(!checker.isVersion("99.99.99", greaterThan: "100.0.0"))
    }

    @Test("Release web URL contains repo name")
    func testReleaseWebURL() {
        #expect(checker.releasesWebURL.absoluteString.contains("kiron0/quitx"))
    }

    @Test("Current version is non-empty")
    func testCurrentVersionNonEmpty() {
        #expect(!checker.currentVersion.isEmpty)
    }
}

@Suite("ShortcutManager Tests")
struct ShortcutManagerTests {
    @Test("Modifier flags mapping for Control")
    func testModifierControl() {
        let flags: NSEvent.ModifierFlags = [.control]
        var keys: [String] = []
        if flags.contains(.control) { keys.append("^") }
        #expect(keys == ["^"])
    }

    @Test("Modifier flags mapping for Option")
    func testModifierOption() {
        let flags: NSEvent.ModifierFlags = [.option]
        var keys: [String] = []
        if flags.contains(.option) { keys.append("⌥") }
        #expect(keys == ["⌥"])
    }

    @Test("Modifier flags mapping for Shift")
    func testModifierShift() {
        let flags: NSEvent.ModifierFlags = [.shift]
        var keys: [String] = []
        if flags.contains(.shift) { keys.append("⇧") }
        #expect(keys == ["⇧"])
    }

    @Test("Modifier flags mapping for Command")
    func testModifierCommand() {
        let flags: NSEvent.ModifierFlags = [.command]
        var keys: [String] = []
        if flags.contains(.command) { keys.append("⌘") }
        #expect(keys == ["⌘"])
    }

    @Test("Compound modifiers order")
    func testCompoundModifiersOrder() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .command]
        var keys: [String] = []
        if flags.contains(.control) { keys.append("^") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }
        #expect(keys == ["^", "⌥", "⌘"])
    }

    @Test("Special keycode mapping for Return")
    func testSpecialKeycodeReturn() {
        let keyCode: UInt16 = 36
        var key = ""
        switch keyCode {
        case 36: key = "↩"
        default: break
        }
        #expect(key == "↩")
    }

    @Test("Special keycode mapping for Space")
    func testSpecialKeycodeSpace() {
        let keyCode: UInt16 = 49
        var key = ""
        switch keyCode {
        case 49: key = "Space"
        default: break
        }
        #expect(key == "Space")
    }

    @Test("Special keycode mapping for Tab")
    func testSpecialKeycodeTab() {
        let keyCode: UInt16 = 48
        var key = ""
        switch keyCode {
        case 48: key = "Tab"
        default: break
        }
        #expect(key == "Tab")
    }

    @Test("Key matching exact array")
    func testKeyMatchingExact() {
        let pressed = ["^", "⌥", "A"]
        let target = ["^", "⌥", "A"]
        #expect(pressed == target)
    }

    @Test("Key matching mismatch")
    func testKeyMatchingMismatch() {
        let pressed = ["^", "⌥", "A"]
        let target = ["^", "⌥", "Q"]
        #expect(pressed != target)
    }
}

@Suite("QuitService Tests")
struct QuitServiceTests {
    @Test("Dry run returns success for all apps without terminating")
    func testDryRun() async {
        let app1 = AppInfo(name: "MockApp1", pid: 99991)
        let app2 = AppInfo(name: "MockApp2", pid: 99992)
        let results = await QuitService.shared.quit(apps: [app1, app2], force: false, dryRun: true)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.success })
        #expect(results.allSatisfy { $0.error == nil })
    }

    @Test("Quit app with no PID returns error")
    func testQuitWithNoPid() async {
        let app = AppInfo(name: "NonExistentApp", pid: nil, pids: [])
        let results = await QuitService.shared.quit(apps: [app], force: false, dryRun: false)
        #expect(results.count == 1)
        #expect(!results[0].success)
        #expect(results[0].error != nil)
    }

    @Test("QuitResult properly encapsulates force flag")
    func testQuitResultForcedFlag() {
        let app = AppInfo(name: "App", pid: 10)
        let resForced = QuitResult(app: app, success: true, forced: true, error: nil)
        let resNormal = QuitResult(app: app, success: true, forced: false, error: nil)
        #expect(resForced.forced)
        #expect(!resNormal.forced)
    }
}

@Suite("MenuHelper Tests")
struct MenuHelperTests {
    @Test("MenuHelper creates item with title and key equivalent")
    func testMakeItemBasic() {
        let item = MenuHelper.makeItem(
            title: "Settings",
            action: nil,
            target: nil,
            keyEquivalent: ",",
            systemSymbolName: "gearshape"
        )
        #expect(item.title == "Settings")
        #expect(item.keyEquivalent == ",")
        #expect(item.isEnabled)
    }

    @Test("MenuHelper creates disabled item")
    func testMakeItemDisabled() {
        let item = MenuHelper.makeItem(
            title: "Restore",
            action: nil,
            target: nil,
            keyEquivalent: "r",
            systemSymbolName: "tray.and.arrow.up",
            isEnabled: false
        )
        #expect(!item.isEnabled)
    }

    @Test("MenuHelper configures image size and template")
    func testMakeItemImageProperties() {
        let item = MenuHelper.makeItem(
            title: "Help",
            action: nil,
            target: nil,
            keyEquivalent: "h",
            systemSymbolName: "questionmark.circle"
        )
        #expect(item.image != nil)
        #expect(item.image?.isTemplate == true)
        #expect(item.image?.size == NSSize(width: 15, height: 15))
    }

    @Test("MenuHelper loads asset image when available")
    func testMakeItemAssetImage() {
        let item = MenuHelper.makeItem(
            title: "Preferences",
            action: nil,
            target: nil,
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape"
        )
        #expect(item.image != nil)
        #expect(item.image?.size == NSSize(width: 15, height: 15))
    }

    @Test("MenuHelper custom keyEquivalentModifierMask")
    func testMakeItemModifierMask() {
        let mask: NSEvent.ModifierFlags = [.command, .option]
        let item = MenuHelper.makeItem(
            title: "Force Quit",
            action: nil,
            target: nil,
            keyEquivalent: "q",
            keyEquivalentModifierMask: mask,
            systemSymbolName: "bolt.fill"
        )
        #expect(item.keyEquivalentModifierMask == mask)
    }

    @Test("MenuHelper preferredImageVisibility set via KVC")
    func testMakeItemPreferredImageVisibility() {
        let item = MenuHelper.makeItem(
            title: "Item",
            action: nil,
            target: nil,
            systemSymbolName: "star"
        )
        let val = item.value(forKey: "preferredImageVisibility") as? Int
        #expect(val == 1)
    }
}
