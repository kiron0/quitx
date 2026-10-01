// Basic model tests — no UI dependencies
import XCTest
@testable import QuitX

final class MemoryFormatterTests: XCTestCase {
    func testKB() {
        XCTAssertEqual(MemoryFormatter.format(bytes: 512 * 1024), "512 KB")
    }
    func testMB() {
        XCTAssertEqual(MemoryFormatter.format(bytes: 256 * 1024 * 1024), "256 MB")
    }
    func testGB() {
        let bytes: UInt64 = 2 * 1024 * 1024 * 1024
        XCTAssertTrue(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }
}

final class AppInfoTests: XCTestCase {
    func testWindowlessFlag() {
        let app = AppInfo(name: "Test", windowCount: 0, memoryBytes: 0)
        XCTAssertTrue(app.isWindowless)
    }
    func testNotWindowlessWhenBackground() {
        let app = AppInfo(name: "Agent", isBackground: true, windowCount: 0)
        XCTAssertFalse(app.isWindowless)
    }
}
