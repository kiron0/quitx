import Foundation
import Testing
@testable import QuitX

@Suite("Cleanup and leftovers")
struct CleanupTests {
    @Test("Permanent removal safety blocks roots and system paths")
    func permanentRemovalSafety() {
        let home = URL(fileURLWithPath: "/Users/example")
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/"), home: home))
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Applications"), home: home))
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/System/Library/X"), home: home))
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Users/example"), home: home))
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Users/example/Library"), home: home))
        #expect(AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Applications/Example.app"), home: home))
        #expect(AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Users/example/Library/Caches/com.example.app"), home: home))
    }

    @Test("Permanent admin command quotes every path")
    func permanentCommand() {
        let command = AppUninstaller.adminPermanentRemovalCommand(for: [
            URL(fileURLWithPath: "/Applications/It's Cool.app"),
            URL(fileURLWithPath: "/Users/me/Library/Caches/cool app")
        ])
        #expect(command == "/bin/rm -rf -- '/Applications/It'\\''s Cool.app' '/Users/me/Library/Caches/cool app'")
    }

    @Test("Permanent removal deletes only the requested temporary item")
    func permanentRemoval() async throws {
        let fileManager = FileManager.default
        let parent = fileManager.temporaryDirectory.appendingPathComponent("quitx-purge-\(UUID().uuidString)")
        let target = parent.appendingPathComponent("target")
        let sibling = parent.appendingPathComponent("keep")
        defer { try? fileManager.removeItem(at: parent) }
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        try Data("delete".utf8).write(to: target.appendingPathComponent("data"))
        try Data("keep".utf8).write(to: sibling)

        let result = await AppUninstaller.removePermanently([target])

        #expect(result.failed.isEmpty)
        #expect(!fileManager.fileExists(atPath: target.path))
        #expect(fileManager.fileExists(atPath: sibling.path))
    }

    @Test("Cleanup scanners stay in their category roots")
    func categoryScanning() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent("quitx-cleanup-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: home) }
        let cache = home.appendingPathComponent("Library/Caches/com.example.cache")
        let npm = home.appendingPathComponent("Library/Caches/npm")
        try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: npm, withIntermediateDirectories: true)
        try Data(count: 4_096).write(to: cache.appendingPathComponent("blob"))
        try Data(count: 2_048).write(to: npm.appendingPathComponent("blob"))

        let user = CleanupService.scanSynchronously(.userCache, home: home, now: Date())
        let node = CleanupService.scanSynchronously(.nodeCache, home: home, now: Date())

        #expect(user.map(\.name) == ["com.example.cache"])
        #expect(node.contains { $0.url == npm.standardizedFileURL })
    }

    @Test("Large file scan never preselects personal files")
    func largeFiles() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent("quitx-large-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: home) }
        let downloads = home.appendingPathComponent("Downloads")
        try fileManager.createDirectory(at: downloads, withIntermediateDirectories: true)
        let old = downloads.appendingPathComponent("archive.bin")
        try Data(count: 11 * 1024 * 1024).write(to: old)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -400 * 86_400)], ofItemAtPath: old.path)

        let items = CleanupService.scanSynchronously(.largeOldFiles, home: home, now: Date())

        #expect(items.count == 1)
        #expect(items[0].url == old.standardizedFileURL)
        #expect(!items[0].isSelectedByDefault)
    }

    @Test("Leftover matching is conservative around installed apps")
    func leftoverMatching() {
        #expect(LeftoverScanner.candidateBundleIdentifier(from: "com.example.gone.plist", rule: .bundleOnly) == "com.example.gone")
        #expect(LeftoverScanner.candidateBundleIdentifier(from: "group.com.example.shared", rule: .groupContainer) == "com.example.shared")
        #expect(LeftoverScanner.candidateBundleIdentifier(from: "Notes", rule: .bundleOnly) == nil)
        #expect(LeftoverScanner.candidateBundleIdentifier(from: "com.apple.mail.plist", rule: .bundleOnly) == nil)
        #expect(LeftoverScanner.belongsToInstalledApp("com.example.keep.helper", installed: ["com.example.keep"]))
        #expect(!LeftoverScanner.belongsToInstalledApp("com.example.gone", installed: ["com.example.keep"]))
    }

    @Test("Leftover scan finds missing identifiers and skips installed ones")
    func leftoverScan() async throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent("quitx-leftovers-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: home) }
        let preferences = home.appendingPathComponent("Library/Preferences")
        try fileManager.createDirectory(at: preferences, withIntermediateDirectories: true)
        try Data("gone".utf8).write(to: preferences.appendingPathComponent("com.example.gone.plist"))
        try Data("keep".utf8).write(to: preferences.appendingPathComponent("com.example.keep.plist"))
        try Data("apple".utf8).write(to: preferences.appendingPathComponent("com.apple.mail.plist"))

        let items = await LeftoverScanner.scan(installedBundleIdentifiers: ["com.example.keep"], home: home)

        #expect(items.map(\.name) == ["com.example.gone.plist"])
    }
}
