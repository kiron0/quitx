import Foundation

enum TestPhase {
    static let current = ProcessInfo.processInfo.environment["QUITX_TEST_PHASE"] ?? "regression"
    static let integration = current == "integration"
    static let ui = current == "ui"
    static let snapshots = current == "snapshots"
}
