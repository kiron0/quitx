import Foundation
import Testing
@testable import QuitX

@Suite("Quick clean")
struct QuickCleanTests {
    private static func makeHome() throws -> URL {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent("quitx-quick-\(UUID().uuidString)")
        let files: [(String, Int)] = [
            ("Library/Caches/com.example.browser/blob", 8_192),
            ("Library/Caches/npm/blob", 4_096),
            ("Library/Logs/com.example.app/app.log", 2_048),
            (".npm/_cacache/index", 4_096),
            ("Library/Developer/Xcode/DerivedData/App-abc/build", 16_384),
            ("Library/Developer/Xcode/Archives/App.xcarchive/payload", 16_384),
            ("Library/Developer/Xcode/iOS DeviceSupport/17.0/symbols", 16_384),
            (".Trash/old.zip", 1_024)
        ]
        for (path, size) in files {
            let url = home.appendingPathComponent(path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(count: size).write(to: url)
        }
        return home
    }

    private static func item(_ path: String, bytes: Int64) -> CleanupItem {
        CleanupItem(
            url: URL(fileURLWithPath: path),
            category: .userCache,
            bytes: bytes,
            fileCount: 1,
            isDirectory: true,
            lastModified: nil,
            isSelectedByDefault: true
        )
    }

    private static let sampleGroups: [QuickCleanGroup] = [
        QuickCleanGroup(kind: .userCaches, items: [item("/tmp/qx-a", bytes: 3_000), item("/tmp/qx-b", bytes: 1_000)]),
        QuickCleanGroup(kind: .developerCaches, items: [item("/tmp/qx-c", bytes: 2_000)]),
        QuickCleanGroup(kind: .trash, items: [item("/tmp/qx-d", bytes: 500)])
    ]

    @Test("Scan groups safe caches and keeps risky developer data out")
    func scanGroups() throws {
        let home = try Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let groups = QuickCleanService.scanSynchronously(home: home.standardizedFileURL, now: Date())
        let kinds = groups.map(\.kind)
        #expect(kinds == [.userCaches, .userLogs, .developerCaches, .trash])

        let paths = Set(groups.flatMap { $0.items.map(\.url.path) })
        #expect(paths.contains { $0.hasSuffix("Library/Caches/com.example.browser") })
        #expect(paths.contains { $0.hasSuffix("Xcode/DerivedData") })
        #expect(paths.contains { $0.hasSuffix(".npm/_cacache") })
        #expect(paths.contains { $0.hasSuffix("Library/Caches/npm") })
        #expect(!paths.contains { $0.contains("Archives") })
        #expect(!paths.contains { $0.contains("DeviceSupport") })
        #expect(paths.count == groups.reduce(0) { $0 + $1.items.count })

        let byKind = Dictionary(uniqueKeysWithValues: groups.map { ($0.kind, $0) })
        #expect(byKind[.userCaches]?.items.contains { $0.url.lastPathComponent == "npm" } == false)
        #expect(byKind[.trash]?.safety == .caution)
        #expect(byKind[.trash]?.isSelectedByDefault == false)
        #expect(byKind[.userCaches]?.safety == .safe)
        #expect(QuickCleanService.defaultSelection(for: groups) == [.userCaches, .userLogs, .developerCaches])
    }

    @Test("Totals and URLs follow the selection")
    func selectionMath() {
        let groups = Self.sampleGroups
        #expect(QuickCleanService.bytes(of: groups, selected: [.userCaches]) == 4_000)
        #expect(QuickCleanService.bytes(of: groups, selected: [.userCaches, .trash]) == 4_500)
        #expect(QuickCleanService.bytes(of: groups, selected: []) == 0)
        #expect(QuickCleanService.urls(of: groups, selected: [.developerCaches]).map(\.path) == ["/tmp/qx-c"])
        #expect(QuickCleanService.isRebuildableXcodeCache(URL(fileURLWithPath: "/Users/me/Library/Developer/Xcode/DerivedData")))
        #expect(!QuickCleanService.isRebuildableXcodeCache(URL(fileURLWithPath: "/Users/me/Library/Developer/Xcode/Archives")))
    }

    @Test("Monitor scans, selects safe groups and only cleans after confirmation")
    @MainActor
    func monitorFlow() async {
        let removed = RemovedURLs()
        let monitor = QuickCleanMonitor(
            scanner: { Self.sampleGroups },
            remover: { urls in
                await removed.add(urls)
                var result = AppUninstaller.RemovalResult()
                result.trashed = urls.filter { $0.path != "/tmp/qx-b" }
                result.failed = urls.filter { $0.path == "/tmp/qx-b" }.map { AppUninstaller.RemovalFailure(url: $0, message: "busy") }
                return result
            }
        )
        #expect(monitor.reclaimableBytes == nil)
        #expect(monitor.isStale(maxAge: 60))
        monitor.requestClean()
        #expect(!monitor.confirmationShown)

        monitor.refreshIfStale(maxAge: 60)
        #expect(monitor.phase == .scanning)
        await monitor.waitForWork()
        #expect(monitor.phase == .idle)
        #expect(monitor.selection == [.userCaches, .developerCaches])
        #expect(monitor.reclaimableBytes == 6_000)
        #expect(monitor.selectedBytes == 6_000)
        #expect(monitor.selectedItemCount == 3)
        #expect(!monitor.isStale(maxAge: 60))

        monitor.toggle(.developerCaches)
        #expect(monitor.selectedBytes == 4_000)
        monitor.toggle(.userLogs)
        #expect(monitor.selection == [.userCaches])

        monitor.requestClean()
        #expect(monitor.confirmationShown)
        monitor.cancelClean()
        #expect(!monitor.confirmationShown)
        #expect(await removed.all.isEmpty)

        monitor.requestClean()
        var outcome: QuickCleanMonitor.Outcome?
        monitor.clean { outcome = $0 }
        #expect(!monitor.confirmationShown)
        #expect(monitor.phase == .cleaning)
        await monitor.waitForWork()
        #expect(await removed.all.map(\.path).sorted() == ["/tmp/qx-a", "/tmp/qx-b"])
        #expect(outcome == QuickCleanMonitor.Outcome(freedBytes: 3_000, removed: 1, skipped: 1))
        #expect(outcome?.message.contains("1 in use") == true)
        #expect(monitor.phase == .idle)
    }

    @Test("Nothing selected means nothing to confirm")
    @MainActor
    func emptySelection() async {
        let monitor = QuickCleanMonitor(scanner: { [] }, remover: { _ in AppUninstaller.RemovalResult() })
        monitor.rescan()
        await monitor.waitForWork()
        #expect(monitor.groups.isEmpty)
        #expect(monitor.reclaimableBytes == 0)
        monitor.requestClean()
        #expect(!monitor.confirmationShown)
        var called = false
        monitor.clean { _ in called = true }
        #expect(!called)
        #expect(monitor.phase == .idle)
    }

    @Test("Quick clean never escalates to an administrator prompt")
    func noAdministratorEscalation() async throws {
        let fileManager = FileManager.default
        let parent = fileManager.temporaryDirectory.appendingPathComponent("quitx-noadmin-\(UUID().uuidString)")
        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
            try? fileManager.removeItem(at: parent)
        }
        let locked = parent.appendingPathComponent("locked")
        try fileManager.createDirectory(at: locked, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: locked.appendingPathComponent("file"))
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent.path)

        let result = await AppUninstaller.removePermanently([locked], allowAdministrator: false)

        #expect(result.trashed.isEmpty)
        #expect(result.failed.map(\.url) == [locked])
        #expect(fileManager.fileExists(atPath: locked.path))
    }
}

actor RemovedURLs {
    private(set) var all: [URL] = []

    func add(_ urls: [URL]) {
        all.append(contentsOf: urls)
    }
}
