import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ExcludeListView()
                .tabItem { Label("Exclude", systemImage: "minus.circle") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 380)
        .environmentObject(configStore)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Behaviour") {
                Toggle("Include Finder", isOn: $configStore.config.includeFinder)
                Toggle("Include Trash", isOn: $configStore.config.includeTrash)
                Toggle("Include Background Apps", isOn: $configStore.config.includeBackground)
                Toggle("Group Background Apps", isOn: $configStore.config.groupBackground)
                Toggle("Never Quit Music Apps", isOn: $configStore.config.neverQuitMusic)
                Toggle("Select All by Default", isOn: $configStore.config.defaultSelectAll)
            }
            Section("Quit Mode") {
                Picker("On Quit", selection: $configStore.config.force) {
                    Text("Graceful").tag(QuitXConfig.ForceMode.normal)
                    Text("Force").tag(QuitXConfig.ForceMode.force)
                }
                .pickerStyle(.segmented)
            }
            Section("Sort") {
                Picker("Sort Apps By", selection: $configStore.config.sortBy) {
                    Text("Name").tag(QuitXConfig.SortBy?.none)
                    Text("Memory").tag(Optional(QuitXConfig.SortBy.memory))
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: configStore.config.includeFinder) { configStore.save() }
        .onChange(of: configStore.config.includeTrash) { configStore.save() }
        .onChange(of: configStore.config.includeBackground) { configStore.save() }
        .onChange(of: configStore.config.groupBackground) { configStore.save() }
        .onChange(of: configStore.config.neverQuitMusic) { configStore.save() }
        .onChange(of: configStore.config.defaultSelectAll) { configStore.save() }
    }
}

// MARK: - Exclude List

/// ObservableObject holds mutable text field state — avoids @State macro requirement.
private final class ExcludeVM: ObservableObject {
    @Published var newItem: String = ""
}

struct ExcludeListView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var vm = ExcludeVM()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apps in this list are never quit.")
                .foregroundStyle(.secondary)
                .font(.callout)

            List {
                ForEach(configStore.config.exclude, id: \.self) { item in
                    Text(item)
                }
                .onDelete { indices in
                    configStore.config.exclude.remove(atOffsets: indices)
                    configStore.save()
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                TextField("Bundle ID or app name", text: $vm.newItem)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = vm.newItem.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    configStore.config.exclude.append(trimmed)
                    configStore.save()
                    vm.newItem = ""
                }
                .disabled(vm.newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.app.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text("QuitX").font(.title2.bold())
            Text("macOS App · v1.0.0").foregroundStyle(.secondary)
            Divider()
            Link("quitx.js.org", destination: URL(string: "https://quitx.js.org")!)
            Link("GitHub", destination: URL(string: "https://github.com/coreify/quitx")!)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
