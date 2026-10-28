import SwiftUI
import AppKit
import Combine

enum SettingsCategory: String, CaseIterable, Identifiable {
    case start = ""
    case app = "App"
    case quitting = "Quitting"
    case applications = "Applications"
    case cleanup = "Cleanup"
    case developerCleanup = "Developer Cleanup"
    case developer = "Developer"
    case quitx = "QuitX"
    case moreApps = "More Apps"

    var id: String { rawValue }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case general = "General"
    case shortcuts = "Shortcuts"
    case automation = "Automation"
    case advanced = "Advanced"
    case exclude = "Exclude"
    case uninstallApps = "Uninstall Apps"
    case leftovers = "Leftovers"
    case systemJunk = "System Junk"
    case userCache = "User Cache"
    case mailFiles = "Mail Files"
    case trashBins = "Trash Bins"
    case largeOldFiles = "Large & Old Files"
    case aiApps = "AI Apps"
    case xcodeJunk = "Xcode Junk"
    case brewCache = "Brew Cache"
    case nodeCache = "Node Cache"
    case dockerCache = "Docker Cache"
    case ports = "Ports"
    case about = "About"
    case marquee = "Marquee"

    static let windowSize = NSSize(width: 860, height: 600)
    static let sidebarWidth: CGFloat = 220
    static let detailWidth: CGFloat = windowSize.width - sidebarWidth
    static let detailHorizontalPadding: CGFloat = 28
    static let contentWidth: CGFloat = detailWidth - detailHorizontalPadding * 2

    var id: String { rawValue }

    var title: String { rawValue }

    var category: SettingsCategory {
        switch self {
        case .overview: return .start
        case .general, .shortcuts: return .app
        case .automation, .advanced, .exclude: return .quitting
        case .uninstallApps, .leftovers: return .applications
        case .systemJunk, .userCache, .mailFiles, .trashBins, .largeOldFiles, .aiApps: return .cleanup
        case .xcodeJunk, .brewCache, .nodeCache, .dockerCache: return .developerCleanup
        case .ports: return .developer
        case .about: return .quitx
        case .marquee: return .moreApps
        }
    }

    var symbol: String {
        switch self {
        case .overview:   return "square.grid.2x2"
        case .general:    return "gearshape"
        case .shortcuts:  return "command"
        case .automation: return "timer"
        case .advanced:   return "slider.horizontal.3"
        case .exclude:    return "nosign"
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
        case .ports:      return "network"
        case .about:      return "bolt.fill"
        case .marquee:    return "viewfinder"
        }
    }

    var summary: String {
        switch self {
        case .overview:   return "Everything QuitX can do. Click a card to jump to its settings."
        case .general:    return "Startup, sounds, updates, menu bar stats and how QuitX looks."
        case .shortcuts:  return "Open QuitX or quit apps from anywhere with your own key combos."
        case .automation: return "Let QuitX quit apps on sleep, after their last window, or when they sit idle."
        case .advanced:   return "Background apps, music protection, confirmations and extra list items."
        case .exclude:    return "Apps and ports QuitX never quits, manually or automatically."
        case .uninstallApps: return "Remove installed apps, support files, caches, preferences and launch items."
        case .leftovers: return "Find files left behind by apps that are no longer installed."
        case .systemJunk: return "Review system caches, logs and temporary files."
        case .userCache: return "Review cache data created by apps in your account."
        case .mailFiles: return "Review downloaded Mail attachments stored on this Mac."
        case .trashBins: return "Review files already waiting in your Trash."
        case .largeOldFiles: return "Find large or old files in Desktop, Documents and Downloads."
        case .aiApps: return "Review disposable logs and caches from local AI apps."
        case .xcodeJunk: return "Review DerivedData, archives, simulator caches and Swift package caches."
        case .brewCache: return "Review downloaded Homebrew packages and metadata caches."
        case .nodeCache: return "Review npm, Yarn and pnpm package caches."
        case .dockerCache: return "Review Docker Desktop caches and logs without touching images or volumes."
        case .ports:      return "Find and free ports held by dev servers, databases and Docker."
        case .about:      return "Version, updates and ways to get in touch."
        case .marquee:    return "Capture the screen. Keep the clipboard."
        }
    }

    var keywords: String {
        switch self {
        case .overview:   return "features cards everything help uninstall apps what's new changelog tools"
        case .general:    return "login startup sounds updates download menu bar stats cpu memory gpu battery cleanup cache quick clean order drag refresh appearance liquid glass classic sort default normal force quit"
        case .shortcuts:  return "keyboard hotkey key combo activate menu quit all force quit all settings refresh help what's new changelog uninstall apps"
        case .automation: return "sleep schedule last window close accessibility cpu hog memory pressure rescue auto quit inactive idle timer"
        case .advanced:   return "background helpers group instances music protection select by default tips confirm finder windows empty trash"
        case .exclude:    return "exclude exclusion list never quit protect immune ports"
        case .uninstallApps: return "applications uninstall remove app leftovers support files permanent delete"
        case .leftovers: return "applications orphan leftovers removed uninstalled files scan"
        case .systemJunk: return "cleanup system junk caches logs temporary files"
        case .userCache: return "cleanup user app cache library caches"
        case .mailFiles: return "cleanup mail attachments downloads email"
        case .trashBins: return "cleanup trash bin empty permanent delete"
        case .largeOldFiles: return "cleanup large old files downloads documents desktop storage"
        case .aiApps: return "cleanup ai ollama lm studio logs cache"
        case .xcodeJunk: return "developer cleanup xcode derived data archives simulator swift package"
        case .brewCache: return "developer cleanup homebrew brew cache downloads"
        case .nodeCache: return "developer cleanup node npm yarn pnpm cache"
        case .dockerCache: return "developer cleanup docker desktop cache logs"
        case .ports:      return "port kill listener tcp udp docker refresh menu bar count group sort sigterm sigkill confirm"
        case .about:      return "version update check github contact support website"
        case .marquee:    return "more apps screenshot recording screen capture clipboard color picker measure ocr"
        }
    }

    var fallbackSymbolName: String { symbol }

    var headerTitle: String {
        switch self {
        case .overview: return "Overview"
        case .marquee: return "More Apps"
        default: return title
        }
    }

    var headerSummary: String {
        switch self {
        case .marquee: return "Another free, open-source Mac app worth a look."
        default: return summary
        }
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let features = SettingsFeature.allCases.filter { $0.tab == self }.map { "\($0.title) \($0.detail)" }
        let haystack = ([title, summary, keywords] + features).joined(separator: " ")
        return trimmed.split(separator: " ").allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    static var byCategory: [(category: SettingsCategory, tabs: [SettingsTab])] {
        SettingsCategory.allCases.compactMap { category in
            let tabs = allCases.filter { $0.category == category }
            return tabs.isEmpty ? nil : (category, tabs)
        }
    }
}

@MainActor
final class HelpPopoverState: NSObject, ObservableObject {
    private static var activeStates = NSHashTable<HelpPopoverState>.weakObjects()

    @Published var isShowing = false
    @Published var isHovered = false
    weak var anchorView: NSView?
    private var window: ArrowPopoverWindow?
    private var dismissObserver: AnyCancellable?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    static func closeAll() {
        for state in activeStates.allObjects { state.close() }
    }

    override init() {
        super.init()
        dismissObserver = NotificationCenter.default.publisher(for: QuitXConstants.Notifications.dismissSettingsTooltips)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                if let obj = notification.object as? NSObject, obj === self { return }
                self.close()
            }
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        Self.orderOut(window)
    }

    nonisolated private static func orderOut(_ window: ArrowPopoverWindow?) {
        guard let window else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated { window.orderOut(nil) }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { window.orderOut(nil) }
            }
        }
    }

    func toggle(text: String) {
        if isShowing { close() } else { show(text: text) }
    }

    func hide() { close() }

    private func close() {
        if isShowing {
            window?.orderOut(nil)
            isShowing = false
            isHovered = false
            Self.activeStates.remove(self)
        }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
    }

    private func show(text: String) {
        guard let anchor = anchorView, let anchorWindow = anchor.window else { return }
        NotificationCenter.default.post(name: QuitXConstants.Notifications.dismissSettingsTooltips, object: self)

        let anchorScreenRect = anchorWindow.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let hostView = NSHostingView(rootView: HelpPopoverContentView(text: text))
        let size = hostView.fittingSize

        var originX = anchorScreenRect.midX - size.width / 2
        if let screen = anchorWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4, min(originX, screen.visibleFrame.maxX - size.width - 4))
        }
        let originY = anchorScreenRect.minY - size.height - 2
        let arrowX = anchorScreenRect.midX - originX
        hostView.rootView = HelpPopoverContentView(text: text, arrowX: arrowX)

        let win: ArrowPopoverWindow
        if let existing = window {
            win = existing
        } else {
            let created = ArrowPopoverWindow()
            window = created
            win = created
        }
        win.contentView = hostView
        win.setContentSize(size)
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.prepareForDisplay()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.isShowing else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
            guard let anchor = self.anchorView, let anchorWindow = anchor.window else {
                self.close()
                return event
            }
            guard event.window === anchorWindow else {
                self.close()
                return event
            }
            let onAnchor: Bool
            if let superview = anchor.superview {
                let point = superview.convert(event.locationInWindow, from: nil)
                onAnchor = anchor.frame.contains(point)
            } else {
                onAnchor = false
            }
            self.close()
            return onAnchor ? nil : event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.close()
        }

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        isShowing = true
        Self.activeStates.add(self)
    }
}

private struct HelpPopoverContentView: View {
    let text: String
    var arrowX: CGFloat? = nil

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primary)
                .lineSpacing(2.5)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(width: 230)
        }
        .arrowPopoverChrome(arrowX: arrowX, classicBackground: AnyView(QuitXTheme.popoverBackground))
    }
}

private struct PopoverAnchorView: NSViewRepresentable {
    var onResolve: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onResolve(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView) }
    }
}

struct HelpPopoverButton: View {
    let text: String
    @StateObject private var state = HelpPopoverState()

    var body: some View {
        Button {
            state.toggle(text: text)
        } label: {
            let isActive = state.isShowing || state.isHovered
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? QuitXTheme.accent : Color.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in state.isHovered = h }
        .onDisappear {
            state.hide()
        }
        .background(PopoverAnchorView { state.anchorView = $0 })
    }
}
