import CoreGraphics
import Foundation
import Testing
@testable import QuitX

@Suite("Performance guards")
struct PerformanceGuardTests {
    @Test("Window observers rescan accessibility windows at most every 5 seconds")
    @MainActor
    func observerRefreshThrottle() {
        #expect(AXWindowCloseObserver.isRefreshDue(lastRefresh: nil, now: 10))
        #expect(!AXWindowCloseObserver.isRefreshDue(lastRefresh: 10, now: 11))
        #expect(!AXWindowCloseObserver.isRefreshDue(lastRefresh: 10, now: 14.9))
        #expect(AXWindowCloseObserver.isRefreshDue(lastRefresh: 10, now: 15))
        #expect(AXWindowCloseObserver.refreshInterval == 5)
    }

    @Test("Rescans keep the user's Quick Clean choices")
    func carriedSelection() {
        let item = CleanupItem(url: URL(fileURLWithPath: "/tmp/qx"), category: .userCache, bytes: 1, fileCount: 1, isDirectory: true, lastModified: nil, isSelectedByDefault: true)
        let all = QuickCleanGroup.Kind.allCases.map { QuickCleanGroup(kind: $0, items: [item]) }
        let first = QuickCleanMonitor.carriedSelection(previous: [], previousKinds: nil, found: all)
        #expect(first == [.userCaches, .userLogs, .developerCaches])
        let kept = QuickCleanMonitor.carriedSelection(previous: [.trash], previousKinds: Set(QuickCleanGroup.Kind.allCases), found: all)
        #expect(kept == [.trash])
        let newKind = QuickCleanMonitor.carriedSelection(previous: [.trash], previousKinds: [.trash], found: all)
        #expect(newKind == [.trash, .userCaches, .userLogs, .developerCaches])
        let gone = QuickCleanMonitor.carriedSelection(previous: [.userLogs], previousKinds: [.userLogs], found: [])
        #expect(gone.isEmpty)
    }

    @Test("Visible windows skip the accessibility count unless they were just closed")
    func onScreenShortcut() {
        let visible: [pid_t: Set<CGWindowID>] = [10: [1, 2], 11: [3]]
        #expect(LastWindowQuitWindowState.openOnScreenWindows(owners: [10, 11], visible: visible, closedIDs: []) == 3)
        #expect(LastWindowQuitWindowState.openOnScreenWindows(owners: [10], visible: visible, closedIDs: [1, 2]) == 0)
        #expect(LastWindowQuitWindowState.openOnScreenWindows(owners: [12], visible: visible, closedIDs: []) == 0)
    }
}
