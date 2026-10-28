import AppKit
import SwiftUI
import Testing
@testable import QuitX

extension PortListViewModelTests {
    @Test("Switching Apps and Ports tabs keeps layout stable while the window resizes")
    func tabSwitchLayout() async throws {
        _ = NSApplication.shared
        let store = ConfigStore.shared
        let saved = store.config
        defer {
            store.config = saved
            AppListViewModel.shared.open(.apps)
        }
        store.config.portsEnabled = true

        let hosting = NSHostingController(rootView: MainPopoverView().environmentObject(store))
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: StatusItemController.popoverWidth, height: 360),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        window.setFrame(NSRect(x: 0, y: 0, width: StatusItemController.popoverWidth, height: 360), display: false)

        let heights: [CGFloat] = [300, 420, 260, 500, 340]
        for (index, tab) in [PopoverTab.ports, .apps, .ports, .apps, .ports].enumerated() {
            AppListViewModel.shared.selectTab(tab)
            #expect(AppListViewModel.shared.activeTab == tab)
            window.setFrame(NSRect(x: 0, y: 0, width: StatusItemController.popoverWidth, height: heights[index]), display: true)
            window.updateConstraintsIfNeeded()
            hosting.view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 120_000_000)
        }

        store.config.portsEnabled = false
        window.updateConstraintsIfNeeded()
        hosting.view.layoutSubtreeIfNeeded()
        #expect(AppListViewModel.shared.activeTab == .ports)
        window.orderOut(nil)
        window.contentViewController = nil
    }
}
