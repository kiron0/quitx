import Foundation
import Testing

enum TestDefaults {
    static func discard(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        CFPreferencesAppSynchronize(suite as CFString)
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suite).plist")
        try? FileManager.default.removeItem(at: plist)
    }
}

@Suite("Test hygiene")
struct TestHygieneTests {
    @Test("Temporary preference suites leave no plist behind")
    func discardRemovesPlist() {
        let suite = "QuitXTests.hygiene.\(UUID().uuidString)"
        let plist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(suite).plist")
        let defaults = UserDefaults(suiteName: suite)
        defaults?.set(true, forKey: "flag")
        CFPreferencesAppSynchronize(suite as CFString)
        TestDefaults.discard(suite)
        #expect(!FileManager.default.fileExists(atPath: plist.path))
        #expect(UserDefaults(suiteName: suite)?.object(forKey: "flag") == nil)
    }
}
