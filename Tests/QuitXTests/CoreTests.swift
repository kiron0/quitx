import Testing
@testable import QuitX

@Suite struct MemoryFormatterTests {
    @Test func testKB() {
        #expect(MemoryFormatter.format(bytes: 512 * 1024) == "512 KB")
    }
    @Test func testMB() {
        #expect(MemoryFormatter.format(bytes: 256 * 1024 * 1024) == "256 MB")
    }
    @Test func testGB() {
        let bytes: UInt64 = 2 * 1024 * 1024 * 1024
        #expect(MemoryFormatter.format(bytes: bytes).contains("GB"))
    }
}

@Suite struct AppInfoTests {
    @Test func testWindowlessFlag() {
        let app = AppInfo(name: "Test", windowCount: 0, memoryBytes: 0)
        #expect(app.isWindowless)
    }
    @Test func testNotWindowlessWhenBackground() {
        let app = AppInfo(name: "Agent", isBackground: true, windowCount: 0)
        #expect(!app.isWindowless)
    }
}
