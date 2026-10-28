import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    static weak var shared: StatusItemController?
    static let popoverWidth: CGFloat = 330

    private var statusItem: NSStatusItem
    private var statsStatusItem: NSStatusItem?
    struct SegmentMetrics {
        var segments: [(stat: QuitXConfig.MenuBarStat, width: CGFloat)] = []
        var sepWidth: CGFloat = 0

        func hit(atOffset offset: CGFloat) -> (stat: QuitXConfig.MenuBarStat, midX: CGFloat)? {
            guard !segments.isEmpty else { return nil }
            var cursor: CGFloat = 0
            for (index, segment) in segments.enumerated() {
                let end = cursor + segment.width
                let isLast = index == segments.count - 1
                if isLast || offset < end + sepWidth / 2 {
                    return (segment.stat, cursor + segment.width / 2)
                }
                cursor = end + sepWidth
            }
            return nil
        }
    }
    private var segmentMetrics = SegmentMetrics()
    private var window: ArrowPopoverWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var globalEventMonitor: Any?
    private var resignAppObserver: NSObjectProtocol?
    private var localEventMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var liveMonitoringTask: Task<Void, Never>?
    private var lastCloseTimestamp: Date = .distantPast
    private var openTimestamp: Date = .distantPast
    private var workspaceObservers: [NSObjectProtocol] = []
    private var backgroundRefreshTask: Task<Void, Never>?
    private var liveTickCount = 0
    private var lastThrottled = false
    private var menuStatsTask: Task<Void, Never>?
    private var resignKeyObserver: NSObjectProtocol?
    private var updateObservers: Set<AnyCancellable> = []
    private var portConfigObserver: AnyCancellable?

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
        observeUpdates()
        observePortSettings()
        QuickCleanMonitor.shared.onChange = { [weak self] in
            self?.updateMenuBarStats()
        }
    }

    private func observePortSettings() {
        portConfigObserver = ConfigStore.shared.$config
            .map { [$0.portsEnabled ? 1 : 0, $0.portsShowMenuBarCount ? 1 : 0, $0.portsRefreshSeconds, $0.portsIncludeUDP ? 1 : 0]}
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let ports = PortListViewModel.shared
                if ConfigStore.shared.config.portsEnabled {
                    ports.stopAutoRefresh()
                } else {
                    ports.clearWhenDisabled()
                }
                self.syncPortMonitoring()
                self.updateMenuBarPortCount(ConfigStore.shared.config.portsEnabled && ports.hasLoadedOnce ? ports.listenerCount : nil)
                self.updatePopoverSize()
            }
    }

    var isPortsTabActive: Bool {
        ConfigStore.shared.config.portsEnabled && AppListViewModel.shared.activeTab == .ports
    }

    func syncPortMonitoring() {
        let config = ConfigStore.shared.config
        let ports = PortListViewModel.shared
        guard config.portsEnabled else {
            ports.stopAutoRefresh()
            updateMenuBarPortCount(nil)
            return
        }
        if isShown && isPortsTabActive {
            ports.startAutoRefresh()
        } else if config.portsShowMenuBarCount {
            ports.startAutoRefresh(interval: config.portsRefreshSeconds)
        } else {
            ports.stopAutoRefresh()
        }
    }

    private var menuBarPortCount: Int?
    private var detailSampleTask: Task<Void, Never>?
    private var lastMenuBarSample: MenuBarSample?
    private var popoverResizeScheduled = false

    func updateMenuBarPortCount(_ count: Int?) {
        let config = ConfigStore.shared.config
        let visible = (config.portsEnabled && config.portsShowMenuBarCount) ? count : nil
        guard visible != menuBarPortCount || (visible != nil && statsStatusItem == nil) else { return }
        menuBarPortCount = visible
        updateMenuBarStats(sample: lastMenuBarSample)
    }

    static func showsPortCount(_ config: QuitXConfig, count: Int?) -> Bool {
        config.portsEnabled && config.portsShowMenuBarCount && count != nil
    }

    func scheduleUpdatePopoverSize() {
        guard !popoverResizeScheduled else { return }
        popoverResizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.popoverResizeScheduled = false
            self.updatePopoverSize()
        }
    }

    private func observeUpdates() {
        UpdateChecker.shared.$availableUpdate
            .map { $0 != nil }
            .combineLatest(UpdateDownloadService.shared.$state.map { state -> Bool in
                if case .ready = state { return true }
                return false
            })
            .map { $0 || $1 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                self?.updateBadge(show: show)
            }
            .store(in: &updateObservers)
    }

    private func updateBadge(show: Bool) {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        let name = "quitxUpdateDot"
        let existing = button.layer?.sublayers?.first { $0.name == name }
        guard show else {
            existing?.removeFromSuperlayer()
            button.setAccessibilityLabel(QuitXConstants.appName)
            button.toolTip = QuitXConstants.appName
            return
        }
        let dot = existing ?? CALayer()
        dot.name = name
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.borderColor = NSColor.windowBackgroundColor.cgColor
        dot.borderWidth = 1
        let size: CGFloat = 7
        dot.frame = CGRect(x: button.bounds.maxX - size - 2, y: button.bounds.maxY - size - 3, width: size, height: size)
        dot.cornerRadius = size / 2
        if existing == nil { button.layer?.addSublayer(dot) }
        button.setAccessibilityLabel("\(QuitXConstants.appName), update available")
        button.toolTip = "\(QuitXConstants.appName) — update available"
    }

    static func updateMenuTitle(availableVersion: String?, state: UpdateState) -> String? {
        switch state {
        case .ready(_, let version):
            return "Restart to Update to v\(version)"
        case .downloading, .extracting:
            return availableVersion.map { "Downloading v\($0)…" }
        default:
            return availableVersion.map { "Update to v\($0)…" }
        }
    }

    static var redDot: NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    deinit {
        refreshTask?.cancel()
        liveMonitoringTask?.cancel()
        backgroundRefreshTask?.cancel()
        menuStatsTask?.cancel()
        NSStatusBar.system.removeStatusItem(statusItem)
        if let statsStatusItem { NSStatusBar.system.removeStatusItem(statsStatusItem) }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        if let resignAppObserver {
            NotificationCenter.default.removeObserver(resignAppObserver)
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
        let path1x = Bundle.main.path(forResource: "status-icon", ofType: "png") ?? "Support/Icons/status-icon.png"
        let path2x = Bundle.main.path(forResource: "status-icon@2x", ofType: "png") ?? "Support/Icons/status-icon@2x.png"

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
                if Date().timeIntervalSince(self.openTimestamp) < 0.25 {
                    if !NSApp.isActive {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    self.window?.makeKeyAndOrderFront(nil)
                    return
                }
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
        let portsEnabled = ConfigStore.shared.config.portsEnabled
        let tabBarHeight: CGFloat = portsEnabled ? 29 : 0
        let count: Int
        let groupHeaders: Int
        if isPortsTabActive {
            let ports = PortListViewModel.shared
            count = ports.hasLoadedOnce ? ports.visibleCount : 0
            groupHeaders = ports.hasLoadedOnce ? ports.visibleGroupCount : 0
        } else {
            count = vm.filteredApps.count
            groupHeaders = 0
        }
        let calculated: CGFloat
        if count == 0 {
            calculated = 175 + tabBarHeight
        } else {
            let baseHeight: CGFloat = 94 + tabBarHeight
            let rowHeight: CGFloat = 27
            calculated = baseHeight + (CGFloat(count) * rowHeight) + CGFloat(groupHeaders) * 17
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
        PortListViewModel.shared.pendingKillConfirmation = nil
        if isShown {
            lastCloseTimestamp = Date()
        }
        stopLiveMonitoring()
        removeOutsideClickMonitor()
        window?.orderOut(nil)
        syncPortMonitoring()
    }

    @MainActor
    func showPopover() {
        lastCloseTimestamp = .distantPast
        if !isShown {
            togglePopover()
        } else {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            window?.makeKeyAndOrderFront(nil)
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
            openTimestamp = Date()
            updatePopoverSize()
            win.prepareForDisplay()
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            win.makeKeyAndOrderFront(nil)
            win.makeFirstResponder(nil)
            AppListViewModel.shared.syncOptionKey()
            refreshVisibleApps()
            installOutsideClickMonitor()
            startLiveMonitoring()
            if isPortsTabActive { PortListViewModel.shared.randomizeQuote() }
            syncPortMonitoring()
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
                let throttled = BatterySaver.isLowPowerMode
                if throttled != self.lastThrottled {
                    self.liveTickCount = 0
                    self.lastThrottled = throttled
                }
                self.liveTickCount += 1
                let skip = throttled && self.liveTickCount % 5 != 0
                if !skip {
                    if !self.isPortsTabActive {
                        await AppListViewModel.shared.updateLiveStats()
                    }
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

    struct MenuBarSample: Sendable {
        let cpu: Double
        let memoryUsed: UInt64
        let battery: BatteryMenuBarSnapshot?
        let gpu: GpuUsageService.Snapshot?
    }

    nonisolated static func sampleMenuBar(config cfg: QuitXConfig, cpu: Double? = nil, memoryUsed: UInt64? = nil) -> MenuBarSample {
        let powerSources = cfg.batteryMenuBarEnabled ? BatterySaver.currentDescriptions() : nil
        return MenuBarSample(
            cpu: cpu ?? SystemUsage.cpuPercent(consumer: "menuBar"),
            memoryUsed: memoryUsed ?? SystemUsage.memoryUsedBytes(),
            battery: cfg.batteryMenuBarEnabled
                ? BatteryDetailSampler.menuBarSnapshot(descriptions: powerSources)
                : nil,
            gpu: cfg.menuBarShowGpu ? GpuUsageService.snapshot() : nil
        )
    }

    func updateMenuBarStats(sample providedSample: MenuBarSample? = nil) {
        let cfg = ConfigStore.shared.config.hardwareAdjusted
        let statsOn = cfg.menuBarStatsEnabled
        let portCount = Self.showsPortCount(cfg, count: menuBarPortCount) ? menuBarPortCount : nil
        guard statsOn || portCount != nil else {
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

        let sample: MenuBarSample? = statsOn ? (providedSample ?? lastMenuBarSample ?? Self.sampleMenuBar(config: cfg)) : nil
        if let sample { lastMenuBarSample = sample }
        let showCpu = statsOn && cfg.menuBarShowCpu
        let showMemory = statsOn && cfg.menuBarShowMemory
        let cpu = sample?.cpu ?? 0
        let memoryUsed = sample?.memoryUsed ?? 0
        let battery = statsOn && cfg.batteryMenuBarEnabled ? sample?.battery : nil
        let gpu = statsOn && cfg.menuBarShowGpu ? sample?.gpu : nil

        let cpuText = showCpu ? BatterySaver.percentText(cpu) : "off"
        let memText = showMemory ? BatterySaver.compactMemoryText(bytes: memoryUsed, unit: cfg.menuBarMemoryUnit) : "off"
        let gpuText = gpu.map { BatterySaver.percentText($0.deviceUtilization) } ?? "off"
        let batteryKey = battery.map { "\($0.percent)-\($0.isCharging)-\($0.isACPower)" } ?? "none"
        let gpuKey = gpu.map { "\(Int($0.deviceUtilization.rounded()))-\($0.memoryUsedBytes)" } ?? "none"
        let portKey = portCount.map(String.init) ?? "none"
        let showCleanup = statsOn && cfg.menuBarShowCleanup
        if showCleanup {
            QuickCleanMonitor.shared.refreshIfStale(maxAge: QuickCleanMonitor.menuBarMaxAge)
        }
        let cleanupText = showCleanup ? Self.cleanupText(QuickCleanMonitor.shared.reclaimableBytes) : "off"
        let order = cfg.orderedMenuBarStats
        let titleKey = "\(order.map(\.rawValue).joined(separator: ","))|\(cleanupText)|\(cfg.menuBarStatStyle.rawValue)|\(showCpu)|\(showMemory)|\(cfg.menuBarShowGpu)|\(cpuText)|\(memText)|\(gpuKey)|\(batteryKey)|\(portKey)"
        if titleKey == lastStatTitleKey {
            return
        }

        let cpuAttr: NSAttributedString? = showCpu ? Self.statSegmentTitle(
            symbolNames: ["cpu"],
            fallback: "CPU",
            text: cpuText,
            style: cfg.menuBarStatStyle
        ) : nil

        let memAttr: NSAttributedString? = showMemory ? Self.statSegmentTitle(
            symbolNames: ["memorychip", "internaldrive"],
            fallback: "MEM",
            text: memText,
            style: cfg.menuBarStatStyle
        ) : nil

        let gpuAttr: NSAttributedString? = gpu.map { _ in
            Self.statSegmentTitle(
                symbolNames: ["cube.transparent", "square.grid.2x2"],
                fallback: "GPU",
                text: gpuText,
                style: cfg.menuBarStatStyle
            )
        }

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

        let portAttr: NSAttributedString? = portCount.map {
            Self.statSegmentTitle(
                symbolNames: ["network"],
                fallback: "PORTS",
                text: "\($0)",
                style: cfg.menuBarStatStyle
            )
        }
        let cleanupAttr: NSAttributedString? = showCleanup ? Self.statSegmentTitle(
            symbolNames: ["sparkles", "trash"],
            fallback: "CLEAN",
            text: cleanupText,
            style: cfg.menuBarStatStyle
        ) : nil
        let candidates: [QuitXConfig.MenuBarStat: NSAttributedString?] = [
            .cpu: cpuAttr, .gpu: gpuAttr, .memory: memAttr, .battery: batAttr, .ports: portAttr, .cleanup: cleanupAttr
        ]
        let attributes = candidates.compactMapValues { $0 }
        let fullTitle = NSMutableAttributedString()
        var segments: [(stat: QuitXConfig.MenuBarStat, width: CGFloat)] = []
        for stat in order {
            guard let attr = attributes[stat] else { continue }
            if !segments.isEmpty { fullTitle.append(sepAttr) }
            fullTitle.append(attr)
            segments.append((stat, attr.size().width))
        }
        let didAppend = !segments.isEmpty
        guard didAppend else {
            removeStatsItem()
            return
        }

        button.attributedTitle = fullTitle
        lastStatTitleKey = titleKey

        segmentMetrics = SegmentMetrics(segments: segments, sepWidth: sepAttr.size().width)
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
            showContextMenu(anchor: button)
            return
        }

        let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
        let fullWidth = button.attributedTitle.size().width
        let titleInsetX = max(0, (button.bounds.width - fullWidth) / 2)
        let contentStartX = buttonScreenRect.minX + titleInsetX
        let hit = segmentMetrics.hit(atOffset: NSEvent.mouseLocation.x - contentStartX)
        if hit?.stat == .ports {
            StatsDetailController.shared.close()
            AppListViewModel.shared.selectTab(.ports)
            showPopover()
            return
        }
        let mode = hit.map { Self.detailMode(for: $0.stat) } ?? .cpu
        let anchorX = contentStartX + (hit?.midX ?? 0)
        StatsDetailController.shared.toggle(from: button, mode: mode, anchorScreenX: anchorX)
    }

    static func detailMode(for stat: QuitXConfig.MenuBarStat) -> StatsDetailModel.Mode {
        switch stat {
        case .cpu, .ports: .cpu
        case .gpu: .gpu
        case .memory: .memory
        case .battery: .battery
        case .cleanup: .cleanup
        }
    }

    static func cleanupText(_ bytes: Int64?) -> String {
        guard let bytes else { return "…" }
        return QuickCleanService.format(bytes)
    }

    func startMenuBarStats() {
        menuStatsTask?.cancel()
        SystemUsage.prime()
        let initialConfig = ConfigStore.shared.config.hardwareAdjusted
        updateMenuBarStats(sample: initialConfig.menuBarStatsEnabled ? Self.sampleMenuBar(config: initialConfig) : nil)
        StatsDetailController.shared.refreshIntervalChanged()
        menuStatsTask = Task { @MainActor [weak self] in
            var interval = BatterySaver.menuBarInterval(refreshSeconds: initialConfig.menuBarRefreshSeconds, lowPowerMode: BatterySaver.isLowPowerMode)
            var elapsed: UInt64 = 0
            while true {
                try? await Task.sleep(nanoseconds: interval > elapsed ? interval - elapsed : 0)
                guard !Task.isCancelled, let self else { break }
                let started = DispatchTime.now().uptimeNanoseconds
                let cfg = ConfigStore.shared.config.hardwareAdjusted
                guard cfg.menuBarStatsEnabled else {
                    self.updateMenuBarStats(sample: nil)
                    interval = 5_000_000_000
                    elapsed = 0
                    continue
                }
                interval = BatterySaver.menuBarInterval(refreshSeconds: cfg.menuBarRefreshSeconds, lowPowerMode: BatterySaver.isLowPowerMode)
                if StatsDetailController.shared.isVisible {
                    elapsed = 0
                    continue
                }
                let sample = await Task.detached(priority: .utility) {
                    StatusItemController.sampleMenuBar(config: cfg)
                }.value
                guard !Task.isCancelled else { break }
                self.updateMenuBarStats(sample: sample)
                elapsed = DispatchTime.now().uptimeNanoseconds &- started
            }
        }
    }

    func applyDetailSample(cpu: Double, memoryUsed: UInt64) {
        let cfg = ConfigStore.shared.config.hardwareAdjusted
        guard cfg.menuBarStatsEnabled else { return }
        detailSampleTask?.cancel()
        detailSampleTask = Task { @MainActor [weak self] in
            let sample = await Task.detached(priority: .utility) {
                StatusItemController.sampleMenuBar(config: cfg, cpu: cpu, memoryUsed: memoryUsed)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.updateMenuBarStats(sample: sample)
        }
    }

    private func stopLiveMonitoring() {
        liveMonitoringTask?.cancel()
        liveMonitoringTask = nil
    }

    private func showContextMenu(anchor: NSStatusBarButton? = nil) {
        closePopover()
        StatsDetailController.shared.close()
        let menu = NSMenu()
        menu.autoenablesItems = false

        let updateState = UpdateDownloadService.shared.state
        if let title = Self.updateMenuTitle(
            availableVersion: UpdateChecker.shared.availableUpdate?.version,
            state: updateState
        ) {
            let isReady: Bool
            if case .ready = updateState { isReady = true } else { isReady = false }
            let updateItem = NSMenuItem(
                title: title,
                action: isReady ? #selector(restartToUpdate) : #selector(showAvailableUpdate),
                keyEquivalent: ""
            )
            updateItem.target = self
            updateItem.image = Self.redDot
            menu.addItem(updateItem)
            menu.addItem(.separator())
        }

        menu.addItem(MenuHelper.makeItem(
            title: "Uninstall Apps",
            action: #selector(openUninstaller),
            target: self,
            systemSymbolName: "trash"
        ))

        menu.addItem(.separator())

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
            title: "What's New",
            action: #selector(openChangelog),
            target: self,
            keyEquivalent: "n",
            systemSymbolName: "sparkles"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Check for Updates",
            action: #selector(checkForUpdates),
            target: self,
            keyEquivalent: "u",
            systemSymbolName: "arrow.triangle.2.circlepath"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "About QuitX",
            action: #selector(openAbout),
            target: self,
            keyEquivalent: "i",
            assetName: "preferences-about",
            systemSymbolName: "info.circle"
        ))

        menu.addItem(MenuHelper.makeItem(
            title: "Buy me a coffee",
            action: #selector(openBuyMeACoffee),
            target: self,
            systemSymbolName: "cup.and.saucer.fill"
        ))

        menu.addItem(.separator())

        menu.addItem(MenuHelper.makeItem(
            title: "Quit QuitX",
            action: #selector(quitApp),
            target: self,
            keyEquivalent: "q",
            assetName: "settings-quit",
            systemSymbolName: "power"
        ))

        if let button = anchor ?? statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    @objc private func openUninstaller() {
        UninstallWindowController.shared.showPicker()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAbout() {
        SettingsWindowController.shared.show(tab: .about)
    }

    @objc private func openBuyMeACoffee() {
        NSWorkspace.shared.open(QuitXConstants.buyMeACoffeeURL)
    }

    @objc private func showAvailableUpdate() {
        UpdateChecker.shared.presentAvailableUpdate()
    }

    @objc private func restartToUpdate() {
        UpdateChecker.shared.restartToUpdate()
    }

    @objc private func checkForUpdates() {
        Task {
            await UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
        }
    }

    @objc private func openHelp() {
        HelpWindowController.shared.show()
    }

    @objc private func openChangelog() {
        ChangelogWindowController.shared.show()
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
                    } else if chars == "n" {
                        self.closePopover()
                        ChangelogWindowController.shared.show()
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
                if Date().timeIntervalSince(self.openTimestamp) >= 0.25 {
                    self.closePopover()
                }
            }
            return event
        }
    }

    private func installOutsideClickMonitor() {
        if resignAppObserver == nil {
            resignAppObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if Date().timeIntervalSince(self.openTimestamp) < 0.25 {
                        if !NSApp.isActive {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        return
                    }
                    self.closePopover()
                }
            }
        }
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.isShown else { return }
            if Date().timeIntervalSince(self.openTimestamp) < 0.25 {
                return
            }

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
        if let observer = resignAppObserver {
            NotificationCenter.default.removeObserver(observer)
            resignAppObserver = nil
        }
    }
}
