import SwiftUI

struct AppListView: View {
    @ObservedObject var vm: AppListViewModel

    @ViewBuilder
    var body: some View {
        if vm.listNeedsScrolling {
            ScrollView(.vertical, showsIndicators: true) {
                rows
            }
        } else {
            rows
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var rows: some View {
        let sortBy = ConfigStore.shared.config.sortBy
        let forceMode = ConfigStore.shared.config.force
        return LazyVStack(spacing: 2) {
            ForEach(vm.filteredApps) { app in
                AppRowView(
                    app: app,
                    isSelected: vm.selected.contains(app.id),
                    isOptionKeyPressed: vm.isOptionKeyPressed,
                    isPending: vm.pendingAppIds.contains(app.id),
                    sortBy: sortBy,
                    forceMode: forceMode,
                    onToggle: {
                        vm.toggleSelection(for: app)
                    },
                    onQuit: { force in
                        vm.requestQuitSingle(app: app, force: force)
                    },
                    onRestart: {
                        vm.requestRestart(app: app)
                    },
                    onExclude: {
                        let identifier = app.bundleId ?? app.name
                        ConfigStore.shared.addExcludedApps([identifier])
                    },
                    onQuitOthers: { force in
                        Task {
                            await vm.quitOthers(keeping: app, force: force)
                        }
                    }
                )
            }
        }
        .padding(.vertical, 2)
    }
}
