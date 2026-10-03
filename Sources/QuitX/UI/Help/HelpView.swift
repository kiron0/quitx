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
                    body: "Use Command-comma for Settings and Command-question-mark for QuitX Help while QuitX is active."
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
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 440)
        .background(QuitXTheme.windowBackground)
        .onChange(of: state.searchText) {
            guard !filteredTopics.contains(where: { $0.id == state.selection }) else { return }
            state.selection = filteredTopics.first?.id
        }
    }

    private var sidebar: some View {
        List(selection: $state.selection) {
            ForEach(QuitXHelpCategory.allCases) { category in
                let topics = filteredTopics.filter { $0.category == category }
                if !topics.isEmpty {
                    Section(category.rawValue) {
                        ForEach(topics) { topic in
                            Label(topic.title, systemImage: topic.symbol)
                                .tag(topic.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("QuitX Help")
        .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 285)
        .searchable(text: $state.searchText, placement: .sidebar, prompt: "Search Help")
        .overlay {
            if filteredTopics.isEmpty {
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
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let topic = selectedTopic {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: topic.symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(QuitXTheme.accent)
                            .frame(width: 42, height: 42)
                            .background(QuitXTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(topic.title)
                                .font(.system(size: 24, weight: .bold))
                            Text(topic.summary)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(section.body)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primary.opacity(0.88))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•")
                                    Text(bullet)
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(Color.primary.opacity(0.88))
                            }
                        }
                    }

                    supportActions
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(32)
            }
            .id(topic.id)
            .background(QuitXTheme.windowBackground)
            .navigationTitle(topic.title)
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

    private var supportActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Button("Open Settings") {
                    SettingsWindowController.shared.show()
                }

                Button("Welcome Guide") {
                    WelcomeWindowController.shared.show()
                }

                Spacer()

                Button("Contact Support") {
                    guard let url = QuitXConstants.contactURL() else { return }
                    NSWorkspace.shared.open(url)
                }

                Button("Report an Issue") {
                    NSWorkspace.shared.open(QuitXConstants.githubIssuesURL)
                }
            }
            .controlSize(.small)
        }
        .padding(.top, 4)
    }
}
