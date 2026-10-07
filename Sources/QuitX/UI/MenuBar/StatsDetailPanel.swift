import AppKit
import SwiftUI

final class StatsDetailWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class StatsDetailModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var arrowX: CGFloat = 115

    private var timer: Timer?

    func start() {
        tick()
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        cpu = SystemUsage.cpuPercent()
        memoryUsed = SystemUsage.memoryUsedBytes()
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }
}

struct StatsDetailView: View {
    @ObservedObject var model: StatsDetailModel
    @ObservedObject private var configStore: ConfigStore = ConfigStore.shared

    private func symbol(_ names: [String]) -> Image {
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                return Image(nsImage: image)
            }
        }
        return Image(systemName: "circle")
    }

    var body: some View {
        let containerShape = PopoverContainerShape(arrowX: model.arrowX, cornerRadius: 14)
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    symbol(["gauge.with.needle"])
                        .font(.system(size: 11, weight: .semibold))
                    Text("QuitX Monitor")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)

                statRow(
                    icon: symbol(["cpu"]),
                    title: "CPU",
                    value: BatterySaver.percentText(model.cpu),
                    detail: "whole system load"
                )

                Divider()

                let isPercent = configStore.config.menuBarMemoryUnit == .percentage
                let memValue = isPercent
                    ? BatterySaver.memoryPercentText(bytes: model.memoryUsed, totalBytes: model.memoryTotal)
                    : MemoryFormatter.format(bytes: model.memoryUsed)
                let memDetail = isPercent
                    ? "\(MemoryFormatter.format(bytes: model.memoryUsed)) of \(MemoryFormatter.format(bytes: model.memoryTotal))"
                    : "of \(MemoryFormatter.format(bytes: model.memoryTotal)) total"

                statRow(
                    icon: symbol(["memorychip", "internaldrive"]),
                    title: "Memory",
                    value: memValue,
                    detail: memDetail
                )
            }
            .padding(16)
        }
        .frame(width: 230, alignment: .leading)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: containerShape)
            } else {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                    .clipShape(containerShape)
            }
        }
        .overlay {
            if #available(macOS 26.0, *) {
                EmptyView()
            } else {
                containerShape
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
        }
        .clipShape(containerShape)
    }

    private func statRow(icon: Image, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            icon
                .font(.system(size: 15))
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
            }
            Spacer(minLength: 0)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: 84, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }
}

@MainActor
final class StatsDetailController {
    static let shared = StatsDetailController()

    private var window: StatsDetailWindow?
    private var model: StatsDetailModel?
    private var outsideMonitor: Any?
    private var localMonitor: Any?
    private var lastCloseTimestamp: Date = .distantPast

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle(from button: NSStatusBarButton) {
        if isVisible {
            close()
        } else {
            if Date().timeIntervalSince(lastCloseTimestamp) < 0.25 {
                return
            }
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        StatusItemController.shared?.closePopover()

        let model = self.model ?? StatsDetailModel()
        self.model = model

        let hostView = NSHostingView(rootView: StatsDetailView(model: model))

        let win: StatsDetailWindow
        if let existing = window {
            win = existing
        } else {
            win = StatsDetailWindow()
            window = win
        }
        win.contentView = hostView

        let size = hostView.fittingSize
        win.setContentSize(size)

        let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
        var originX = buttonScreenRect.midX - size.width / 2
        if let screen = buttonWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4,
                          min(originX, screen.visibleFrame.maxX - size.width - 4))
        }
        let arrowX = max(24, min(buttonScreenRect.midX - originX, size.width - 24))
        model.arrowX = arrowX

        let originY = buttonScreenRect.minY - size.height - 2
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.invalidateShadow()

        model.start()
        win.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func close() {
        guard isVisible else { return }
        lastCloseTimestamp = Date()
        window?.orderOut(nil)
        model?.stop()
        removeMonitors()
    }

    private func installMonitors() {
        guard outsideMonitor == nil else { return }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            if let button = StatusItemController.shared?.statsButton,
               let buttonWindow = button.window {
                let mouseLoc = NSEvent.mouseLocation
                let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
                if buttonScreenRect.contains(mouseLoc) {
                    return
                }
            }
            Task { @MainActor in
                self.close()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.close()
                    return nil
                }
                return event
            }
            let mouseLoc = NSEvent.mouseLocation
            if let win = self.window, !win.frame.contains(mouseLoc) {
                if let button = StatusItemController.shared?.statsButton,
                   let buttonWindow = button.window {
                    let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
                    if buttonScreenRect.contains(mouseLoc) {
                        return event
                    }
                }
                self.close()
            }
            return event
        }
    }

    private func removeMonitors() {
        if let monitor = outsideMonitor {
            NSEvent.removeMonitor(monitor)
            outsideMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
