import AppKit
import SwiftUI

enum RescueReason {
    case cpu(Double)
    case memory

    var title: String {
        switch self {
        case .cpu: return "High CPU usage"
        case .memory: return "Memory pressure"
        }
    }

    var detail: String {
        switch self {
        case .cpu(let value):
            return String(
                format: "System CPU stayed at %.0f%%. QuitX wants to quit inactive apps. Your call.",
                value
            )
        case .memory:
            return "Memory is running out. QuitX wants to quit high-memory inactive apps. Your call."
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: return "gauge.with.dots.needle.67percent"
        case .memory: return "memorychip"
        }
    }
}

final class RescueConsentPanel: NSPanel {
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
final class RescueConsentController {
    static let shared = RescueConsentController()
    nonisolated static let promptCooldown: TimeInterval = 60
    fileprivate static let maxListedNames = 6

    private var window: RescueConsentPanel?
    private var resignObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var lastPromptDate: Date = .distantPast
    private var pendingTargets: [AppInfo] = []
    private var lastPayload: (targets: [AppInfo], reason: RescueReason)?

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    nonisolated static func shouldPrompt(
        lastPrompt: Date,
        now: Date,
        cooldown: TimeInterval = RescueConsentController.promptCooldown
    ) -> Bool {
        now.timeIntervalSince(lastPrompt) >= cooldown
    }

    func request(targets: [AppInfo], reason: RescueReason) {
        guard !targets.isEmpty else { return }
        let now = Date()
        guard isVisible || Self.shouldPrompt(lastPrompt: lastPromptDate, now: now) else { return }
        lastPromptDate = now
        present(targets: targets, reason: reason)
    }

    func confirm() {
        let targets = pendingTargets
        close()
        guard !targets.isEmpty else { return }
        Task {
            await AppListViewModel.shared.quitSilently(targets: targets, force: true)
        }
    }

    func cancel() {
        close()
    }

    func reopenFromNotification() {
        if isVisible {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        if let payload = lastPayload, !payload.targets.isEmpty {
            lastPromptDate = Date()
            present(targets: payload.targets, reason: payload.reason)
            return
        }
        StatusItemController.shared?.showPopover()
    }

    private func close() {
        window?.orderOut(nil)
        pendingTargets = []
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func present(targets: [AppInfo], reason: RescueReason) {
        pendingTargets = targets
        lastPayload = (targets, reason)
        StatusItemController.shared?.closePopover()

        let hostView = NSHostingView(
            rootView: RescueConsentView(
                reason: reason,
                targetNames: targets.map(\.name),
                onConfirm: { [weak self] in self?.confirm() },
                onCancel: { [weak self] in self?.cancel() }
            )
        )

        let win: RescueConsentPanel
        if let existing = window {
            win = existing
        } else {
            win = RescueConsentPanel()
            window = win
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: win,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.close() }
            }
        }
        win.contentView = hostView

        let size = hostView.fittingSize
        win.setContentSize(size)

        var originX = (NSScreen.main?.visibleFrame.width ?? 800) / 2 - size.width / 2
        var originY = (NSScreen.main?.visibleFrame.maxY ?? 900) - size.height - 60
        if let button = StatusItemController.shared?.statusBarButton,
           let buttonWindow = button.window {
            let buttonRect = buttonWindow.convertToScreen(button.bounds)
            originX = buttonRect.midX - size.width / 2
            originY = buttonRect.minY - size.height - 2
            if let screen = buttonWindow.screen ?? NSScreen.main {
                originX = max(screen.visibleFrame.minX + 4,
                              min(originX, screen.visibleFrame.maxX - size.width - 4))
            }
        }
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)

        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self, event.keyCode == 53 else { return event }
                self.cancel()
                return nil
            }
        }

        win.makeKeyAndOrderFront(nil)
    }
}

struct RescueConsentView: View {
    let reason: RescueReason
    let targetNames: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let containerShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    private var listedNames: [String] {
        Array(targetNames.prefix(RescueConsentController.maxListedNames))
    }

    private var overflowCount: Int {
        max(0, targetNames.count - RescueConsentController.maxListedNames)
    }

    private var confirmTitle: String {
        targetNames.count == 1 ? "Quit 1 app" : "Quit \(targetNames.count) apps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: reason.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(reason.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            Text(reason.detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(listedNames, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "app")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary)
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                    }
                }
                if overflowCount > 0 {
                    Text("+\(overflowCount) more")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack(spacing: 8) {
                Spacer()
                consentButton(title: "Cancel", style: .neutral, action: onCancel)
                consentButton(title: confirmTitle, style: .destructive, action: onConfirm)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: containerShape)
            } else {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                    .clipShape(containerShape)
            }
        }
        .overlay {
            containerShape
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .clipShape(containerShape)
    }

    private enum ButtonStyle {
        case neutral
        case destructive
    }

    private func consentButton(title: String, style: ButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(style == .destructive ? Color.white : Color.primary)
        .background {
            Capsule()
                .fill(style == .destructive ? Color(red: 240/255, green: 70/255, blue: 50/255) : Color.primary.opacity(0.1))
        }
    }
}
