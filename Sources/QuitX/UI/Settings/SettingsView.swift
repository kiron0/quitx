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
                .tabItem { Label("About", systemImage: "bolt.fill") }
        }
        .frame(width: 440, height: 420)
        .environmentObject(configStore)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Audio & Feedback") {
                Toggle("Play sound effects on quit", isOn: $configStore.config.playSounds)
            }

            Section("Automation") {
                HStack {
                    Text("Quit inactive apps after:")
                    Spacer()
                    Picker("", selection: $configStore.config.quitInactiveAfterMinutes) {
                        Text("Disabled").tag(0)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .frame(width: 140)
                }
            }

            Section("Apps & Filtering") {
                Toggle("Include Finder", isOn: $configStore.config.includeFinder)
                Toggle("Include Trash", isOn: $configStore.config.includeTrash)
                Toggle("Include Background Apps", isOn: $configStore.config.includeBackground)
                Toggle("Never Quit Music Apps", isOn: $configStore.config.neverQuitMusic)
                Toggle("Confirm when quitting 4+ apps", isOn: $configStore.config.confirmQuitAll)
            }

            Section("Quit Mode") {
                Picker("Default Quit Mode", selection: $configStore.config.force) {
                    Text("Graceful").tag(QuitXConfig.ForceMode.normal)
                    Text("Force").tag(QuitXConfig.ForceMode.force)
                }
                .pickerStyle(.segmented)
            }

            Section("Sort Order") {
                Picker("Sort Apps By", selection: $configStore.config.sortBy) {
                    Text("Name").tag(QuitXConfig.SortBy?.none)
                    Text("Memory Usage").tag(Optional(QuitXConfig.SortBy.memory))
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: configStore.config.playSounds) { configStore.save() }
        .onChange(of: configStore.config.quitInactiveAfterMinutes) { configStore.save() }
        .onChange(of: configStore.config.includeFinder) { configStore.save() }
        .onChange(of: configStore.config.includeTrash) { configStore.save() }
        .onChange(of: configStore.config.includeBackground) { configStore.save() }
        .onChange(of: configStore.config.neverQuitMusic) { configStore.save() }
        .onChange(of: configStore.config.confirmQuitAll) { configStore.save() }
        .onChange(of: configStore.config.force) { configStore.save() }
        .onChange(of: configStore.config.sortBy) { configStore.save() }
    }
}

// MARK: - Exclude List

private final class ExcludeVM: ObservableObject {
    @Published var newItem: String = ""
}

struct ExcludeListView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var vm = ExcludeVM()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Protected apps will never be quit automatically or via Quit All.")
                .foregroundStyle(.secondary)
                .font(.callout)

            List {
                ForEach(configStore.config.exclude, id: \.self) { item in
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 12))
                        Text(item)
                            .font(.system(size: 13))
                    }
                }
                .onDelete { indices in
                    configStore.config.exclude.remove(atOffsets: indices)
                    configStore.save()
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                TextField("Bundle ID (e.g. com.apple.Safari) or App Name", text: $vm.newItem)
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
        VStack(spacing: 14) {
            Spacer()

            if let img = NSImage(contentsOfFile: "Support/Icons/icon_128x128.png") ?? Bundle.main.image(forResource: "AppIcon") {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 4) {
                Text("QuitX for macOS")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Fast, minimal menubar app to quit, force quit, and manage running macOS apps.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Divider().padding(.horizontal, 32)

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/coreify/quitx-app")!)
                Link("Docs", destination: URL(string: "https://quitx.coreify.io")!)
            }
            .font(.footnote)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
