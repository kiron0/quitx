import SwiftUI
import AppKit

struct MainPopoverView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var vm = AppListViewModel.shared

    private let goldColor = Color(red: 247/255, green: 181/255, blue: 0/255)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar & Select All checkbox
            searchBarRow
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Apps list
            if vm.isLoading && vm.apps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if vm.filteredApps.isEmpty {
                emptyAppsView
            } else {
                AppListView(vm: vm)
                    .frame(maxHeight: .infinity)
            }

            Spacer(minLength: 0)

            // Footer
            footerRow
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .frame(width: 294)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.96)
                VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
            }
        )
        .preferredColorScheme(.dark)
        .onChange(of: vm.filteredApps.count) { _ in
            StatusItemController.shared?.updatePopoverSize()
        }
        .overlay(alignment: .bottom) {
            if vm.showToast {
                ToastView(count: vm.lastQuitCount)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showToast)
        .task {
            await vm.refresh()
        }
    }

    // MARK: - Search & Select All Row

    private var searchBarRow: some View {
        HStack(spacing: 10) {
            // Select All Checkbox
            Button {
                vm.toggleSelectAll()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(vm.isAllSelected ? goldColor : Color.white.opacity(0.3), lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(vm.isAllSelected ? goldColor : Color.clear)
                        )
                        .frame(width: 16, height: 16)

                    if vm.isAllSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black.opacity(0.85))
                    } else if !vm.selected.isEmpty {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(goldColor)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(vm.isAllSelected ? "Deselect All" : "Select All")

            // Search input field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))

                TextField("", text: $vm.searchQuery, prompt: Text("Search").foregroundColor(Color.white.opacity(0.35)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.white.opacity(0.92))

                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    // MARK: - Empty State

    private var emptyAppsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(goldColor)
            Text(vm.searchQuery.isEmpty ? "All clean! No apps to quit." : "No running apps match '\(vm.searchQuery)'")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        HStack {
            Text(vm.currentQuote)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)

            Spacer()

            Menu {
                Button {
                    vm.showBackgroundApps.toggle()
                    Task { await vm.refresh() }
                } label: {
                    if vm.showBackgroundApps {
                        Label("Hide background apps", systemImage: "eye.slash")
                    } else {
                        Label("View background apps", systemImage: "eye")
                    }
                }

                Divider()

                Button {
                    Task { await vm.stash() }
                } label: {
                    Label("Stash session", systemImage: "tray.and.arrow.down")
                }

                Button {
                    Task { await vm.restore() }
                } label: {
                    Label("Restore session", systemImage: "tray.and.arrow.up")
                }
                .disabled(!vm.hasStash)

                Divider()

                Button {
                    WelcomeWindowController.shared.show()
                } label: {
                    Label("Welcome Guide...", systemImage: "hand.wave")
                }

                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    Label("Preferences...", systemImage: "gearshape")
                }

                Button {
                    if let url = URL(string: "https://github.com/coreify/quitx") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }

                Divider()

                Button("Quit QuitX") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Blur helper

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
