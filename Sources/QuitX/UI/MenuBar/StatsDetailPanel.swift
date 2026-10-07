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
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class StatsDetailModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory

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

    private func symbol(_ names: [String]) -> Image {
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                return Image(nsImage: image)
            }
        }
        return Image(systemName: "circle")
    }

    var body: some View {
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

            statRow(
                icon: symbol(["memorychip", "internaldrive"]),
                title: "Memory",
                value: MemoryFormatter.format(bytes: model.memoryUsed),
                detail: "of \(MemoryFormatter.format(bytes: model.memoryTotal)) total"
            )
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
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
                .frame(maxWidth: 74, alignment: .trailing)
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

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    func toggle(from button: NSStatusBarButton) {
        if isVisible {
            close()
        } else {
            show(from: button)
        }
    }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let model = self.model ?? StatsDetailModel()
        self.model = model

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        let hostView = NSHostingView(rootView: StatsDetailView(model: model))
        hostView.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(hostView)
        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            hostView.topAnchor.constraint(equalTo: blur.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: blur.bottomAnchor)
        ])

        let win: StatsDetailWindow
        if let existing = window {
            win = existing
        } else {
            win = StatsDetailWindow()
            window = win
        }
        win.contentView = blur

        let size = hostView.fittingSize
        win.setContentSize(size)

        let buttonScreenRect = buttonWindow.convertToScreen(button.bounds)
        var originX = buttonScreenRect.midX - size.width / 2
        if let screen = buttonWindow.screen ?? NSScreen.main {
            originX = max(screen.visibleFrame.minX + 4,
                          min(originX, screen.visibleFrame.maxX - size.width - 4))
        }
        let originY = buttonScreenRect.minY - size.height - 6
        win.setFrameOrigin(NSPoint(x: originX, y: originY))

        model.start()
        win.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func close() {
        window?.orderOut(nil)
        model?.stop()
        removeMonitors()
    }

    private func installMonitors() {
        guard outsideMonitor == nil else { return }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
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
            if let win = self.window, !win.frame.contains(NSEvent.mouseLocation) {
                let button = StatusItemController.shared?.statsButton
                if let button, let buttonWindow = button.window,
                   buttonWindow.convertToScreen(button.bounds).contains(NSEvent.mouseLocation) {
                    return event
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
