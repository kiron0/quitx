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

        #expect(sm.setKeys(activateKeys, for: .quitAll) == false)
        #expect(sm.shortcutError != nil)

        #expect(sm.setKeys([], for: .activateMenu) == true)
        #expect(sm.setKeys(activateKeys, for: .quitAll) == true)
        #expect(sm.shortcutError == nil)
        #expect(sm.quitAllKeys == activateKeys)
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
        #expect(sm.openSettingsEnabled == false)
        #expect(sm.openSettingsKeys.isEmpty)
        #expect(sm.refreshAppsEnabled == false)
        #expect(sm.refreshAppsKeys.isEmpty)
        #expect(sm.openHelpEnabled == false)
        #expect(sm.openHelpKeys.isEmpty)
        #expect(sm.openChangelogEnabled == false)
        #expect(sm.openChangelogKeys.isEmpty)
        #expect(sm.openUninstallerEnabled == false)
        #expect(sm.openUninstallerKeys.isEmpty)
        #expect(sm.shortcutError == nil)
    }

    @Test("Every Shortcut Slot Has A Unique Hot Key Identity")
    func testShortcutHotKeyIdentitiesAreUnique() {
        let ids = ShortcutManager.Slot.allCases.map(\.hotKeyId)
        #expect(Set(ids).count == ids.count)
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

        let foreground = AppInfo(name: "Finder", bundleId: QuitXConstants.SystemBundleIds.finder, pid: 42)
        #expect(foreground.id == "42-\(QuitXConstants.SystemBundleIds.finder)")
    }
}
