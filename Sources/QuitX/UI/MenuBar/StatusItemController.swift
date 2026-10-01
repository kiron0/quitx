import AppKit
import SwiftUI

/// Owns the NSStatusItem and NSPopover. Single source of truth for menubar presence.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static weak var shared: StatusItemController?

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        // Menus inside transient popovers can dismiss their parent before they
        // receive the click. Explicit monitors provide predictable dismissal.
        popover.behavior = .applicationDefined
        popover.animates = false

        super.init()
        Self.shared = self
        popover.delegate = self

        configureButton()
        configurePopover()
        startEventMonitor()
    }

    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        refreshTask?.cancel()
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = "QuitX"
        button.setAccessibilityLabel("QuitX")

        // Support both left and right click
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    /// Monochrome menu-bar version matching QuitAll status-icon with full 1x and @2x Retina support.
    private func makeMenuBarIcon() -> NSImage {
        let icon = NSImage(size: NSSize(width: 18, height: 18))
        let iconNames = ["status-icon", "menubar"]
        var loaded = false

        for name in iconNames {
            let path1x = Bundle.main.path(forResource: name, ofType: "png") ?? "Support/Icons/\(name).png"
            let path2x = Bundle.main.path(forResource: "\(name)@2x", ofType: "png") ?? "Support/Icons/\(name)@2x.png"

            var reps: [NSImageRep] = []
            if FileManager.default.fileExists(atPath: path1x),
               let rep1 = NSImageRep(contentsOfFile: path1x) {
                rep1.size = NSSize(width: 18, height: 18)
                reps.append(rep1)
            }
            if FileManager.default.fileExists(atPath: path2x),
               let rep2 = NSImageRep(contentsOfFile: path2x) {
                rep2.size = NSSize(width: 18, height: 18)
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

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 2.2, y: 3.2, width: 11.8, height: 11.8))
        ring.lineWidth = 2.6
        ring.stroke()
        NSColor.black.setFill()
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 10.1, y: 10.1))
        bolt.line(to: NSPoint(x: 14.1, y: 9.7))
        bolt.line(to: NSPoint(x: 12.8, y: 16.2))
        bolt.line(to: NSPoint(x: 17.0, y: 9.0))
        bolt.line(to: NSPoint(x: 13.4, y: 9.2))
        bolt.line(to: NSPoint(x: 14.6, y: 3.0))
        bolt.close()
        bolt.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @MainActor
    private func configurePopover() {
        let rootView = MainPopoverView()
            .environmentObject(ConfigStore.shared)
        popover.contentViewController = NSHostingController(rootView: rootView)
        updatePopoverSize()

        // Prime the first popover size before it becomes visible. Otherwise the
        // footer jumps when the initial app scan finishes.
        Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            self?.updatePopoverSize()
        }
    }

    @MainActor
    func updatePopoverSize() {
        let count = AppListViewModel.shared.filteredApps.count
        // Grow naturally. Scroll only when rows exceed available screen height.
        let baseHeight: CGFloat = 104
        let rowHeight: CGFloat = 29
        let itemCount = max(1, count)
        let calculated = baseHeight + (CGFloat(itemCount) * rowHeight)
        let screenHeight = statusItem.button?.window?.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 800
        let maximumHeight = max(145, screenHeight - 48)
        let targetHeight = min(maximumHeight, max(145, calculated))
        AppListViewModel.shared.listNeedsScrolling = calculated > maximumHeight
        popover.contentSize = NSSize(width: 270, height: targetHeight)
    }

    // MARK: - Click Handling

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover Actions

    func closePopover() {
        stopLiveMonitoring()
        popover.close()
    }

    @MainActor
    func showPopover() {
        if !popover.isShown {
            togglePopover()
        }
    }

    @MainActor
    func togglePopover() {
        if popover.isShown {
            stopLiveMonitoring()
            popover.close()
        } else {
            guard let button = statusItem.button else { return }
            NSApp.activate(ignoringOtherApps: true)
            updatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
            refreshVisibleApps()
            startLiveMonitoring()
        }
    }

    private func startLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = Task { @MainActor [weak self] in
            while let self = self, self.popover.isShown {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.popover.isShown else { break }
                await AppListViewModel.shared.updateLiveStats()
                self.updatePopoverSize()
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            StatusItemController.shared?.stopLiveMonitoring()
        }
    }

    private func refreshVisibleApps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled else { return }
            self?.updatePopoverSize()
        }
    }

    // MARK: - Context Menu on Right Click

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let stashItem = NSMenuItem(title: "Stash Session", action: #selector(stashSession), keyEquivalent: "")
        stashItem.target = self
        menu.addItem(stashItem)

        let restoreItem = NSMenuItem(title: "Restore Session", action: #selector(restoreSession), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.isEnabled = StashService.shared.hasStash
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        let welcomeItem = NSMenuItem(title: "Welcome Guide...", action: #selector(openWelcomeGuide), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        let aboutItem = NSMenuItem(title: "About QuitX", action: #selector(openPreferences), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit QuitX", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func openPreferences() {
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

    // MARK: - Outside-click dismissal

    private func startEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.popover.isShown else { return event }

            if event.type == .keyDown, event.keyCode == 53 {
                self.closePopover()
                return nil
            }

            let popoverWindow = self.popover.contentViewController?.view.window
            let statusWindow = self.statusItem.button?.window
            if event.window !== popoverWindow, event.window !== statusWindow {
                self.closePopover()
            }
            return event
        }
    }
}
