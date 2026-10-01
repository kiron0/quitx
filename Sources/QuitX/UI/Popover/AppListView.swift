import SwiftUI

struct AppListView: View {
    @ObservedObject var vm: AppListViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 2) {
                ForEach(vm.filteredApps) { app in
                    AppRowView(
                        app: app,
                        isSelected: vm.selected.contains(app.id),
                        isOptionKeyPressed: vm.isOptionKeyPressed,
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
            .padding(.vertical, 4)
        }
    }
}
