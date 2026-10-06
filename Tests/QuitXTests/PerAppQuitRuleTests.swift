import Testing
import Foundation
@testable import QuitX

@Suite("Per-App Quit Rule Tests")
@MainActor
struct PerAppQuitRuleTests {

    @Test("Rule key prefers bundle ID over name")
    func testRuleKey() {
        #expect(PerAppQuitRule.ruleKey(bundleId: "com.example.App", name: "Example") == "com.example.app")
        #expect(PerAppQuitRule.ruleKey(bundleId: nil, name: "Example App") == "example app")
        #expect(PerAppQuitRule.ruleKey(bundleId: "", name: "Example App") == "example app")
        #expect(PerAppQuitRule.ruleKey(bundleId: "  com.example.App  ", name: "Example") == "com.example.app")
    }

    @Test("Stored rule lookup is case-insensitive with bundle priority")
    func testStoredMinutes() {
        let rules = ["com.example.app": 30, "helper tool": 60]

        #expect(PerAppQuitRule.storedMinutes(bundleId: "COM.EXAMPLE.APP", name: "Example", rules: rules) == 30)
        #expect(PerAppQuitRule.storedMinutes(bundleId: nil, name: "Helper Tool", rules: rules) == 60)
        #expect(PerAppQuitRule.storedMinutes(bundleId: "com.unknown.app", name: "Unknown", rules: rules) == nil)
        #expect(PerAppQuitRule.storedMinutes(bundleId: nil, name: "Unknown", rules: [:]) == nil)
    }

    @Test("Bundle ID wins over name on conflict")
    func testBundlePriority() {
        let rules = ["com.example.app": 30, "example": 90]
        #expect(PerAppQuitRule.storedMinutes(bundleId: "com.example.app", name: "Example", rules: rules) == 30)
    }

    @Test("Timeout falls back to global minutes")
    func testTimeoutFallback() {
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: "com.x.app", name: "X", rules: [:], globalMinutes: 45) == 45)
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: "com.x.app", name: "X", rules: ["com.x.app": 15], globalMinutes: 45) == 15)
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: "com.x.app", name: "X", rules: ["com.x.app": 0], globalMinutes: 45) == 0)
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: "com.x.app", name: "X", rules: [:], globalMinutes: 0) == 0)
    }

    @Test("Zero stored value means Never")
    func testNeverMeansZero() {
        #expect(PerAppQuitRule.neverMinutes == 0)
        #expect(PerAppQuitRule.timeoutMinutes(bundleId: nil, name: "Loud", rules: ["loud": 0], globalMinutes: 60) == 0)
    }

    @Test("Rules roundtrip through ConfigStore")
    func testConfigStoreRoundtrip() {
        let store = ConfigStore.shared
        let savedRules = store.config.perAppQuitRules

        store.setPerAppQuitRule(identifier: "  COM.Example.App  ", minutes: 30)
        #expect(store.perAppQuitMinutes(bundleId: "com.example.app", name: "Example") == 30)
        #expect(store.effectiveQuitTimeoutMinutes(bundleId: "com.example.app", name: "Example") == 30)

        store.setPerAppQuitRule(identifier: "helper tool", minutes: 0)
        #expect(store.perAppQuitMinutes(bundleId: nil, name: "Helper Tool") == 0)
        #expect(store.effectiveQuitTimeoutMinutes(bundleId: nil, name: "Helper Tool") == 0)

        store.setPerAppQuitRule(identifier: "helper tool", minutes: -5)
        #expect(store.perAppQuitMinutes(bundleId: nil, name: "Helper Tool") == 0)

        store.removePerAppQuitRule(identifier: "com.example.app")
        #expect(store.perAppQuitMinutes(bundleId: "com.example.app", name: "Example") == nil)

        store.removePerAppQuitRule(identifier: "helper tool")
        #expect(store.config.perAppQuitRules == savedRules)
    }

    @Test("Global fallback and presets hold")
    func testGlobalFallbackThroughStore() {
        let store = ConfigStore.shared
        let savedRules = store.config.perAppQuitRules
        let savedGlobal = store.config.quitInactiveAfterMinutes

        var restored = store.config
        restored.perAppQuitRules = [:]
        restored.quitInactiveAfterMinutes = 45
        store.config = restored

        #expect(store.effectiveQuitTimeoutMinutes(bundleId: "com.x.app", name: "X") == 45)
        #expect(PerAppQuitRule.presets.first?.minutes == nil)
        #expect(PerAppQuitRule.presets.contains(where: { $0.minutes == 0 }))

        var back = store.config
        back.perAppQuitRules = savedRules
        back.quitInactiveAfterMinutes = savedGlobal
        store.config = back
        store.save(immediate: true)
        #expect(store.config.perAppQuitRules == savedRules)
    }
}
