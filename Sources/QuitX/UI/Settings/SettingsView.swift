import SwiftUI
import AppKit
import Combine

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case automation = "Automation"
    case advanced = "Advanced"
    case exclude = "Exclude"
    case shortcuts = "Shortcuts"
    case about = "About"

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }

    var iconName: String {
        switch self {
        case .general:   return "preferences-general"
        case .automation: return "preferences-automation"
        case .advanced:  return "preferences-advanced"
        case .exclude:   return "preferences-exclude"
        case .shortcuts: return "preferences-shortcuts"
        case .about:     return "preferences-about"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .automation: return "timer"
        case .advanced:  return "slider.horizontal.3"
        case .exclude:   return "nosign"
        case .shortcuts: return "command"
        case .about:     return "bolt.fill"
        }
    }

    var toolbarImage: NSImage? {
        if let img = AssetImages.load(iconName) {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 19, height: 19)
            copy.isTemplate = true
            return copy
        }
        let sym = NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: rawValue)
        let copy = sym?.copy() as? NSImage
        copy?.size = NSSize(width: 19, height: 19)
        copy?.isTemplate = true
        return copy ?? sym
    }

    var contentHeight: CGFloat {
        switch self {
        case .general:
            if #available(macOS 26.0, *) { return 331 }
            return 301
        case .automation: return 361
        case .advanced:  return 271
        case .exclude:   return 306
        case .shortcuts: return 221
        case .about:     return 186
        }
    }
}

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
            .sink { [weak self] notification in
                guard let self else { return }
                if let obj = notification.object as? NSObject, obj === self { return }
                self.close()
            }
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        window?.orderOut(nil)
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
            Task { @MainActor in self?.close() }
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

final class SettingsTabViewModel: ObservableObject {
    @Published var activeTab: SettingsTab = .general
    @Published var glassTopInset: CGFloat = 0
}

struct SettingsContainerView: View {
    @ObservedObject var tabModel: SettingsTabViewModel
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        ZStack(alignment: .top) {
            switch tabModel.activeTab {
            case .general:
                GeneralTabCloneView()
                    .environmentObject(configStore)
            case .automation:
                AutomationTabCloneView()
                    .environmentObject(configStore)
            case .advanced:
                AdvancedTabCloneView()
                    .environmentObject(configStore)
            case .exclude:
                ExcludeTabView()
                    .environmentObject(configStore)
            case .shortcuts:
                ShortcutsTabCloneView()
            case .about:
                AboutTabCloneView()
            }
        }
        .frame(width: 480, height: tabModel.activeTab.contentHeight, alignment: .top)
        .overlay(alignment: .top) {
            if LiquidGlass.enabled {
                Color.primary.opacity(0.12)
                    .frame(height: 0.5)
            }
        }
        .background {
            if LiquidGlass.enabled {
                ZStack(alignment: .top) {
                    LiquidGlassFill(shape: Rectangle())
                    if tabModel.glassTopInset > 0 {
                        QuitXTheme.cardBackground
                            .frame(height: tabModel.glassTopInset)
                    }
                }
                .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
            }
        }
        .onChange(of: tabModel.activeTab) { _, _ in
            HelpPopoverState.closeAll()
            NotificationCenter.default.post(name: QuitXConstants.Notifications.dismissSettingsTooltips, object: nil)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var tabModel = SettingsTabViewModel()

    var body: some View {
        SettingsContainerView(tabModel: tabModel)
            .environmentObject(configStore)
    }
}
