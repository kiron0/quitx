import AppKit
import SwiftUI

enum QuitXHelpCategory: String, CaseIterable, Identifiable, Sendable {
    case essentials = "Essentials"
    case automation = "Automation"
    case preferences = "Settings"
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
    let searchableContent: String

    init(
        id: String,
        category: QuitXHelpCategory,
        title: String,
        symbol: String,
        summary: String,
        sections: [QuitXHelpSection]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.symbol = symbol
        self.summary = summary
        self.sections = sections
        self.searchableContent = ([title, summary] + sections.flatMap { [$0.title, $0.body] + $0.bullets })
            .joined(separator: " ")
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return searchableContent.localizedCaseInsensitiveContains(trimmed)
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
                    body: "Select each app checkbox, or use the checkbox beside Search to select or deselect the visible list. Configure Select apps by default in Settings > Advanced or the welcome guide."
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
                    body: "Each row shows live CPU or memory usage. The displayed value follows the current Sort setting. Values refresh continuously while the popover is open."
                ),
                QuitXHelpSection(
                    title: "Row actions",
                    body: "Open the three-dot menu beside the quit button to quit, force quit, restart, exclude, reveal an app in Finder, or uninstall it."
                ),
                QuitXHelpSection(
                    title: "Uninstall apps",
                    body: "Choose Uninstall in an app row's menu to open the uninstaller, or Uninstall Apps in the gear menu to pick several installed apps at once. It finds each app and the files it left in your Library: application support, caches, preferences, containers, saved state, logs, and launch items. Everything starts selected; uncheck anything you want to keep, then click Remove and confirm. Hover a file to show it in Finder or remove only that file. QuitX force quits the app first, so save your work, then moves the files to the Trash. You can put files back until you empty the Trash. Apple apps, parts of macOS, helpers inside other apps, and QuitX itself can't be uninstalled. Your Documents and Desktop are never touched."
                ),
                QuitXHelpSection(
                    title: "Quit Other Apps",
                    body: "Choose Quit Other Apps in any app row's menu to terminate all running apps except that specific app. Honoring your quit-all confirmation preference."
                ),
                QuitXHelpSection(
                    title: "Quit timers",
                    body: "Choose Quit In from the row menu to schedule graceful termination after 15, 30, or 60 minutes. Timers persist across app restarts and can be cancelled anytime from the same menu."
                ),
                QuitXHelpSection(
                    title: "Multiple instances and profiles",
                    body: "An app that runs more than once (for example Chrome with a separate data folder) shows as one row. Quit, restart, and Quit In act on every instance; restart brings each instance back with its own profile. To close only part of an app, open Windows in the row menu, shown when the app has more than one window: close single windows, or close one Chrome profile's windows. With Quit When Last Window Closes on, the app quits only when none of its instances has a window left. It then quits completely, every instance and the background processes it started, exactly like Quit in the list. Windows needs Accessibility access, granted in Automation settings."
                ),
                QuitXHelpSection(
                    title: "Background apps",
                    body: "Show background apps temporarily from the popover gear menu or persistently from Settings > Advanced. Group Background Instances combines related helper processes into one line."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "recently-quit",
            category: .essentials,
            title: "Recently Quit and Reopen",
            symbol: "arrow.clockwise.circle",
            summary: "Quickly relaunch apps you previously closed from the Reopen menu.",
            sections: [
                QuitXHelpSection(
                    title: "Relaunch recent apps",
                    body: "Click the gear menu in the bottom-right corner and hover over Reopen Recently Quit to view recently quit apps (up to 5). Click any app to launch it immediately."
                ),
                QuitXHelpSection(
                    title: "Automatic history",
                    body: "QuitX automatically records apps closed through single quits, batch quits, auto-quit, timers, or sleep actions. The list stays deduplicated with the freshest apps at the top."
                ),
                QuitXHelpSection(
                    title: "Clear history",
                    body: "Choose Clear List at the bottom of the Reopen Recently Quit menu whenever you want to wipe the recent history."
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
                    body: "Normal quit asks the app to terminate and waits for it to close gracefully. QuitX never forces termination on its own."
                ),
                QuitXHelpSection(
                    title: "Force quit",
                    body: "Hold Option while clicking any quit button to force quit immediately. You can also make Force Quit the default in Settings > General."
                ),
                QuitXHelpSection(
                    title: "Safety net confirmations",
                    body: "Enable Confirm batch quit or Confirm single app quit & restart in Settings to display an 'Are you sure?' confirmation dialog before closing apps."
                ),
                QuitXHelpSection(
                    title: "Protect your work",
                    body: "Force quit can discard unsaved changes. Always save your active files and documents before terminating apps."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "ports",
            category: .essentials,
            title: "Ports",
            symbol: "network",
            summary: "Find and free ports held by dev servers, databases and Docker containers.",
            sections: [
                QuitXHelpSection(
                    title: "Turn it on",
                    body: "Enable port killing in Settings > Ports. An Apps and Ports switch then appears above the main button. QuitX remembers which one you used last. Turn it off and the Ports tab and its settings go away."
                ),
                QuitXHelpSection(
                    title: "The list",
                    body: "Every TCP listener (and UDP if you turn it on) with its port, app, Docker container, exposure (Local, LAN or Public), memory and CPU. The list refreshes on its own every few seconds while it's open; pick the interval in Settings > Ports. Search by port, app, command or folder, and group by project folder, Docker container or process tree."
                ),
                QuitXHelpSection(
                    title: "Kill ports",
                    body: "Select ports and click Kill, or use the power button on a row. Kill sends SIGTERM and escalates only if the listener won't let go; hold ⌥ (Option) or choose Force kill in Settings to send SIGKILL. Dev servers are stopped with their whole process tree, Homebrew services through brew services, and Docker ports by stopping the container. macOS services and apps with windows are protected and can't be killed here."
                ),
                QuitXHelpSection(
                    title: "Row menu",
                    body: "The ••• menu shows details, traces the process tree, interrupts with SIGINT, excludes it, copies the port, PID or command, opens Terminal in its folder, and opens it in your browser."
                ),
                QuitXHelpSection(
                    title: "Menu bar count and diagnostics",
                    body: "Show listening port count adds the number of listening ports to the menu bar stats, next to CPU, memory and battery, kept current in the background. Click it to open the Ports tab. Settings > Exclude has a Ports tab while port killing is on: Add Ports… excludes ports picked from the ones listening now or typed by hand, like 3000, 5173 or 8000-8010. The gear menu can export redacted diagnostics or copy recent listener history; tokens and passwords in commands are removed."
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
                ),
                QuitXHelpSection(
                    title: "System protections",
                    body: "QuitX, Finder, and configured music apps are protected automatically. Excluded apps never appear in batch quit selections or auto-quit operations."
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
                    title: "Inactivity detection",
                    body: "QuitX records when each regular app was last active and checks once per minute. The frontmost app is never treated as inactive."
                ),
                QuitXHelpSection(
                    title: "Configure global interval",
                    body: "Open Settings > Automation, enable Quit Inactive Apps After, then choose minutes, hours, or days. Turn it off to disable automatic quitting."
                ),
                QuitXHelpSection(
                    title: "Per-app rules",
                    body: "Open the three-dot menu on any app row, choose Auto-quit, then pick a timeout or Never. A per-app rule overrides the global interval. Use Default returns the app to the global setting."
                ),
                QuitXHelpSection(
                    title: "Sleep quit schedule",
                    body: "Settings > Automation offers unattended quitting: automatically and gracefully terminate safe apps when your Mac sleeps. Configure your custom active hours with start and end time pickers (default 12 AM to 6 AM), and toggle between 12-hour AM/PM and 24-hour display formats. Outside the range, sleep leaves apps running."
                ),
                QuitXHelpSection(
                    title: "Quit when the last window closes",
                    body: "In Settings > Automation, grant Accessibility, then enable Quit app when its last window closes. QuitX never asks at launch. Once allowed, it directly force-quits regular apps after their last window closes via the red close button (x) or ⌘W. Minimized windows, hidden apps, and windows on other Spaces do not count as closed. Remove Access disables the option and opens macOS Accessibility settings for native permission removal. Finder, background daemons, music apps, and excluded apps remain protected. Quit apps appear in Recently Quit."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "menu-battery",
            category: .automation,
            title: "Menu Bar Stats and Battery",
            symbol: "battery.100.bolt",
            summary: "Monitor live CPU, memory, GPU, and battery data in the menu bar and detail panel.",
            sections: [
                QuitXHelpSection(
                    title: "Menu bar stats readout",
                    body: "Enable Show stats in menu bar in Settings > General, then choose CPU, Memory, GPU, and Battery independently. Configure Style format with Icon (SF Symbols) or Text (CPU / MEM / GPU prefixes), and Memory format with Gigabytes (GB) or Percentage (%). Choose how often the readout updates under Refresh, from every second to every 10 seconds. Battery options appear only on Macs with a battery, and GPU only when macOS reports GPU statistics."
                ),
                QuitXHelpSection(
                    title: "Stats detail panel",
                    body: "Click a menu bar stat to open its detail panel. CPU and memory show live breakdowns and top processes, GPU shows utilization and memory, and battery shows power source, charge time, power draw, voltage, temperature, capacity, and cycle count when macOS reports them. Click the stats item again, click anywhere outside, or press Esc to dismiss it."
                ),
                QuitXHelpSection(
                    title: "Low Power Mode",
                    body: "When macOS Low Power Mode is on, QuitX slows down by itself: menu bar stats update at most every 5 seconds, and live CPU and memory checks every 10 seconds. Turn Low Power Mode off and the normal pace comes back. There is nothing to set up."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "system-health",
            category: .automation,
            title: "Resource Hogs and Memory Pressure",
            symbol: "flame.fill",
            summary: "Identify runaway processes, receive CPU hog alerts, and manage memory pressure.",
            sections: [
                QuitXHelpSection(
                    title: "CPU hog warnings",
                    body: "Enable Warn & rescue CPU hogs in Settings > Automation and dial in your own CPU percent with the steppers. QuitX arms for 15 seconds after you enable the setting, then watches whole-system CPU load. Smart Rescue fires only when load stays over your limit for 15 seconds: it sends a notification and force quits inactive windowed apps only — never your frontmost app. Apps genuinely burning CPU also display a flame badge in the list. Enabling the setting never triggers an instant quit."
                ),
                QuitXHelpSection(
                    title: "Memory pressure cleaning",
                    body: "Enable Rescue inactive on memory pressure in Settings > Automation and dial in your own gigabyte limit with the stepper, capped at this Mac's total memory. When macOS reports pressure and any app exceeds it, Smart Rescue force quits inactive apps only. Quit apps land in Recently Quit, so you can reopen anything from the gear menu."
                ),
                QuitXHelpSection(
                    title: "Unresponsive app badges",
                    body: "A red warning triangle marks apps that resisted or ignored a previous graceful quit request, signaling that Force Quit is needed."
                ),
                QuitXHelpSection(
                    title: "Safety guards",
                    body: "Excluded apps, music apps, system helpers, and apps marked with 'Never' rule are never closed by automated resource managers."
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
                    body: "The Finder item closes open Finder windows in one click. It does not terminate Finder itself."
                ),
                QuitXHelpSection(
                    title: "Empty Trash",
                    body: "The Trash item permanently empties Trash without Finder confirmation. Review Trash before selecting this action."
                ),
                QuitXHelpSection(
                    title: "Enable extras",
                    body: "Open Settings > Advanced and toggle Include Finder Windows in list or Include Empty Trash in list."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "shortcuts",
            category: .preferences,
            title: "Keyboard Shortcuts",
            symbol: "command",
            summary: "Configure global shortcuts for opening QuitX, quitting all apps, and force quitting all apps.",
            sections: [
                QuitXHelpSection(
                    title: "Available global shortcuts",
                    body: "Settings > Shortcuts provides customizable global hotkeys for Open QuitX, Quit All, and Force Quit All. Record any unique key combination."
                ),
                QuitXHelpSection(
                    title: "In-app key commands",
                    body: "While QuitX is open: use Cmd-A to toggle select all, Cmd-, for Settings, Cmd-? for Help, Cmd-I for About, Esc to cancel confirmation or close, and Return to confirm."
                ),
                QuitXHelpSection(
                    title: "Shortcut conflicts",
                    body: "Avoid hotkeys already registered by macOS. If a shortcut does not trigger, check System Settings > Privacy & Security > Input Monitoring."
                )
            ]
        ),
        QuitXHelpTopic(
            id: "settings",
            category: .preferences,
            title: "Settings and Updates",
            symbol: "gearshape",
            summary: "Explore all Settings tabs, app configuration, and verified in-app updates.",
            sections: [
                QuitXHelpSection(
                    title: "General & Advanced tabs",
                    body: "Settings > General controls startup, sounds, menu bar stats for CPU, memory, GPU, and battery, macOS 26 Liquid Glass vs Classic appearance theme, sort order, and defaults. Settings > Automation manages sleep scheduling, quit-on-last-window-close, health rescue thresholds, and Auto Quit. Settings > Advanced manages background apps, music protection, default selection, tips, confirmations, and Finder/Trash."
                ),
                QuitXHelpSection(
                    title: "Exclude & Shortcuts tabs",
                    body: "Settings > Exclude manages your protected apps list. Settings > Shortcuts allows recording global hotkeys with conflict checks."
                ),
                QuitXHelpSection(
                    title: "About & Updates",
                    body: "Settings > About shows current app version, links to contact developer support, and includes Check for Updates. Updates download, verify checksums and signatures, and install automatically."
                ),
                QuitXHelpSection(
                    title: "Reset defaults",
                    body: "Click Reset All in Settings > General to restore QuitX configuration defaults to their initial clean state."
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
                    body: "Clear the Search box. Verify the app is not in Excluded apps. Enable View background apps in Settings > Advanced if the process has no regular window."
                ),
                QuitXHelpSection(
                    title: "App returns after quitting",
                    body: "Login items, launch agents, or parent apps can automatically restart background helpers. Check System Settings > General > Login Items."
                ),
                QuitXHelpSection(
                    title: "Badges and indicators",
                    body: "A flame badge indicates CPU usage over your chosen limit. A red triangle indicates an app that resisted normal quit — hold Option to force quit it."
                ),
                QuitXHelpSection(
                    title: "Quit or shortcut fails",
                    body: "Check macOS permissions under System Settings > Privacy & Security > Accessibility and Input Monitoring. Restart QuitX after granting permissions."
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
                    title: "100% local operation",
                    body: "App discovery, resource monitoring, exclusions, rules, and quit actions run entirely locally on your Mac. No usage tracking or telemetry is collected."
                ),
                QuitXHelpSection(
                    title: "Network access",
                    body: "QuitX only connects to the internet to check for software updates from official GitHub releases and download cryptographically verified packages."
                ),
                QuitXHelpSection(
                    title: "Contact support",
                    body: "Click Contact in Settings > About or open Help to get assistance. Emails open in your default mail app with your app version and macOS version prefilled."
                )
            ]
        )
    ]

    static let byCategory: [(category: QuitXHelpCategory, topics: [QuitXHelpTopic])] = {
        QuitXHelpCategory.allCases.compactMap { cat in
            let matching = all.filter { $0.category == cat }
            return matching.isEmpty ? nil : (category: cat, topics: matching)
        }
    }()
}

@MainActor
final class HelpViewState: ObservableObject {
    @Published var selection: String? = QuitXHelpTopic.all.first?.id
    @Published var searchText = ""
    @Published var hoveredTopicId: String?
}

struct HelpView: View {
    @StateObject private var state = HelpViewState()
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared

    private var filteredTopics: [QuitXHelpTopic] {
        QuitXHelpTopic.all.filter { $0.matches(state.searchText) }
    }

    private var selectedTopic: QuitXHelpTopic? {
        guard let selection = state.selection else { return filteredTopics.first }
        return QuitXHelpTopic.all.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            detail
        }
        .frame(minWidth: 740, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onChange(of: state.searchText) {
            guard !filteredTopics.contains(where: { $0.id == state.selection }) else { return }
            state.selection = filteredTopics.first?.id
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            stickySearchHeader

            topicList
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(QuitXTheme.cardBackground)
    }

    private var stickySearchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(state.searchText.isEmpty ? Color.secondary.opacity(0.85) : QuitXTheme.accent)

                TextField("Search help…", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()

                if !state.searchText.isEmpty {
                    Button {
                        state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(SearchFieldGlassBackground(isFocused: !state.searchText.isEmpty))
            .padding(.horizontal, 10)
            .padding(.top, 38)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.35)
        }
        .background(QuitXTheme.cardBackground)
    }

    private var topicList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 14) {
                let trimmedQuery = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedQuery.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SEARCH RESULTS (\(filteredTopics.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)

                        if filteredTopics.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                Text("No matching topics")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(filteredTopics) { topic in
                                topicRow(topic)
                            }
                        }
                    }
                } else {
                    ForEach(QuitXHelpTopic.byCategory, id: \.category) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 2)

                            ForEach(section.topics) { topic in
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
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? QuitXTheme.accent.opacity(0.18) : (state.hoveredTopicId == topic.id ? Color.primary.opacity(0.05) : Color.clear))
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
                    VStack(alignment: .leading, spacing: 20) {
                        contentHeader(for: topic)

                        ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                            sectionCard(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footerLinks(for: topic)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(QuitXTheme.paneBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(topic.id)
            .background(QuitXTheme.paneBackground)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.secondary)
                Text("Select a Help Topic")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.paneBackground)
        }
    }

    private func contentHeader(for topic: QuitXHelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(topic.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)

            Text(topic.summary)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func sectionCard(_ section: QuitXHelpSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text(section.body)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !section.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(section.bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(Color.secondary)
                                Text(bullet)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.88))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func footerLinks(for topic: QuitXHelpTopic) -> some View {
        HStack(spacing: 8) {
            switch topic.id {
            case "quick-start":
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
                    SettingsWindowController.shared.show(tab: .automation)
                }

            case "finder-trash":
                Button("Finder & Trash Settings") {
                    SettingsWindowController.shared.show(tab: .advanced)
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
                Button("About QuitX") {
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
                NSWorkspace.shared.open(QuitXConstants.issuesURL)
            }
        }
        .controlSize(.small)
    }
}
