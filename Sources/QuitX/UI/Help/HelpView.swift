import AppKit
import SwiftUI

enum QuitXHelpCategory: String, CaseIterable, Identifiable, Sendable {
    case essentials = "Essentials"
    case automation = "Automation"
    case preferences = "Preferences"
    case support = "Support"

    var id: String { rawValue }
}

struct QuitXHelpSection: Hashable, Sendable {
    let title: String
    let body: String
    let bullets: [String]

    init(title: String, body: String, bullets: [String] = []) {
        self.title = title
        self.body = body
        self.bullets = bullets
    }
}

struct QuitXHelpTopic: Identifiable, Hashable, Sendable {
    let id: String
    let category: QuitXHelpCategory
    let title: String
    let symbol: String
    let summary: String
    let sections: [QuitXHelpSection]

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let content = ([title, summary] + sections.flatMap { [$0.title, $0.body] + $0.bullets })
            .joined(separator: " ")
        return content.localizedCaseInsensitiveContains(query)
    }

    static let all: [QuitXHelpTopic] = [
        QuitXHelpTopic(
            id: "quick-start",
            category: .essentials,
            title: "Quick Start",
            symbol: "bolt.fill",
            summary: "Open QuitX, choose running apps, then quit them together or one at a time.",
            sections: [
                QuitXHelpSection(
                    title: "Open QuitX",
                    body: "Click the QuitX menu bar icon or use the configured Open QuitX shortcut. Type in Search to filter the current app list."
                ),
                QuitXHelpSection(
                    title: "Choose apps",
                    body: "Select each app checkbox, or use the checkbox beside Search to select or deselect the visible list. The default selection behavior is available in Settings."
                ),
                QuitXHelpSection(
                    title: "Quit apps",
                    body: "Use Quit Selected for the current selection. Use the power button on a row for one app. QuitX shows progress and keeps failed apps selected."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "app-list",
            category: .essentials,
            title: "App List and Actions",
            symbol: "list.bullet.rectangle",
            summary: "Understand resource values, background apps, and row actions.",
            sections: [
                QuitXHelpSection(
                    title: "Resource values",
                    body: "Each row shows CPU or memory usage. The displayed value follows the current Sort setting. Values refresh while the popover is open."
                ),
                QuitXHelpSection(
                    title: "More actions",
                    body: "Open the three-dot menu beside the quit button to quit, force quit, restart, exclude, or reveal an app in Finder."
                ),
                QuitXHelpSection(
                    title: "Background apps",
                    body: "Show background apps temporarily from the popover menu or persistently from Settings. Some system helpers restart automatically after termination. Group Background Instances combines related processes into one row."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "quit-modes",
            category: .essentials,
            title: "Quit and Force Quit",
            symbol: "power",
            summary: "Choose graceful termination or immediate force termination.",
            sections: [
                QuitXHelpSection(
                    title: "Normal quit",
                    body: "Normal quit first asks the app to terminate. If the app does not terminate, QuitX automatically retries with force quit."
                ),
                QuitXHelpSection(
                    title: "Force quit",
                    body: "Hold Option while using a quit action to force quit immediately. You can also make Force Quit the default in Settings."
                ),
                QuitXHelpSection(
                    title: "Protect your work",
                    body: "Force quit can discard unsaved changes. Save work before quitting apps. Confirmation for larger batch quits can be enabled in Settings."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "exclude",
            category: .essentials,
            title: "Exclude Apps",
            symbol: "nosign",
            summary: "Keep important apps out of manual and automatic quit actions.",
            sections: [
                QuitXHelpSection(
                    title: "Add exclusions",
                    body: "Use Exclude in a running app's three-dot menu, or open Settings > Exclude and choose Add Apps. The installed-app picker supports multiple selections."
                ),
                QuitXHelpSection(
                    title: "Manage exclusions",
                    body: "Open Settings > Exclude to select one or more entries for removal. QuitX asks for confirmation before changing protection."
                ),
                QuitXHelpSection(
                    title: "Background apps",
                    body: "Enable Show Background Apps inside the picker when needed. This picker option is temporary and does not change the main Background Apps setting."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "auto-quit",
            category: .automation,
            title: "Auto Quit",
            symbol: "timer",
            summary: "Quit regular apps after they remain inactive for your chosen interval.",
            sections: [
                QuitXHelpSection(
                    title: "How inactivity works",
                    body: "QuitX records when each regular app was last active and checks once per minute. The frontmost app is never treated as inactive."
                ),
                QuitXHelpSection(
                    title: "Protected apps",
                    body: "Excluded apps and Finder stay protected. Never Quit Music Apps also protects configured music apps from automatic and manual batch actions."
                ),
                QuitXHelpSection(
                    title: "Configure Auto Quit",
                    body: "Open Settings > General, enable Quit Inactive Apps After, then choose minutes, hours, or days. Set it off to disable automatic quitting."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "finder-trash",
            category: .automation,
            title: "Finder and Trash",
            symbol: "folder",
            summary: "Optionally include Finder windows and Empty Trash in the app list.",
            sections: [
                QuitXHelpSection(
                    title: "Finder windows",
                    body: "The Finder item closes open Finder windows. It does not terminate Finder."
                ),
                QuitXHelpSection(
                    title: "Empty Trash",
                    body: "The Trash item permanently empties Trash without Finder confirmation. Review Trash before selecting this action."
                ),
                QuitXHelpSection(
                    title: "Enable extras",
                    body: "Open Settings > General and enable the Finder or Trash options. Each item then appears with normal app selections."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "shortcuts",
            category: .preferences,
            title: "Keyboard Shortcuts",
            symbol: "command",
            summary: "Configure global shortcuts for opening QuitX and quitting selected apps.",
            sections: [
                QuitXHelpSection(
                    title: "Available actions",
                    body: "Settings > Shortcuts provides Open QuitX, Quit All, and Force Quit All. Enable only the actions you want and record a unique key combination."
                ),
                QuitXHelpSection(
                    title: "Shortcut conflicts",
                    body: "Avoid combinations already used by macOS or another app. If a shortcut does not respond, change it and check System Settings > Privacy & Security > Input Monitoring."
                ),
                QuitXHelpSection(
                    title: "Menu commands",
                    body: "Use Command-comma for Settings and Command-question-mark for Help while QuitX is active."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "settings",
            category: .preferences,
            title: "Settings and Updates",
            symbol: "gearshape",
            summary: "Control startup, sounds, sorting, safety prompts, and updates.",
            sections: [
                QuitXHelpSection(
                    title: "General settings",
                    body: "Settings > General controls launch at login, sounds, background processes, default selection, list sorting, quit mode, Finder, Trash, and Auto Quit."
                ),
                QuitXHelpSection(
                    title: "Updates",
                    body: "Automatic update checks request the latest release metadata from GitHub. Use Check for Updates in Settings > About for a manual check."
                ),
                QuitXHelpSection(
                    title: "Reset",
                    body: "Reset All restores QuitX configuration defaults. Shortcut values are managed separately in the Shortcuts tab."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "troubleshooting",
            category: .support,
            title: "Troubleshooting",
            symbol: "wrench.and.screwdriver",
            summary: "Resolve missing apps, relaunching helpers, shortcuts, and quit failures.",
            sections: [
                QuitXHelpSection(
                    title: "App is missing",
                    body: "Clear Search. Check whether the app is excluded. Enable background apps if the process has no regular window. Reopen the QuitX popover to refresh the list."
                ),
                QuitXHelpSection(
                    title: "App returns after quitting",
                    body: "Login items, launch agents, or parent apps can restart helper processes. Disable the owning app's background or login-item setting when appropriate."
                ),
                QuitXHelpSection(
                    title: "Quit or shortcut fails",
                    body: "Save work and try Force Quit. Confirm QuitX has required macOS permissions. Restart QuitX after permission changes. Contact support with reproducible steps if the issue continues."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "privacy-support",
            category: .support,
            title: "Privacy and Support",
            symbol: "hand.raised",
            summary: "Learn what stays local and how to request help.",
            sections: [
                QuitXHelpSection(
                    title: "Local operation",
                    body: "App discovery, resource monitoring, exclusions, and quit actions run on your Mac. Settings are stored locally."
                ),
                QuitXHelpSection(
                    title: "Network access",
                    body: "QuitX contacts GitHub only for release checks or when you open a GitHub link. Contact Support opens your default mail app with version and macOS details for review before sending."
                ),
                QuitXHelpSection(
                    title: "Get support",
                    body: "Include QuitX version, macOS version, affected app, expected behavior, actual behavior, and repeatable steps. Never include passwords or private documents."
                )
            ]
        )
    ]
}

@MainActor
final class HelpViewState: ObservableObject {
    @Published var selection: String? = QuitXHelpTopic.all.first?.id
    @Published var searchText = ""
    @Published var hoveredTopicId: String?
}

struct HelpView: View {
    @StateObject private var state = HelpViewState()

    private var filteredTopics: [QuitXHelpTopic] {
        QuitXHelpTopic.all.filter { $0.matches(state.searchText) }
    }

    private var selectedTopic: QuitXHelpTopic? {
        guard let selection = state.selection else { return filteredTopics.first }
        return QuitXHelpTopic.all.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                sidebar

                Divider()

                detail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 740, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background {
            QuitXTheme.windowBackground
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onChange(of: state.searchText) {
            guard !filteredTopics.contains(where: { $0.id == state.selection }) else { return }
            state.selection = filteredTopics.first?.id
        }
    }

    private var header: some View {
        Text(selectedTopic?.title ?? "Help")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(QuitXTheme.windowBackground)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            if filteredTopics.isEmpty {
                emptySearch
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                topicList
            }
        }
        .frame(width: 235)
        .frame(maxHeight: .infinity)
        .background(QuitXTheme.windowBackground)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            TextField("Search Help...", text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .disableInitialFocus()

            if !state.searchText.isEmpty {
                Button {
                    state.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var emptySearch: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(Color.secondary)
            Text("No Results")
                .font(.system(size: 13, weight: .semibold))
            Text("Try another search.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)
        }
    }

    private var topicList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(QuitXHelpCategory.allCases) { category in
                    let topics = filteredTopics.filter { $0.category == category }
                    if !topics.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 2)

                            ForEach(topics) { topic in
                                topicRow(topic)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func topicRow(_ topic: QuitXHelpTopic) -> some View {
        let isSelected = state.selection == topic.id
        return Button {
            state.selection = topic.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: topic.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? QuitXTheme.accent : Color.secondary)
                    .frame(width: 18)

                Text(topic.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? QuitXTheme.accent.opacity(0.18) : (state.hoveredTopicId == topic.id ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                state.hoveredTopicId = topic.id
            } else if state.hoveredTopicId == topic.id {
                state.hoveredTopicId = nil
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let topic = selectedTopic {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        contentHeader(for: topic)

                        ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                            sectionView(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                footerLinks(for: topic)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(QuitXTheme.windowBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(topic.id)
            .background(QuitXTheme.windowBackground)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.secondary)
                Text("Select a Help Topic")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.windowBackground)
        }
    }

    private func contentHeader(for topic: QuitXHelpTopic) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: topic.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(QuitXTheme.accent)
                .frame(width: 28, height: 28)
                .background(QuitXTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(topic.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionView(_ section: QuitXHelpSection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            Text(section.body)
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.88))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(section.bullets, id: \.self) { bullet in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                    Text(bullet)
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.primary.opacity(0.88))
            }
        }
    }

    @ViewBuilder
    private func footerLinks(for topic: QuitXHelpTopic) -> some View {
        HStack(spacing: 8) {
            switch topic.id {
            case "quick-start":
                Button("Welcome Guide") {
                    WelcomeWindowController.shared.show()
                }
                Button("Open Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            case "app-list":
                Button("General Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }
                Button("Manage Exclusions") {
                    SettingsWindowController.shared.show(tab: .exclude)
                }

            case "quit-modes":
                Button("Quit Mode Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }
                Button("Shortcuts") {
                    SettingsWindowController.shared.show(tab: .shortcuts)
                }

            case "exclude":
                Button("Exclude Settings") {
                    SettingsWindowController.shared.show(tab: .exclude)
                }
                Button("Add Apps") {
                    ExcludeAppPickerWindowController.shared.show()
                }

            case "auto-quit":
                Button("Auto Quit Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            case "finder-trash":
                Button("Finder & Trash Settings") {
                    SettingsWindowController.shared.show(tab: .general)
                }

            case "shortcuts":
                Button("Shortcuts Settings") {
                    SettingsWindowController.shared.show(tab: .shortcuts)
                }

            case "settings":
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }
                Button("About & Updates") {
                    SettingsWindowController.shared.show(tab: .about)
                }

            case "troubleshooting":
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }
                Button("Contact Support") {
                    guard let url = QuitXConstants.contactURL() else { return }
                    NSWorkspace.shared.open(url)
                }

            case "privacy-support":
                Button("About") {
                    SettingsWindowController.shared.show(tab: .about)
                }
                Button("Contact Support") {
                    guard let url = QuitXConstants.contactURL() else { return }
                    NSWorkspace.shared.open(url)
                }

            default:
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }
            }

            Spacer()

            if topic.id != "troubleshooting" && topic.id != "privacy-support" {
                Button("Contact Support") {
                    guard let url = QuitXConstants.contactURL() else { return }
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Report an Issue") {
                NSWorkspace.shared.open(QuitXConstants.githubIssuesURL)
            }
        }
        .controlSize(.small)
    }
}
