import AppKit
import SwiftUI

extension Notification.Name {
    static let quitxStatsSample = Notification.Name("QuitXStatsSample")
}

@MainActor
final class StatsDetailModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory

    private var timer: Timer?
    private var sampleObserver: NSObjectProtocol?

    func start() {
        stop()
        tick()
        if ConfigStore.shared.config.showMenuBarStats {
            sampleObserver = NotificationCenter.default.addObserver(
                forName: .quitxStatsSample,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let cpu = note.userInfo?["cpu"] as? Double,
                      let mem = note.userInfo?["mem"] as? UInt64 else { return }
                Task { @MainActor in
                    self?.cpu = cpu
                    self?.memoryUsed = mem
                }
            }
        } else {
            let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let sampleObserver {
            NotificationCenter.default.removeObserver(sampleObserver)
            self.sampleObserver = nil
        }
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
        .arrowPopoverChrome()
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

    private var window: ArrowPopoverWindow?
    private var model: StatsDetailModel?
    private var localMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var lastCloseTimestamp: Date = .distantPast
    private var frontmostAtShow: NSRunningApplication?

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

        let win: ArrowPopoverWindow
        if let existing = window {
            win = existing
        } else {
            win = ArrowPopoverWindow()
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

        let originY = buttonScreenRect.minY - size.height - 2
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.invalidateShadow()

        if resignObserver == nil {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: win,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.close() }
            }
        }

        model.start()
        frontmostAtShow = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func close() {
        guard isVisible else { return }
        lastCloseTimestamp = Date()
        window?.orderOut(nil)
        model?.stop()
        removeMonitors()
        restoreFrontmost()
    }

    private func restoreFrontmost() {
        guard NSApp.isActive,
              let prev = frontmostAtShow,
              prev != NSRunningApplication.current,
              !prev.isTerminated else {
            frontmostAtShow = nil
            return
        }
        frontmostAtShow = nil
        prev.activate(options: [])
    }

    private func installMonitors() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self, self.isVisible, event.keyCode == 53 else { return event }
            self.close()
            return nil
        }
    }

    private func removeMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
