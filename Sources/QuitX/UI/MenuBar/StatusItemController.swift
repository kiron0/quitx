import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    static weak var shared: StatusItemController?
    static let popoverWidth: CGFloat = 270

    private var statusItem: NSStatusItem
    private var statsStatusItem: NSStatusItem?
    private struct SegmentMetrics {
        var cpuWidth: CGFloat = 0
        var sepWidth: CGFloat = 0
        var memWidth: CGFloat = 0
        var batWidth: CGFloat? = nil
    }
    private var segmentMetrics = SegmentMetrics()
    private var window: ArrowPopoverWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?
    private var lastCloseTimestamp: Date = .distantPast
    private var workspaceObservers: [NSObjectProtocol] = []
    private var backgroundRefreshTask: Task<Void, Never>?
    private var liveTickCount = 0
    private var lastThrottled = false
    private var menuStatsTask: Task<Void, Never>?
    private var resignKeyObserver: NSObjectProtocol?

    var isShown: Bool {
        window?.isVisible ?? false
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        Self.shared = self

        configureButton()
        configureWindow()
        startEventMonitor()
        startWorkspaceObservers()
    }

    deinit {
        refreshTask?.cancel()
        liveMonitoringTask?.cancel()
        backgroundRefreshTask?.cancel()
        menuStatsTask?.cancel()
        if let statsStatusItem { NSStatusBar.system.removeStatusItem(statsStatusItem) }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        if let g = globalEventMonitor { NSEvent.removeMonitor(g) }
        if let l = localEventMonitor { NSEvent.removeMonitor(l) }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.imagePosition = .imageOnly
        button.toolTip = QuitXConstants.appName
        button.setAccessibilityLabel(QuitXConstants.appName)

        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    private var cachedMenuBarIcon: NSImage?

    private func makeMenuBarIcon() -> NSImage {
        if let cached = cachedMenuBarIcon {
            return cached
        }
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
            cachedMenuBarIcon = icon
            return icon
        }

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSColor.black.setFill()
        let rounded = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 17, height: 17), xRadius: 4, yRadius: 4)
        rounded.fill()
        image.unlockFocus()
        image.isTemplate = true
        cachedMenuBarIcon = image
        return image
    }

    @MainActor
    private func configureWindow() {
        let rootView = AnyView(
            MainPopoverView()
                .environmentObject(ConfigStore.shared)
        )
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = []
        hosting.view.wantsLayer = true
        self.hostingController = hosting

        let win = ArrowPopoverWindow(level: .popUpMenu)
        win.contentViewController = hosting
        self.window = win

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: win,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isShown else { return }
                self.closePopover()
            }
        }

        updatePopoverSize()

        Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            self?.updatePopoverSize()
        }
    }

    @MainActor
    func updatePopoverSize() {
        let vm = AppListViewModel.shared
        let count = vm.filteredApps.count
        let calculated: CGFloat
        if count == 0 {
            calculated = 175
        } else {
            let baseHeight: CGFloat = 94
            let rowHeight: CGFloat = 27
            calculated = baseHeight + (CGFloat(count) * rowHeight)
        }

        let minPopoverHeight: CGFloat = 220
        let effectiveCalculated = max(calculated, minPopoverHeight)
        let arrowHeight: CGFloat = 12
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 800
        let maximumHeight = max(100, screenHeight - 48)
        let targetHeight = min(maximumHeight, effectiveCalculated)
        let needsScrolling = calculated > maximumHeight
        if AppListViewModel.shared.listNeedsScrolling != needsScrolling {
            AppListViewModel.shared.listNeedsScrolling = needsScrolling
        }

        let totalHeight = targetHeight + arrowHeight
        let newSize = NSSize(width: Self.popoverWidth, height: totalHeight)
        guard let win = window else { return }

        var frame = win.frame
        frame.size = newSize

        var originX = frame.origin.x
        var originY = frame.origin.y
        var arrowX: CGFloat? = nil

        if let button = statusItem.button, let btnWindow = button.window {
            let buttonScreenRect = btnWindow.convertToScreen(button.bounds)
            originX = buttonScreenRect.midX - (newSize.width / 2)
            originY = buttonScreenRect.minY - totalHeight - 2

            if let scr = screen {
                let screenMinX = scr.visibleFrame.minX
                let screenMaxX = scr.visibleFrame.maxX
                originX = max(screenMinX + 4, min(originX, screenMaxX - newSize.width - 4))
            }
            arrowX = buttonScreenRect.midX - originX
        } else if let scr = screen ?? NSScreen.main {
            originX = scr.visibleFrame.midX - (newSize.width / 2)
            originY = scr.visibleFrame.maxY - totalHeight - 2
        }

        frame.origin = NSPoint(x: originX, y: originY)
        frame = frame.integral
        if AppListViewModel.shared.popoverArrowX != arrowX {
            AppListViewModel.shared.popoverArrowX = arrowX
        }
        guard frame != win.frame else { return }
        win.setFrame(frame, display: win.isVisible, animate: false)
        win.invalidateShadow()
    }

    private func startWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleBackgroundRefresh() }
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        guard isShown else { return }
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled else { return }
            self.updatePopoverSize()
        }
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
        AppListViewModel.shared.cancelConfirmQuitAll()
        AppListViewModel.shared.cancelIndividualAction()
        if isShown {
            lastCloseTimestamp = Date()
        }
        stopLiveMonitoring()
        removeOutsideClickMonitor()
        window?.orderOut(nil)
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
            StatsDetailController.shared.close()
            guard let win = window else { return }
            updatePopoverSize()
            win.contentView?.layoutSubtreeIfNeeded()
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(nil)
            win.invalidateShadow()
            AppListViewModel.shared.syncOptionKey()
            refreshVisibleApps()
            installOutsideClickMonitor()
            startLiveMonitoring()
        }
    }

    private func refreshVisibleApps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await AppListViewModel.shared.refresh()
            guard !Task.isCancelled, let self else { return }
            self.updateMenuBarStats()
            self.updatePopoverSize()
        }
    }

    private func startLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = Task { @MainActor [weak self] in
            while let self = self, self.isShown {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, self.isShown else { break }
                let cfg = ConfigStore.shared.config
                let powerSources = cfg.batterySaverEnabled
                    ? BatterySaver.currentDescriptions()
                    : nil
                let throttled = cfg.batterySaverEnabled
                    && BatterySaver.isOnBattery(descriptions: powerSources ?? [])
                if throttled != self.lastThrottled {
                    self.liveTickCount = 0
                    self.lastThrottled = throttled
                }
                self.liveTickCount += 1
                let skip = throttled && self.liveTickCount % 5 != 0
                if !skip {
                    await AppListViewModel.shared.updateLiveStats()
                    self.updatePopoverSize()
                }
            }
        }
    }

    private static var attachmentCache: [String: NSTextAttachment] = [:]

    private static func menuBarAttachment(symbolNames: [String]) -> NSTextAttachment? {
        for name in symbolNames {
            if let cached = attachmentCache[name] {
                return cached
            }
            guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { continue }
            let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            let sized = image.withSymbolConfiguration(configuration) ?? image
            sized.isTemplate = true
            let attachment = NSTextAttachment()
            attachment.image = sized
            let size = sized.size
            attachment.bounds = NSRect(x: 0, y: -2, width: size.width, height: size.height)
            attachmentCache[name] = attachment
            return attachment
        }
        return nil
    }

    private static func statSegmentTitle(
        symbolNames: [String],
        fallback: String,
        text: String,
        style: QuitXConfig.MenuBarStatStyle
    ) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor
        ]
        let result = NSMutableAttributedString()
        if style == .icon, let attachment = menuBarAttachment(symbolNames: symbolNames) {
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " \(text)", attributes: attributes))
        } else {
            result.append(NSAttributedString(string: "\(fallback) \(text)", attributes: attributes))
        }
        return result
    }

    var statsButton: NSStatusBarButton? {
        statsStatusItem?.button
    }

    var statusBarButton: NSStatusBarButton? {
        statusItem.button
    }

    func updateMenuBarStats(powerSources: [[String: Any]]? = nil) {
        let cfg = ConfigStore.shared.config
        guard cfg.showMenuBarStats else {
            removeStatsItem()
            return
        }

        let item = statsStatusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statsStatusItem = item
        guard let button = item.button else { return }

        if button.action == nil {
            button.target = self
            button.action = #selector(handleStatsItemClick(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.toolTip = "QuitX monitor — click for details"
            button.imagePosition = .imageLeading
        }

        let cpu = SystemUsage.cpuPercent(consumer: "menuBar")
        let memoryUsed = SystemUsage.memoryUsedBytes()
        let battery = cfg.batteryMenuBarEnabled
            ? BatteryDetailSampler.menuBarSnapshot(descriptions: powerSources)
            : nil

        let cpuText = BatterySaver.percentText(cpu)
        let memText = BatterySaver.compactMemoryText(bytes: memoryUsed, unit: cfg.menuBarMemoryUnit)
        let batteryKey = battery.map { "\($0.percent)-\($0.isCharging)-\($0.isACPower)" } ?? "none"
        let titleKey = "\(cfg.menuBarStatStyle.rawValue)|\(cpuText)|\(memText)|\(batteryKey)"
        if titleKey == lastStatTitleKey {
            return
        }

        let cpuAttr = Self.statSegmentTitle(
            symbolNames: ["cpu"],
            fallback: "CPU",
            text: cpuText,
            style: cfg.menuBarStatStyle
        )

        let memAttr = Self.statSegmentTitle(
            symbolNames: ["memorychip", "internaldrive"],
            fallback: "MEM",
            text: memText,
            style: cfg.menuBarStatStyle
        )

        let batAttr: NSAttributedString?
        if let battery {
            let batterySymbols: [String]
            if battery.isCharging {
                batterySymbols = [
                    BatteryDetailSampler.menuBarSymbolName(percent: battery.percent, charging: true),
                    "bolt.fill"
                ]
            } else if battery.isACPower {
                batterySymbols = ["powercord", "power.plug"]
            } else {
                batterySymbols = [
                    BatteryDetailSampler.menuBarSymbolName(percent: battery.percent, charging: false)
                ]
            }
            batAttr = Self.statSegmentTitle(
                symbolNames: batterySymbols,
                fallback: battery.isACPower && !battery.isCharging ? "AC" : "BAT",
                text: "\(battery.percent)%",
                style: cfg.menuBarStatStyle
            )
        } else {
            batAttr = nil
        }

        let sepAttr = NSAttributedString(
            string: "   ",
            attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let fullTitle = NSMutableAttributedString()
        fullTitle.append(cpuAttr)
        fullTitle.append(sepAttr)
        fullTitle.append(memAttr)
        if let batAttr {
            fullTitle.append(sepAttr)
            fullTitle.append(batAttr)
        }

        button.attributedTitle = fullTitle
        lastStatTitleKey = titleKey

        segmentMetrics = SegmentMetrics(
            cpuWidth: cpuAttr.size().width,
            sepWidth: sepAttr.size().width,
            memWidth: memAttr.size().width,
            batWidth: batAttr?.size().width
        )
    }

    private var lastStatTitleKey: String?

    private func removeStatsItem() {
        StatsDetailController.shared.close()
        lastStatTitleKey = nil
        guard let item = statsStatusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statsStatusItem = nil
    }

    private var isRightClick: Bool {
        if let event = NSApp.currentEvent, event.type == .rightMouseDown || event.type == .rightMouseUp {
            return true
        }
        return false
    }

    @objc private func handleStatsItemClick(_ sender: Any?) {
        guard let button = statsStatusItem?.button, let buttonWindow = button.window else { return }
        if isRightClick {
            showContextMenu()
            return
        }

        let (mode, anchorX) = resolveClickedStat(on: button, window: buttonWindow)
        StatsDetailController.shared.toggle(from: button, mode: mode, anchorScreenX: anchorX)
    }

    private func resolveClickedStat(on button: NSStatusBarButton, window: NSWindow) -> (StatsDetailModel.Mode, CGFloat) {
        let buttonScreenRect = window.convertToScreen(button.bounds)
        let fullWidth = button.attributedTitle.size().width
        let titleInsetX = max(0, (button.bounds.width - fullWidth) / 2)
        let contentScreenStartX = buttonScreenRect.minX + titleInsetX

        let m = segmentMetrics
        let cpuStartX = contentScreenStartX
        let cpuMidX = cpuStartX + m.cpuWidth / 2
        let cpuEndX = cpuStartX + m.cpuWidth

        let memStartX = cpuEndX + m.sepWidth
        let memMidX = memStartX + m.memWidth / 2
        let memEndX = memStartX + m.memWidth

        let clickScreenX = NSEvent.mouseLocation.x

        if let batWidth = m.batWidth {
            let batStartX = memEndX + m.sepWidth
            let batMidX = batStartX + batWidth / 2

            let cpuMemBoundary = cpuEndX + m.sepWidth / 2
            let memBatBoundary = memEndX + m.sepWidth / 2

            if clickScreenX < cpuMemBoundary {
                return (.cpu, cpuMidX)
            } else if clickScreenX > memBatBoundary {
                return (.battery, batMidX)
            } else {
                return (.memory, memMidX)
            }
        } else {
            let cpuMemBoundary = cpuEndX + m.sepWidth / 2
            if clickScreenX < cpuMemBoundary {
                return (.cpu, cpuMidX)
            } else {
                return (.memory, memMidX)
            }
        }
    }

    func startMenuBarStats() {
        menuStatsTask?.cancel()
        SystemUsage.prime()
        updateMenuBarStats()
        menuStatsTask = Task { @MainActor [weak self] in
            var interval: UInt64 = 1_000_000_000
            while true {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, let self else { break }
                let cfg = ConfigStore.shared.config
                guard cfg.showMenuBarStats else {
                    self.removeStatsItem()
                    interval = 5_000_000_000
                    continue
                }
                let powerSources = (cfg.batterySaverEnabled || cfg.batteryMenuBarEnabled)
                    ? BatterySaver.currentDescriptions()
                    : nil
                let onBattery = cfg.batterySaverEnabled
                    && BatterySaver.isOnBattery(descriptions: powerSources ?? [])
                interval = onBattery ? 5_000_000_000 : 1_000_000_000
                self.updateMenuBarStats(powerSources: powerSources)
            }
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    private func showContextMenu() {
        closePopover()
        StatsDetailController.shared.close()
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(MenuHelper.makeItem(
            title: "Settings",
            action: #selector(openSettings),
            target: self,
            keyEquivalent: ",",
            assetName: "settings-preferences",
            systemSymbolName: "gearshape"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Help",
            action: #selector(openHelp),
            target: self,
            keyEquivalent: "?",
            assetName: "settings-help",
            systemSymbolName: "questionmark.circle"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Check for Updates",
            action: #selector(checkForUpdates),
            target: self,
            keyEquivalent: "u",
            systemSymbolName: "arrow.triangle.2.circlepath"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About",
            action: #selector(openAbout),
            target: self,
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle"
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit",
            action: #selector(quitApp),
            target: self,
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power"
        ))

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout() {
        SettingsWindowController.shared.show(tab: .about)
    }

    @objc private func checkForUpdates() {
        Task {
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
        }
    }

    @objc private func openHelp() {
        HelpWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func startEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.isShown else { return event }

            if event.type == .keyDown {
                if event.keyCode == 53 {
                    if AppListViewModel.shared.pendingIndividualAction != nil {
                        AppListViewModel.shared.cancelIndividualAction()
                        return nil
                    }
                    if AppListViewModel.shared.showConfirmQuitAll {
                        AppListViewModel.shared.cancelConfirmQuitAll()
                        return nil
                    }
                    self.closePopover()
                    return nil
                }
                if event.keyCode == 36 {
                    if AppListViewModel.shared.pendingIndividualAction != nil {
                        AppListViewModel.shared.confirmIndividualAction()
                        return nil
                    }
                    if AppListViewModel.shared.showConfirmQuitAll {
                        AppListViewModel.shared.confirmQuitAllAction()
                        return nil
                    }
                }

                if event.modifierFlags.contains(.command) {
                    let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
                    if chars == "a" {
                        let isEditingText = self.window?.firstResponder is NSText
                        if !isEditingText {
                            AppListViewModel.shared.toggleSelectAll()
                            return nil
                        }
                    } else if chars == "," {
                        self.closePopover()
                        SettingsWindowController.shared.show()
                        return nil
                    } else if chars == "?" || (chars == "/" && event.modifierFlags.contains(.shift)) {
                        self.closePopover()
                        HelpWindowController.shared.show()
                        return nil
                    } else if chars == "i" {
                        self.closePopover()
                        SettingsWindowController.shared.show(tab: .about)
                        return nil
                    }
                }
            }

            let popupWindow = self.window
            let statusWindow = self.statusItem.button?.window
            if event.window !== popupWindow, event.window !== statusWindow {
                self.closePopover()
            }
            return event
        }
    }

    private func installOutsideClickMonitor() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.isShown else { return }

            if let button = self.statusItem.button, let buttonWindow = button.window {
                let mouseLoc = NSEvent.mouseLocation
                let buttonScreenFrame = buttonWindow.convertToScreen(button.bounds)
                if buttonScreenFrame.contains(mouseLoc) {
                    return
                }
            }
            if let statsButton = self.statsButton, let buttonWindow = statsButton.window {
                let mouseLoc = NSEvent.mouseLocation
                let buttonScreenFrame = buttonWindow.convertToScreen(statsButton.bounds)
                if buttonScreenFrame.contains(mouseLoc) {
                    return
                }
            }

            Task { @MainActor in
                self.closePopover()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
}
