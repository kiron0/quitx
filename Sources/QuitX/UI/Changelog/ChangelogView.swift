import AppKit
import SwiftUI

extension ReleaseChangelog {
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if version.localizedCaseInsensitiveContains(trimmed) { return true }
        if summary.localizedCaseInsensitiveContains(trimmed) { return true }
        for section in sections {
            if section.title.localizedCaseInsensitiveContains(trimmed) { return true }
            for item in section.items {
                if item.localizedCaseInsensitiveContains(trimmed) { return true }
            }
        }
        return false
    }
}

@MainActor
final class ChangelogViewState: ObservableObject {
    @Published var releases: [ReleaseChangelog] = []
    @Published var selection: String?
    @Published var searchText = ""
    @Published var hoveredVersion: String?

    func load(initialVersion: String?, currentVersion: String) {
        let loaded = ChangelogProvider.releases()
        self.releases = loaded
        if let initial = initialVersion, loaded.contains(where: { $0.version == initial }) {
            self.selection = initial
        } else if let match = loaded.first(where: { $0.version == currentVersion }) {
            self.selection = match.version
        } else {
            self.selection = loaded.first?.version ?? currentVersion
        }
    }
}

struct ChangelogView: View {
    let initialVersion: String?
    let onDismiss: (() -> Void)?

    @StateObject private var state = ChangelogViewState()
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared

    private let currentVersion = UpdateChecker.shared.currentVersion

    init(initialVersion: String? = nil, onDismiss: (() -> Void)? = nil) {
        self.initialVersion = initialVersion
        self.onDismiss = onDismiss
    }

    private var filteredReleases: [ReleaseChangelog] {
        state.releases.filter { $0.matches(state.searchText) }
    }

    private var selectedRelease: ReleaseChangelog? {
        guard let selection = state.selection else { return filteredReleases.first }
        return state.releases.first { $0.version == selection }
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
        .onAppear {
            state.load(initialVersion: initialVersion, currentVersion: currentVersion)
        }
        .onChange(of: state.searchText) {
            guard !filteredReleases.contains(where: { $0.version == state.selection }) else { return }
            state.selection = filteredReleases.first?.version
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            stickySearchHeader

            topicList
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(width: 230)
        .frame(maxHeight: .infinity)
        .background(QuitXTheme.cardBackground)
    }

    private var stickySearchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(state.searchText.isEmpty ? Color.secondary.opacity(0.85) : QuitXTheme.accent)

                TextField("Search versions…", text: $state.searchText)
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
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        state.searchText.isEmpty
                            ? Color.primary.opacity(0.09)
                            : QuitXTheme.accent.opacity(0.55),
                        lineWidth: 0.8
                    )
            )
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
                        Text("SEARCH RESULTS (\(filteredReleases.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 2)

                        if filteredReleases.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                Text("No matching versions")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            ForEach(filteredReleases) { release in
                                releaseRow(release)
                            }
                        }
                    }
                } else {
                    if let latest = state.releases.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LATEST RELEASE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 2)

                            releaseRow(latest)
                        }
                    }

                    if state.releases.count > 1 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PREVIOUS RELEASES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 2)

                            ForEach(state.releases.dropFirst()) { release in
                                releaseRow(release)
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

    private func releaseRow(_ release: ReleaseChangelog) -> some View {
        let isSelected = state.selection == release.version
        let isCurrent = release.version == currentVersion
        let symbol = isCurrent ? "sparkles" : "clock.arrow.circlepath"

        return Button {
            state.selection = release.version
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? QuitXTheme.accent : (isCurrent ? QuitXTheme.accent : Color.secondary))
                    .frame(width: 14)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("v\(release.version)")
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(Color.primary)

                        Spacer(minLength: 0)

                        if isCurrent {
                            Text("Current")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(QuitXTheme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(QuitXTheme.accent.opacity(0.18))
                                )
                        }
                    }

                    if !release.summary.isEmpty {
                        Text(release.summary)
                            .font(.system(size: 10.5))
                            .foregroundStyle(isSelected ? Color.primary.opacity(0.85) : Color.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? QuitXTheme.accent.opacity(0.18) : (state.hoveredVersion == release.version ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered {
                state.hoveredVersion = release.version
            } else if state.hoveredVersion == release.version {
                state.hoveredVersion = nil
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let release = selectedRelease {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        contentHeader(for: release)

                        ForEach(release.sections) { section in
                            sectionCard(section)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footerLinks(for: release)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(QuitXTheme.paneBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(release.version)
            .background(QuitXTheme.paneBackground)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.secondary)
                Text("Select a Version")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.paneBackground)
        }
    }

    private func contentHeader(for release: ReleaseChangelog) -> some View {
        HStack(alignment: .center, spacing: 12) {
            QuitXAppIconView(size: 38, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    Text("Version \(release.version)")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if release.version == currentVersion {
                        Text("Current")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(QuitXTheme.accent)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(QuitXTheme.accent.opacity(0.18))
                            )
                    }
                }

                Text(release.summary.isEmpty ? (release.version == currentVersion ? "Installed and running on your Mac." : "Release notes and improvements.") : release.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 38)
        .padding(.bottom, 2)
    }

    static func renderedItem(_ item: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: item, options: options)) ?? AttributedString(item)
    }

    private func sectionCard(_ section: ChangelogSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(section.items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("•")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(QuitXTheme.accent.opacity(0.85))

                        Text(Self.renderedItem(item))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.primary.opacity(0.92))
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
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
    private func footerLinks(for release: ReleaseChangelog) -> some View {
        HStack(spacing: 8) {
            Button("Check for Updates") {
                Task {
                    await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                }
            }

            Button("All Releases") {
                if let url = URL(string: "https://github.com/kiron0/quitx/releases") {
                    NSWorkspace.shared.open(url)
                }
            }

            Spacer()

            Button("Report an Issue") {
                NSWorkspace.shared.open(QuitXConstants.issuesURL)
            }
        }
        .controlSize(.small)
    }
}
