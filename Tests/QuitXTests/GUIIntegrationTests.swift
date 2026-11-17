import Testing

@Suite("GUI Integration Tests", .serialized)
enum GUIIntegrationTests {
    @Suite("Window layout", .enabled(if: TestPhase.ui))
    @MainActor
    struct WindowLayoutTests {}

    @Suite("Snapshots", .enabled(if: TestPhase.snapshots))
    @MainActor
    struct SnapshotTests {}
}
