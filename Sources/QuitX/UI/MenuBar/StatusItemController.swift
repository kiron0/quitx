import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static weak var shared: StatusItemController?

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?
    private var lastCloseTimestamp: Date = .distantPast

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

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
        NSColor.black.setFill()
        let rounded = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 16), xRadius: 4, yRadius: 4)
        rounded.fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @MainActor
    private func configurePopover() {
        let rootView = MainPopoverView()
            .environmentObject(ConfigStore.shared)
        let hosting = NSHostingController(rootView: rootView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = 10
        hosting.view.layer?.masksToBounds = true
        popover.contentViewController = hosting
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

        let screenHeight = statusItem.button?.window?.screen?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 800
        let maximumHeight = max(100, screenHeight - 48)
        let targetHeight = min(maximumHeight, calculated)
        AppListViewModel.shared.listNeedsScrolling = calculated > maximumHeight
        popover.contentSize = NSSize(width: 270, height: targetHeight)
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
            closePopover()
        } else {

            if Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                return
            }
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

    private func showContextMenu() {
        closePopover()
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

        let aboutItem = NSMenuItem(title: "About QuitX", action: #selector(openSettings), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit QuitX", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

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

    private func startEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }

            if let button = self.statusItem.button, let window = button.window {
                let mouseLoc = NSEvent.mouseLocation
                let buttonScreenFrame = window.convertToScreen(button.bounds)
                if buttonScreenFrame.contains(mouseLoc) {
                    return
                }
            }

            Task { @MainActor in
                self.closePopover()
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
