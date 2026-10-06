import Testing
import Foundation
@testable import QuitX

@Suite("Shortcut Conflict and Identity Tests")
@MainActor
struct ShortcutIdentityTests {

    @Test("Duplicate Shortcut Detection Across Enabled Slots")
    func testShortcutConflicts() {
        let sm = ShortcutManager.shared
        sm.resetToDefaults()
        defer { sm.resetToDefaults() }

        let activateKeys = ShortcutManager.defaultActivateMenuKeys

        #expect(sm.conflicts(keys: activateKeys, excluding: .activateMenu) == false)
        #expect(sm.conflicts(keys: activateKeys, excluding: .quitAll) == true)
        #expect(sm.conflicts(keys: [], excluding: .quitAll) == false)

        #expect(sm.setKeys(activateKeys, for: .quitAll) == false)
        #expect(sm.shortcutError != nil)

        #expect(sm.setKeys([], for: .quitAll) == true)
        #expect(sm.shortcutError == nil)
        #expect(sm.quitAllKeys.isEmpty)

        #expect(sm.setKeys(activateKeys, for: .quitAll) == true)
        #expect(sm.shortcutError == nil)
        sm.resetToDefaults()
    }

    @Test("Shortcut Defaults Are Restored By Reset")
    func testShortcutResetToDefaults() {
        let sm = ShortcutManager.shared
        sm.activateMenuEnabled = false
        sm.quitAllEnabled = true
        sm.quitAllKeys = ["F13"]

        sm.resetToDefaults()

        #expect(sm.activateMenuEnabled == ShortcutManager.defaultActivateMenuEnabled)
        #expect(sm.activateMenuKeys == ShortcutManager.defaultActivateMenuKeys)
        #expect(sm.quitAllEnabled == ShortcutManager.defaultQuitAllEnabled)
        #expect(sm.quitAllKeys == ShortcutManager.defaultQuitAllKeys)
        #expect(sm.forceQuitAllEnabled == ShortcutManager.defaultForceQuitAllEnabled)
        #expect(sm.forceQuitAllKeys == ShortcutManager.defaultForceQuitAllKeys)
        #expect(sm.shortcutError == nil)
    }

    @Test("Background Group App IDs Stay Stable Across Refreshes")
    func testStableBackgroundIdentity() {
        let explicit = AppInfo(
            id: "background:com.apple.WebKit.WebContent",
            name: "Safari Web Content",
            pid: 101,
            pids: [101, 102],
            isBackground: true
        )
        #expect(explicit.id == "background:com.apple.WebKit.WebContent")

        let unchanged = AppInfo(id: explicit.id, name: explicit.name, pid: explicit.pid, pids: explicit.pids, isBackground: true)
        #expect(unchanged.id == explicit.id)

        let foreground = AppInfo(name: "Finder", bundleId: "com.apple.finder", pid: 42)
        #expect(foreground.id == "42-com.apple.finder")
    }
}
