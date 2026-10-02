import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static weak var shared: StatusItemController?

    private var statusItem: NSStatusItem
    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?
    private var lastCloseTimestamp: Date = .distantPast

    var isShown: Bool {
        popover?.isShown ?? false
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        Self.shared = self

        configureButton()
        configurePopover()
    }

    deinit {
        refreshTask?.cancel()
        liveMonitoringTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "QuitX"
        button.setAccessibilityLabel("QuitX")

        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    private func makeMenuBarIcon() -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let icon = NSImage(size: targetSize)
        let iconNames = ["status-icon", "menubar"]
        var loaded = false

        for name in iconNames {
            let path1x = Bundle.main.path(forResource: name, ofType: "png") ?? "Support/Icons/\(name).png"
            let path2x = Bundle.main.path(forResource: "\(name)@2x", ofType: "png") ?? "Support/Icons/\(name)@2x.png"

            var reps: [NSImageRep] = []
            if FileManager.default.fileExists(atPath: path1x),
               let rep1 = NSImageRep(contentsOfFile: path1x) {
                rep1.size = targetSize
                reps.append(rep1)
            }
            if FileManager.default.fileExists(atPath: path2x),
               let rep2 = NSImageRep(contentsOfFile: path2x) {
                rep2.size = targetSize
                reps.append(rep2)
            }

            if !reps.isEmpty {
                reps.forEach { icon.addRepresentation($0) }
                loaded = true
                break
            }
        }

        if loaded {
            icon.isTemplate = true
            return icon
        }

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        let rounded = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 17, height: 17), xRadius: 4, yRadius: 4)
        rounded.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @MainActor
    private func configurePopover() {
        let rootView = AnyView(
            MainPopoverView()
                .environmentObject(ConfigStore.shared)
        )
        let hosting = NSHostingController(rootView: rootView)
        self.hostingController = hosting

        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 270, height: 200)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = NSApp.effectiveAppearance
        self.popover = popover

        updatePopoverSize()

        Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            self?.updatePopoverSize()
        }
    }

    @MainActor
    func updatePopoverSize() {
        let count = AppListViewModel.shared.filteredApps.count

        let calculated: CGFloat
        if count == 0 {
            calculated = 175
        } else {
            let baseHeight: CGFloat = 94
            let rowHeight: CGFloat = 27
            calculated = baseHeight + (CGFloat(count) * rowHeight)
        }

        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 800
        let maximumHeight = max(100, screenHeight - 48)
        let targetHeight = min(maximumHeight, calculated)
        AppListViewModel.shared.listNeedsScrolling = calculated > maximumHeight

        let newSize = NSSize(width: 270, height: targetHeight)
        popover?.contentSize = newSize
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseDown || event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func closePopover() {
        lastCloseTimestamp = Date()
        stopLiveMonitoring()
        popover?.performClose(nil)
    }

    @MainActor
    func showPopover() {
        if !isShown {
            togglePopover()
        }
    }

    @MainActor
    func togglePopover() {
        if isShown {
            closePopover()
        } else {
            if Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                return
            }
            guard let popover, let button = statusItem.button else { return }
            popover.appearance = NSApp.effectiveAppearance
            NSApp.activate(ignoringOtherApps: true)
            updatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            refreshVisibleApps()
            startLiveMonitoring()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        lastCloseTimestamp = Date()
        stopLiveMonitoring()
    }

    private func startLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = Task { @MainActor [weak self] in
            while let self = self, self.isShown {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.isShown else { break }
                await AppListViewModel.shared.updateLiveStats()
                self.updatePopoverSize()
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    private func refreshVisibleApps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled else { return }
            self?.updatePopoverSize()
        }
    }

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()
        menu.appearance = NSApp.effectiveAppearance

        menu.addItem(MenuHelper.makeItem(
            title: "Settings...",
            action: #selector(openSettings),
            target: self,
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Stash Session",
            action: #selector(stashSession),
            target: self,
            keyEquivalent: "s",
            systemSymbolName: "tray.and.arrow.down"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Restore Session",
            action: #selector(restoreSession),
            target: self,
            keyEquivalent: "r",
            systemSymbolName: "tray.and.arrow.up",
            isEnabled: StashService.shared.hasStash
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Welcome Guide...",
            action: #selector(openWelcomeGuide),
            target: self,
            keyEquivalent: "w",
            systemSymbolName: "book.pages"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About QuitX",
            action: #selector(openSettings),
            target: self,
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            action: #selector(quitApp),
            target: self,
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power"
        ))

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openWelcomeGuide() {
        WelcomeWindowController.shared.show()
    }

    @objc private func stashSession() {
        let cfg = ConfigStore.shared.config
        let apps = AppListService.shared.fetchApps(config: cfg)
        Task {
            _ = await StashService.shared.stash(apps: apps)
        }
    }

    @objc private func restoreSession() {
        Task {
            _ = await StashService.shared.restore()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

}
