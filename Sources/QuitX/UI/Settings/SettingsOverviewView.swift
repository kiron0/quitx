import AppKit
import SwiftUI

enum SettingsFeature: String, CaseIterable, Identifiable {
    case openAtLogin
    case menuBarStats
    case appearance
    case sounds
    case updates
    case quitMode
    case shortcuts
    case quitOnSleep
    case lastWindow
    case rescue
    case autoQuit
    case backgroundApps
    case musicProtection
    case confirmations
    case finderTrash
    case exclude
    case ports
    case uninstallApps
    case leftovers
    case systemJunk
    case userCache
    case mailFiles
    case trashBins
    case largeOldFiles
    case aiApps
    case xcodeJunk
    case brewCache
    case nodeCache
    case dockerCache

    var id: String { rawValue }

    var tab: SettingsTab {
        switch self {
        case .openAtLogin, .menuBarStats, .appearance, .sounds, .updates, .quitMode: return .general
        case .shortcuts: return .shortcuts
        case .quitOnSleep, .lastWindow, .rescue, .autoQuit: return .automation
        case .backgroundApps, .musicProtection, .confirmations, .finderTrash: return .advanced
        case .exclude: return .exclude
        case .ports: return .ports
        case .uninstallApps: return .uninstallApps
        case .leftovers: return .leftovers
        case .systemJunk: return .systemJunk
        case .userCache: return .userCache
        case .mailFiles: return .mailFiles
        case .trashBins: return .trashBins
        case .largeOldFiles: return .largeOldFiles
        case .aiApps: return .aiApps
        case .xcodeJunk: return .xcodeJunk
        case .brewCache: return .brewCache
        case .nodeCache: return .nodeCache
        case .dockerCache: return .dockerCache
        }
    }

    var title: String {
        switch self {
        case .openAtLogin: return "Open at Login"
        case .menuBarStats: return "Menu Bar Stats"
        case .appearance: return "Appearance"
        case .sounds: return "Sounds"
        case .updates: return "Updates"
        case .quitMode: return "Quit or Force Quit"
        case .shortcuts: return "Global Shortcuts"
        case .quitOnSleep: return "Quit on Sleep"
        case .lastWindow: return "Last Window Closes"
        case .rescue: return "CPU & Memory Rescue"
        case .autoQuit: return "Auto Quit"
        case .backgroundApps: return "Background Apps"
        case .musicProtection: return "Music Protection"
        case .confirmations: return "Confirmations"
        case .finderTrash: return "Finder & Trash"
        case .exclude: return "Exclude List"
        case .ports: return "Port Killing"
        case .uninstallApps: return "Uninstall Apps"
        case .leftovers: return "Leftovers"
        case .systemJunk: return "System Junk"
        case .userCache: return "User Cache"
        case .mailFiles: return "Mail Files"
        case .trashBins: return "Trash Bins"
        case .largeOldFiles: return "Large & Old Files"
        case .aiApps: return "AI Apps"
        case .xcodeJunk: return "Xcode Junk"
        case .brewCache: return "Brew Cache"
        case .nodeCache: return "Node Cache"
        case .dockerCache: return "Docker Cache"
        }
    }

    var detail: String {
        switch self {
        case .openAtLogin: return "Start QuitX quietly every time you log in."
        case .menuBarStats: return "Live CPU, memory, GPU and battery right in the menu bar."
        case .appearance: return "Solid Classic or translucent Liquid Glass on macOS 26."
        case .sounds: return "A short arcade laser every time an app goes."
        case .updates: return "New versions straight from GitHub, verified before install."
        case .quitMode: return "Quit politely by default, or make Force Quit the default."
        case .shortcuts: return "Open QuitX, Quit All or Force Quit All from anywhere."
        case .quitOnSleep: return "Close apps left open when your Mac wakes from sleep in the hours you pick."
        case .lastWindow: return "Quit an app as soon as you close its last window."
        case .rescue: return "Get a heads-up when CPU or memory stays too high."
        case .autoQuit: return "Quit apps you haven't touched in a while."
        case .backgroundApps: return "Show helpers and agents that never appear in the Dock."
        case .musicProtection: return "Keep music playing through every quit."
        case .confirmations: return "Ask before Quit All, single quits and restarts."
        case .finderTrash: return "Add Finder windows and Empty Trash to the list."
        case .exclude: return "Apps and ports that QuitX never touches."
        case .ports: return "Free ports held by dev servers, databases and Docker."
        case .uninstallApps: return "Remove apps and every related file from one settings page."
        case .leftovers: return "Find files left behind by apps you already removed."
        case .systemJunk: return "Review system caches, logs and temporary files."
        case .userCache: return "Review regenerable cache data from your apps."
        case .mailFiles: return "Find attachments downloaded by Mail."
        case .trashBins: return "Review items already waiting in the Trash."
        case .largeOldFiles: return "Find large and old files in your personal folders."
        case .aiApps: return "Clean Ollama and LM Studio caches and logs."
        case .xcodeJunk: return "Clean DerivedData, simulator and Swift package caches."
        case .brewCache: return "Clean Homebrew downloads and logs."
        case .nodeCache: return "Clean npm, Yarn and pnpm caches."
        case .dockerCache: return "Clean Docker Desktop caches and logs safely."
        }
    }

    var symbol: String {
        switch self {
        case .openAtLogin: return "power.circle"
        case .menuBarStats: return "chart.bar.xaxis"
        case .appearance: return "paintpalette"
        case .sounds: return "speaker.wave.2"
        case .updates: return "arrow.down.circle"
        case .quitMode: return "bolt.fill"
        case .shortcuts: return "command"
        case .quitOnSleep: return "moon.zzz"
        case .lastWindow: return "macwindow"
        case .rescue: return "gauge.with.dots.needle.67percent"
        case .autoQuit: return "hourglass"
        case .backgroundApps: return "eye"
        case .musicProtection: return "music.note"
        case .confirmations: return "checkmark.shield"
        case .finderTrash: return "trash"
        case .exclude: return "nosign"
        case .ports: return "network"
        case .uninstallApps: return "xmark.app"
        case .leftovers: return "doc.questionmark"
        case .systemJunk: return "gearshape.2"
        case .userCache: return "internaldrive"
        case .mailFiles: return "envelope"
        case .trashBins: return "trash"
        case .largeOldFiles: return "clock"
        case .aiApps: return "cpu"
        case .xcodeJunk: return "hammer"
        case .brewCache: return "mug"
        case .nodeCache: return "leaf"
        case .dockerCache: return "shippingbox"
        }
    }

    var tint: Color {
        switch tab {
        case .general: return Color(red: 0.25, green: 0.56, blue: 0.98)
        case .shortcuts: return Color(red: 0.55, green: 0.42, blue: 0.96)
        case .automation: return Color(red: 0.98, green: 0.58, blue: 0.20)
        case .advanced: return Color(red: 0.93, green: 0.36, blue: 0.56)
        case .exclude: return Color(red: 0.94, green: 0.33, blue: 0.31)
        case .ports: return Color(red: 0.16, green: 0.71, blue: 0.64)
        default: return QuitXTheme.accent
        }
    }

    @MainActor
    func status(config: QuitXConfig) -> String? {
        func onOff(_ value: Bool) -> String { value ? "On" : "Off" }
        switch self {
        case .openAtLogin: return onOff(LaunchAtLoginService.shared.isEnabled)
        case .menuBarStats: return onOff(config.availableMenuBarStatsEnabled)
        case .appearance:
            if #available(macOS 26.0, *) { return config.liquidGlassEnabled ? "Glass" : "Classic" }
            return "Classic"
        case .sounds: return onOff(config.playSounds)
        case .updates: return onOff(config.autoUpdate)
        case .quitMode: return config.force == .force ? "Force" : "Normal"
        case .shortcuts:
            let manager = ShortcutManager.shared
            let count = ShortcutManager.Slot.allCases.filter { manager.isEnabled($0) }.count
            return count == 0 ? "Off" : "\(count) on"
        case .quitOnSleep: return onOff(config.quitOnSleep)
        case .lastWindow: return onOff(config.quitWhenLastWindowClosed)
        case .rescue: return onOff(config.hogAlertEnabled || config.memoryPressureQuitEnabled)
        case .autoQuit: return config.quitInactiveAfterMinutes > 0 ? "\(config.quitInactiveAfterMinutes) min" : "Off"
        case .backgroundApps: return onOff(config.includeBackground)
        case .musicProtection: return onOff(config.neverQuitMusic)
        case .confirmations: return onOff(config.confirmQuitAll || config.confirmIndividualAction)
        case .finderTrash: return onOff(config.includeFinder || config.includeTrash)
        case .exclude:
            let apps = config.exclude.count
            let ports = config.portsEnabled ? config.portsExcluded.count : 0
            if apps + ports == 0 { return "Empty" }
            return "\(apps + ports) item\(apps + ports == 1 ? "" : "s")"
        case .ports: return onOff(config.portsEnabled)
        case .uninstallApps, .leftovers, .systemJunk, .userCache, .mailFiles, .trashBins,
             .largeOldFiles, .aiApps, .xcodeJunk, .brewCache, .nodeCache, .dockerCache:
            return nil
        }
    }

    static func isActive(_ status: String?) -> Bool {
        guard let status else { return false }
        return !["Off", "Empty"].contains(status)
    }
}

struct FeatureThumbnail: View {
    let symbol: String
    let tint: Color
    var status: String?
    var symbolColor: Color = .white
    var height: CGFloat = 74

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.30), tint.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.42), tint.opacity(0)],
                        center: .center,
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .frame(width: 96, height: 96)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: tint.opacity(0.35), radius: 6, y: 3)

                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(symbolColor)
            }
            .frame(width: 38, height: 38)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if let status {
                let active = SettingsFeature.isActive(status)
                Text(status)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(active ? Color.black.opacity(0.82) : Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(active ? QuitXTheme.accent : Color.primary.opacity(0.08))
                    )
                    .padding(7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FeatureCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    var status: String?
    var footer: String?
    var isHovered = false
    var detailLines = 2
    var symbolColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            FeatureThumbnail(symbol: symbol, tint: tint, status: status, symbolColor: symbolColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(detailLines)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(detailLines) * 14, alignment: .topLeading)

                if let footer {
                    HStack(spacing: 3) {
                        Text(footer)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isHovered ? QuitXTheme.accent : Color.secondary.opacity(0.8))
                    .padding(.top, 3)
                }
            }
            .padding(.horizontal, 3)
        }
        .padding(8)
        .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isHovered ? QuitXTheme.accent.opacity(0.7) : Color.primary.opacity(0.09), lineWidth: isHovered ? 1 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct SettingsOverviewView: View {
    @ObservedObject var navigation: SettingsNavigationModel
    @EnvironmentObject private var configStore: ConfigStore
    @ObservedObject private var launchService = LaunchAtLoginService.shared
    @ObservedObject private var shortcuts = ShortcutManager.shared

    static let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(SettingsTab.byCategory.filter { $0.category != .start && $0.category != .quitx && $0.category != .moreApps }, id: \.category) { group in
                    let features = SettingsFeature.allCases.filter { group.tabs.contains($0.tab) }
                    if !features.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.category.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.secondary)

                            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                                ForEach(features) { feature in
                                    featureButton(feature)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("QUITX TOOLS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)

                    LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 12) {
                        utilityButton(
                            id: "help",
                            symbol: "questionmark.circle.fill",
                            tint: Color(red: 0.24, green: 0.62, blue: 0.96),
                            title: "Help",
                            detail: "Guides for every feature and workflow.",
                            footer: "Open Help"
                        ) {
                            HelpWindowController.shared.show()
                        }

                        utilityButton(
                            id: "uninstaller",
                            symbol: "trash.slash.fill",
                            tint: Color(red: 0.94, green: 0.38, blue: 0.36),
                            title: "Uninstall Apps",
                            detail: "Remove apps and their leftover files.",
                            footer: "Choose an app"
                        ) {
                            navigation.select(.uninstallApps)
                        }

                        utilityButton(
                            id: "changelog",
                            symbol: "sparkles",
                            tint: Color(red: 0.62, green: 0.45, blue: 0.96),
                            title: "What's New",
                            detail: "Latest features, refinements and fixes.",
                            footer: "View updates"
                        ) {
                            ChangelogWindowController.shared.show()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("MORE APPS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)

                    marqueeBanner
                }
            }
            .padding(.bottom, 24)
            .frame(width: SettingsTab.contentWidth, alignment: .leading)
        }
    }

    private func utilityButton(
        id: String,
        symbol: String,
        tint: Color,
        title: String,
        detail: String,
        footer: String,
        action: @escaping () -> Void
    ) -> some View {
        let hoverID = "utility-\(id)"
        let hovered = navigation.hoveredCard == hoverID
        return Button(action: action) {
            FeatureCard(
                symbol: symbol,
                tint: tint,
                title: title,
                detail: detail,
                footer: footer,
                isHovered: hovered
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .onHover { hovering in
            if hovering {
                navigation.hoveredCard = hoverID
            } else if navigation.hoveredCard == hoverID {
                navigation.hoveredCard = nil
            }
        }
    }

    private func featureButton(_ feature: SettingsFeature) -> some View {
        let hovered = navigation.hoveredCard == feature.id
        return Button {
            navigation.select(feature.tab)
        } label: {
            FeatureCard(
                symbol: feature.symbol,
                tint: feature.tint,
                title: feature.title,
                detail: feature.detail,
                status: feature.status(config: configStore.config),
                footer: feature.tab.title,
                isHovered: hovered
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(feature.title). \(feature.detail)")
        .accessibilityHint("Opens \(feature.tab.title) settings")
        .onHover { hovering in
            if hovering {
                navigation.hoveredCard = feature.id
            } else if navigation.hoveredCard == feature.id {
                navigation.hoveredCard = nil
            }
        }
    }

    private var marqueeBanner: some View {
        let hovered = navigation.hoveredCard == "marquee"
        return Button {
            navigation.select(.marquee)
        } label: {
            HStack(spacing: 14) {
                MarqueeIconView(size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Marquee")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.primary)
                        Text("FREE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(MarqueePromo.yellow, in: Capsule())
                    }
                    Text(MarqueePromo.tagline)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                    Text("Screenshots, recordings, colors and clipboard history in your menu bar.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text("Take a look")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(MarqueePromo.yellow.opacity(hovered ? 1 : 0.9), in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [MarqueePromo.yellow.opacity(0.20), MarqueePromo.yellow.opacity(0.04)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MarqueePromo.yellow.opacity(hovered ? 0.8 : 0.35), lineWidth: hovered ? 1 : 0.6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Marquee. \(MarqueePromo.tagline)")
        .onHover { hovering in
            if hovering {
                navigation.hoveredCard = "marquee"
            } else if navigation.hoveredCard == "marquee" {
                navigation.hoveredCard = nil
            }
        }
    }
}
