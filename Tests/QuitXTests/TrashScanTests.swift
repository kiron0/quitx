import Darwin
import Foundation
import Testing
@testable import QuitX

@Suite("Trash scan")
struct TrashScanTests {
    @Test("Trash shows empty, hidden and iCloud Drive items but not Finder metadata")
    func listsEveryTrashedItem() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent("quitx-trash-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: home) }
        let trash = home.appendingPathComponent(".Trash")
        let cloudTrash = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/.Trash")
        try fileManager.createDirectory(at: trash.appendingPathComponent("Empty Folder"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cloudTrash, withIntermediateDirectories: true)
        try Data().write(to: trash.appendingPathComponent("empty.txt"))
        try Data(count: 2_048).write(to: trash.appendingPathComponent(".env"))
        try Data(count: 4_096).write(to: trash.appendingPathComponent("report.pdf"))
        try Data(count: 64).write(to: trash.appendingPathComponent(".DS_Store"))
        try Data().write(to: trash.appendingPathComponent(".localized"))
        try Data(count: 1_024).write(to: cloudTrash.appendingPathComponent("notes.txt"))

        let names = Set(CleanupService.scanSynchronously(.trashBins, home: home, now: Date()).map(\.name))
        #expect(names == ["Empty Folder", "empty.txt", ".env", "report.pdf", "notes.txt"])
    }

    @Test("Trash roots cover the home, iCloud Drive and each volume once")
    func roots() {
        let home = URL(fileURLWithPath: "/Users/me")
        let volume = URL(fileURLWithPath: "/Volumes/Disk/.Trashes/501")
        let paths = CleanupService.trashRoots(home: home, volumeTrashes: [volume, volume]).map(\.path)
        #expect(paths == [
            "/Users/me/.Trash",
            "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/.Trash",
            "/Volumes/Disk/.Trashes/501"
        ])
        #expect(CleanupService.volumeTrashRoots().allSatisfy { $0.path.hasPrefix("/Volumes/") && $0.path.hasSuffix("/.Trashes/\(getuid())") })
    }

    @Test("Only items inside your own volume Trash can be removed")
    func volumeTrashSafety() {
        let uid = getuid()
        #expect(AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/.Trashes/\(uid)/old.zip", uid: uid))
        #expect(AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/.Trashes/\(uid)/Folder/file", uid: uid))
        #expect(!AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/.Trashes/\(uid)", uid: uid))
        #expect(!AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/.Trashes/\(uid + 1)/old.zip", uid: uid))
        #expect(!AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/Documents/old.zip", uid: uid))
        #expect(!AppUninstaller.isInsideVolumeTrash("/Volumes/Disk/.Trashes/\(uid)/../../secret", uid: uid))
        #expect(AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Volumes/Disk/.Trashes/\(uid)/old.zip")))
        #expect(!AppUninstaller.isSafePermanentRemoval(URL(fileURLWithPath: "/Volumes/Disk/.Trashes/\(uid)")))
    }
}
