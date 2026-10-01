import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            FiltersSettingsTab()
                .tabItem { Label("Filters", systemImage: "slider.horizontal.3") }
            ExcludeSettingsTab()
                .tabItem { Label("Exclude", systemImage: "shield") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "bolt.fill") }
        }
        .frame(width: 480, height: 440)
        .environmentObject(configStore)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Automation") {
                HStack {
                    Text("Auto-quit inactive apps after:")
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

            Section("Quit Behavior") {
                Picker("Default Quit Mode", selection: $configStore.config.force) {
                    Text("Graceful").tag(QuitXConfig.ForceMode.normal)
                    Text("Force").tag(QuitXConfig.ForceMode.force)
                }
                .pickerStyle(.segmented)

                Picker("On Quit Failure", selection: Binding(
                    get: { configStore.config.onQuitFailure ?? .prompt },
                    set: { configStore.config.onQuitFailure = $0 }
                )) {
                    Text("Prompt").tag(OnQuitFailureMode.prompt)
                    Text("Force Quit").tag(OnQuitFailureMode.force)
                    Text("Show Error").tag(OnQuitFailureMode.error)
                }
                .pickerStyle(.segmented)

                Toggle("Confirm before quitting 4+ apps", isOn: $configStore.config.confirmQuitAll)
                Toggle("Play sound effects", isOn: $configStore.config.playSounds)
            }

            Section("App List & Sorting") {
                Toggle("Select all apps by default", isOn: $configStore.config.defaultSelectAll)

                Picker("Sort Apps By", selection: $configStore.config.sortBy) {
                    Text("Alphabetical (Name)").tag(QuitXConfig.SortBy?.none)
                    Text("Memory Usage (RAM)").tag(Optional(QuitXConfig.SortBy.memory))
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: configStore.config.quitInactiveAfterMinutes) { configStore.save() }
        .onChange(of: configStore.config.force) { configStore.save() }
        .onChange(of: configStore.config.onQuitFailure) { configStore.save() }
        .onChange(of: configStore.config.confirmQuitAll) { configStore.save() }
        .onChange(of: configStore.config.playSounds) { configStore.save() }
        .onChange(of: configStore.config.defaultSelectAll) { configStore.save() }
        .onChange(of: configStore.config.sortBy) { configStore.save() }
    }
}

// MARK: - Filters & Rules Tab

private final class MusicAppVM: ObservableObject {
    @Published var newMusicApp: String = ""
}

struct FiltersSettingsTab: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var vm = MusicAppVM()

    var body: some View {
        Form {
            Section("System Apps") {
                Toggle("Include Finder in app list", isOn: $configStore.config.includeFinder)
                Toggle("Include Trash", isOn: $configStore.config.includeTrash)
            }

            Section("Background Apps") {
                Toggle("Show background and windowless apps", isOn: $configStore.config.includeBackground)
                Toggle("Group background apps separately", isOn: $configStore.config.groupBackground)
            }

            Section("Music Apps Protection") {
                Toggle("Never quit music players", isOn: $configStore.config.neverQuitMusic)

                if configStore.config.neverQuitMusic {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recognized music apps: \(configStore.config.musicApps.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("Add app (e.g. VLC)", text: $vm.newMusicApp)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                let t = vm.newMusicApp.trimmingCharacters(in: .whitespaces)
                                guard !t.isEmpty else { return }
                                if !configStore.config.musicApps.contains(t) {
                                    configStore.config.musicApps.append(t)
                                    configStore.save()
                                }
                                vm.newMusicApp = ""
                            }
                            .disabled(vm.newMusicApp.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $configStore.config.autoUpdate)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: configStore.config.includeFinder) { configStore.save() }
        .onChange(of: configStore.config.includeTrash) { configStore.save() }
        .onChange(of: configStore.config.includeBackground) { configStore.save() }
        .onChange(of: configStore.config.groupBackground) { configStore.save() }
        .onChange(of: configStore.config.neverQuitMusic) { configStore.save() }
        .onChange(of: configStore.config.autoUpdate) { configStore.save() }
    }
}

// MARK: - Exclude List Tab

private final class ExcludeVM: ObservableObject {
    @Published var newItem: String = ""
}

struct ExcludeSettingsTab: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var vm = ExcludeVM()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        Spacer()
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

                Button("Add to Exclude") {
                    let trimmed = vm.newItem.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    if !configStore.config.exclude.contains(trimmed) {
                        configStore.config.exclude.append(trimmed)
                        configStore.save()
                    }
                    vm.newItem = ""
                }
                .disabled(vm.newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 12) {
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

            Text("Fast, minimal menubar companion to quit, force quit, and manage running macOS apps.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Config synced with ~/.config/quitx/config.json")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider().padding(.horizontal, 32)

            HStack(spacing: 16) {
                Link("GitHub Repo", destination: URL(string: "https://github.com/coreify/quitx-app")!)
                Link("Documentation", destination: URL(string: "https://quitx.coreify.io")!)
            }
            .font(.footnote)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
