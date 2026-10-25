import AppKit
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var navigation: SettingsNavigationModel
    @EnvironmentObject private var configStore: ConfigStore

    private var trimmedQuery: String {
        navigation.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [SettingsTab] {
        SettingsTab.allCases.filter { $0.matches(navigation.searchText) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchHeader

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if trimmedQuery.isEmpty {
                        ForEach(SettingsTab.byCategory, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                if !group.category.rawValue.isEmpty {
                                    sectionTitle(group.category.rawValue)
                                }
                                ForEach(group.tabs) { tab in
                                    sidebarRow(tab)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            sectionTitle("Search Results (\(searchResults.count))")
                            if searchResults.isEmpty {
                                VStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.secondary.opacity(0.5))
                                    Text("No matching settings")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                            } else {
                                ForEach(searchResults) { tab in
                                    sidebarRow(tab)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .frame(width: SettingsTab.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(QuitXTheme.cardBackground)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
    }

    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(navigation.searchText.isEmpty ? Color.secondary.opacity(0.85) : QuitXTheme.accent)

                TextField("Search settings…", text: $navigation.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .disableInitialFocus()
                    .onSubmit {
                        if let first = searchResults.first { navigation.select(first) }
                    }

                if !navigation.searchText.isEmpty {
                    Button {
                        navigation.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(SearchFieldGlassBackground(isFocused: !navigation.searchText.isEmpty))
            .padding(.horizontal, 10)
            .padding(.top, 38)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.35)
        }
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        let isSelected = navigation.selection == tab
        return Button {
            navigation.select(tab)
        } label: {
            HStack(spacing: 8) {
                Group {
                    if tab == .marquee {
                        MarqueeIconView(size: 16)
                    } else {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isSelected ? QuitXTheme.accent : Color.secondary)
                    }
                }
                .frame(width: 18)

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if tab == .ports && !configStore.config.portsEnabled {
                    Text("Off")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? QuitXTheme.accent.opacity(0.18) : (navigation.hoveredTab == tab ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovering in
            if hovering {
                navigation.hoveredTab = tab
            } else if navigation.hoveredTab == tab {
                navigation.hoveredTab = nil
            }
        }
    }

    private var detail: some View {
        let tab = navigation.selection
        return VStack(alignment: .leading, spacing: 16) {
            header(for: tab)
            page(for: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, SettingsTab.detailHorizontalPadding)
        .padding(.top, 40)
        .padding(.bottom, tab == .exclude ? 20 : 0)
        .frame(width: SettingsTab.detailWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(QuitXTheme.paneBackground)
        .id(tab)
    }

    private func header(for tab: SettingsTab) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tab.headerTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)

                Text(tab.headerSummary)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func page(for tab: SettingsTab) -> some View {
        switch tab {
        case .overview:
            SettingsOverviewView(navigation: navigation)
        case .marquee:
            MarqueePromoView()
        case .general:
            scrolling(GeneralTabView())
        case .automation:
            scrolling(AutomationTabView())
        case .advanced:
            scrolling(AdvancedTabView())
        case .ports:
            scrolling(PortsTabView())
        case .exclude:
            ExcludeTabView()
        case .shortcuts:
            scrolling(ShortcutsTabView())
        case .about:
            scrolling(AboutTabView())
        }
    }

    private func scrolling<Content: View>(_ content: Content) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content
                .padding(.bottom, 28)
                .frame(width: SettingsTab.contentWidth, alignment: .topLeading)
        }
    }
}
