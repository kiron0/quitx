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
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(vm.filteredApps) { app in
                AppRowView(
                    app: app,
                    isSelected: vm.selected.contains(app.id),
                    isOptionKeyPressed: vm.isOptionKeyPressed,
                    isPending: vm.pendingAppIds.contains(app.id),
                    onToggle: {
                        vm.toggleSelection(for: app)
                    },
                    onQuit: { force in
                        Task { await vm.quitSingle(app: app, force: force) }
                    },
                    onRestart: {
                        Task { await vm.restartApp(app) }
                    },
                    onExclude: {
                        if let bid = app.bundleId {
                            ConfigStore.shared.config.exclude.append(bid)
                            ConfigStore.shared.save()
                            Task { await vm.refresh() }
                        }
                    }
                )
            }
        }
        .padding(.vertical, 2)
    }
}
