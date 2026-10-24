import SwiftUI

struct PortListView: View {
    @ObservedObject var vm: PortListViewModel
    var needsScrolling: Bool
    @EnvironmentObject private var configStore: ConfigStore

    @ViewBuilder
    var body: some View {
        if needsScrolling {
            ScrollView(.vertical, showsIndicators: true) {
                rows
            }
        } else {
            rows
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var rows: some View {
        LazyVStack(spacing: 2) {
            ForEach(vm.groupedPorts, id: \.0) { group, ports in
                if !group.isEmpty {
                    Text(group)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.top, 3)
                }
                ForEach(ports) { port in
                    PortRowView(port: port, vm: vm)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
