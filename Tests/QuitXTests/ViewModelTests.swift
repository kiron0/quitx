import Testing
import Foundation
@testable import QuitX

@Suite("AppListViewModel State & Selection Tests")
@MainActor
struct AppListViewModelTests {
    let vm = AppListViewModel.shared

    let app1 = AppInfo(name: "App 1", pid: 101)
    let app2 = AppInfo(name: "App 2", pid: 102)
    let app3 = AppInfo(name: "App 3", pid: 103)
    let bgApp = AppInfo(name: "Daemon", pid: 104, isBackground: true)

    @Test("Initial quote is non-empty")
    func testInitialQuote() {
        #expect(!vm.currentQuote.isEmpty)
    }

    @Test("Randomize quote changes or preserves quote")
    func testRandomizeQuote() {
        vm.randomizeQuote()
        #expect(!vm.currentQuote.isEmpty)
    }

    @Test("Filtered apps without background apps")
    func testFilteredAppsNoBackground() {
        vm.apps = [app1, app2, bgApp]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        #expect(vm.filteredApps.count == 2)
        #expect(!vm.filteredApps.contains(where: { $0.isBackground }))
    }

    @Test("Filtered apps with background apps")
    func testFilteredAppsWithBackground() {
        vm.apps = [app1, app2, bgApp]
        vm.showBackgroundApps = true
        vm.searchQuery = ""
        #expect(vm.filteredApps.count == 3)
        #expect(vm.filteredApps.contains(where: { $0.isBackground }))
    }

    @Test("Filtered apps with search query")
    func testFilteredAppsSearch() {
        vm.apps = [app1, app2, bgApp]
        vm.showBackgroundApps = false
        vm.searchQuery = "App 1"
        #expect(vm.filteredApps.count == 1)
        #expect(vm.filteredApps.first?.name == "App 1")
    }

    @Test("Filtered apps with case-insensitive search")
    func testFilteredAppsCaseInsensitive() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = "app 2"
        #expect(vm.filteredApps.count == 1)
        #expect(vm.filteredApps.first?.name == "App 2")
    }

    @Test("Filtered apps trim surrounding search whitespace")
    func testFilteredAppsTrimWhitespace() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = "  app 2\n"
        #expect(vm.filteredApps.map(\.name) == ["App 2"])
    }

    @Test("Toggle selection adds unselected app")
    func testToggleSelectionAdd() {
        vm.selected.removeAll()
        vm.toggleSelection(for: app1)
        #expect(vm.selected.contains(app1.id))
    }

    @Test("Toggle selection removes selected app")
    func testToggleSelectionRemove() {
        vm.selected = [app1.id]
        vm.toggleSelection(for: app1)
        #expect(!vm.selected.contains(app1.id))
    }

    @Test("isAllSelected false when empty filtered apps")
    func testIsAllSelectedEmpty() {
        vm.apps = []
        vm.selected = []
        #expect(!vm.isAllSelected)
    }

    @Test("isAllSelected true when all visible apps selected")
    func testIsAllSelectedTrue() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, app2.id]
        #expect(vm.isAllSelected)
    }

    @Test("isAllSelected false when some apps unselected")
    func testIsAllSelectedPartial() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id]
        #expect(!vm.isAllSelected)
    }

    @Test("isPartiallySelected true when only subset selected")
    func testIsPartiallySelectedTrue() {
        vm.apps = [app1, app2, app3]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id]
        #expect(vm.isPartiallySelected)
    }

    @Test("isPartiallySelected false when none selected")
    func testIsPartiallySelectedNone() {
        vm.apps = [app1, app2]
        vm.selected = []
        #expect(!vm.isPartiallySelected)
    }

    @Test("isPartiallySelected false when all selected")
    func testIsPartiallySelectedAll() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, app2.id]
        #expect(!vm.isPartiallySelected)
    }

    @Test("Toggle select all selects all when none selected")
    func testToggleSelectAllFromNone() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = []
        vm.toggleSelectAll()
        #expect(vm.selected.contains(app1.id))
        #expect(vm.selected.contains(app2.id))
        #expect(vm.isAllSelected)
    }

    @Test("Toggle select all deselects all when all selected")
    func testToggleSelectAllFromAll() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, app2.id]
        vm.toggleSelectAll()
        #expect(vm.selected.isEmpty)
        #expect(!vm.isAllSelected)
    }

    @Test("Toggle select all selects remaining when partially selected")
    func testToggleSelectAllFromPartial() {
        vm.apps = [app1, app2, app3]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id]
        vm.toggleSelectAll()
        #expect(vm.selected.contains(app1.id))
        #expect(vm.selected.contains(app2.id))
        #expect(vm.selected.contains(app3.id))
        #expect(vm.isAllSelected)
    }

    @Test("Selection preserved across search queries")
    func testSelectionPreservedAcrossSearch() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.selected = [app1.id]

        vm.searchQuery = "App 2"
        #expect(vm.selected.contains(app1.id))

        vm.searchQuery = ""
        #expect(vm.selected.contains(app1.id))
    }

    @Test("Toggle select all with search query only impacts filtered apps")
    func testToggleSelectAllWithSearch() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.selected = []

        vm.searchQuery = "App 1"
        vm.toggleSelectAll()

        #expect(vm.selected.contains(app1.id))
        #expect(!vm.selected.contains(app2.id))
    }

    @Test("Visible selection count excludes hidden background apps")
    func testVisibleSelectionCount() {
        vm.apps = [app1, bgApp]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, bgApp.id]
        #expect(vm.selectedVisibleCount == 1)
    }

    @Test("Show toast flag can be updated")
    func testToastState() {
        vm.showToast = false
        vm.lastQuitCount = 5
        #expect(vm.lastQuitCount == 5)
        #expect(!vm.showToast)
        vm.showToast = true
        #expect(vm.showToast)
    }

    @Test("Option key pressed state toggles correctly")
    func testOptionKeyState() {
        vm.isOptionKeyPressed = false
        #expect(!vm.isOptionKeyPressed)
        vm.isOptionKeyPressed = true
        #expect(vm.isOptionKeyPressed)
    }

    @Test("Loading state toggles correctly")
    func testLoadingState() {
        vm.isLoading = false
        #expect(!vm.isLoading)
        vm.isLoading = true
        #expect(vm.isLoading)
    }

    @Test("applyDefaultSelection selects all when defaultSelectAll is true")
    func testApplyDefaultSelectionTrue() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        ConfigStore.shared.config.defaultSelectAll = true

        vm.applyDefaultSelection()

        #expect(vm.selected.contains(app1.id))
        #expect(vm.selected.contains(app2.id))
        #expect(vm.isAllSelected)
    }

    @Test("applyDefaultSelection deselects all when defaultSelectAll is false")
    func testApplyDefaultSelectionFalse() {
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, app2.id]
        ConfigStore.shared.config.defaultSelectAll = false

        vm.applyDefaultSelection()

        #expect(vm.selected.isEmpty)
        #expect(!vm.isAllSelected)
    }

    @Test("resetSelectionState allows refresh to re-evaluate defaultSelectAll")
    func testResetSelectionState() {
        vm.resetSelectionState()
        ConfigStore.shared.config.defaultSelectAll = true
        vm.apps = [app1, app2]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = []

        vm.applyDefaultSelection()
        #expect(vm.selected.count == 2)

        vm.resetSelectionState()
        ConfigStore.shared.config.defaultSelectAll = false
        vm.applyDefaultSelection()
        #expect(vm.selected.isEmpty)
    }

    @Test("User manual selection is preserved across popover toggle without config change")
    func testUserSelectionsPreservedAcrossPopoverReopen() {
        vm.apps = [app1, app2, app3]
        vm.showBackgroundApps = false
        vm.searchQuery = ""
        vm.selected = [app1.id, app3.id]

        // Popover closes (does not wipe user selections) and reopen checks valid running IDs
        let validIds = Set(vm.apps.map(\.id))
        vm.selected = vm.selected.intersection(validIds)

        #expect(vm.selected.contains(app1.id))
        #expect(!vm.selected.contains(app2.id))
        #expect(vm.selected.contains(app3.id))
        #expect(vm.selected.count == 2)
    }
}
