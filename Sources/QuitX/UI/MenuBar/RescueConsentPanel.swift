import AppKit
import SwiftUI

enum RescueReason {
    case cpu(value: Double, limit: Double)
    case memory
    case battery(percent: Double, threshold: Double)

    var title: String {
        switch self {
        case .cpu: return "High CPU usage"
        case .memory: return "Memory pressure"
        case .battery: return "Low battery"
        }
    }

    var detail: String {
        switch self {
        case .cpu(let value, let limit):
            return String(
                format: "System CPU stayed at %.0f%% (limit %.0f%%). QuitX wants to quit inactive apps. Your call.",
                value,
                limit
            )
        case .memory:
            return "Memory is running out. QuitX wants to quit high-memory inactive apps. Your call."
        case .battery(let percent, let threshold):
            return String(
                format: "Battery is at %.0f%% (limit %.0f%%). QuitX wants to quit inactive apps to save power. Your call.",
                percent,
                threshold
            )
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: return "gauge.with.dots.needle.67percent"
        case .memory: return "memorychip"
        case .battery: return "batterymedium"
        }
    }
}

@MainActor
final class RescueConsentController {
    static let shared = RescueConsentController()
    nonisolated static let promptCooldown: TimeInterval = 60
    fileprivate static let maxListedTargets = 6

    private var window: ArrowPopoverWindow?
    private var lastPromptDate: Date = .distantPast
    private var frontmostAtShow: NSRunningApplication?
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

    func confirm(selected: [AppInfo]) {
        close()
        guard !selected.isEmpty else { return }
        Task {
            await AppListViewModel.shared.quitSilently(targets: selected, force: true)
        }
    }

    func cancel() {
        close()
    }

    func reopenFromNotification() {
        if isVisible {
            NSApp.activate(ignoringOtherApps: true)
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

    private func present(targets: [AppInfo], reason: RescueReason) {
        lastPayload = (targets, reason)
        StatusItemController.shared?.closePopover()

        var buttonRect: CGRect? = nil
        var buttonScreen: NSScreen? = nil
        if let button = StatusItemController.shared?.statusBarButton,
           let buttonWindow = button.window {
            buttonRect = buttonWindow.convertToScreen(button.bounds)
            buttonScreen = buttonWindow.screen ?? NSScreen.main
        }

        var arrowX: CGFloat? = nil
        if let buttonRect {
            let width = StatusItemController.popoverWidth
            var x = buttonRect.midX - width / 2
            if let screen = buttonScreen {
                x = max(screen.visibleFrame.minX + 4,
                        min(x, screen.visibleFrame.maxX - width - 4))
            }
            arrowX = buttonRect.midX - x
        }

        let hostView = NSHostingView(
            rootView: RescueConsentView(
                reason: reason,
                targets: targets,
                onConfirm: { [weak self] selected in self?.confirm(selected: selected) },
                onCancel: { [weak self] in self?.cancel() },
                arrowX: arrowX
            )
        )

        let win: ArrowPopoverWindow
        if let existing = window {
            win = existing
        } else {
            win = ArrowPopoverWindow()
            window = win
        }

        let size = hostView.fittingSize
        win.setContentSize(size)

        var originX = (NSScreen.main?.visibleFrame.width ?? 800) / 2 - size.width / 2
        var originY = (NSScreen.main?.visibleFrame.maxY ?? 900) - size.height - 60
        if let buttonRect {
            originX = buttonRect.midX - size.width / 2
            originY = buttonRect.minY - size.height - 2
            if let screen = buttonScreen {
                originX = max(screen.visibleFrame.minX + 4,
                              min(originX, screen.visibleFrame.maxX - size.width - 4))
            }
        }
        win.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        win.contentView = hostView

        frontmostAtShow = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)

        win.makeKeyAndOrderFront(nil)
    }
}

@MainActor
final class ConsentButtonHover: ObservableObject {
    @Published var hovered: String?
}

@MainActor
final class ConsentSelection: ObservableObject {
    @Published var selectedIDs: Set<AppInfo.ID>

    init(targets: [AppInfo]) {
        selectedIDs = Set(targets.map(\.id))
    }

    func toggle(_ id: AppInfo.ID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

struct RescueConsentView: View {
    let reason: RescueReason
    let targets: [AppInfo]
    let onConfirm: ([AppInfo]) -> Void
    let onCancel: () -> Void
    var arrowX: CGFloat? = nil

    @StateObject private var hover = ConsentButtonHover()
    @StateObject private var selection: ConsentSelection

    init(
        reason: RescueReason,
        targets: [AppInfo],
        onConfirm: @escaping ([AppInfo]) -> Void,
        onCancel: @escaping () -> Void,
        arrowX: CGFloat? = nil
    ) {
        self.reason = reason
        self.targets = targets
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.arrowX = arrowX
        _selection = StateObject(wrappedValue: ConsentSelection(targets: targets))
    }

    private var listedTargets: [AppInfo] {
        Array(targets.prefix(RescueConsentController.maxListedTargets))
    }

    private var overflowCount: Int {
        max(0, targets.count - RescueConsentController.maxListedTargets)
    }

    private var selectedTargets: [AppInfo] {
        targets.filter { selection.selectedIDs.contains($0.id) }
    }

    private var confirmTitle: String {
        let count = selectedTargets.count
        return count == 1 ? "Quit 1 app" : "Quit \(count) apps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .frame(height: 14)

            HStack(spacing: 7) {
                Image(systemName: reason.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(reason.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 12)

            Text(reason.detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(listedTargets) { app in
                    consentAppRow(app)
                }
                if overflowCount > 0 {
                    Text("+\(overflowCount) more")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 2)

            HStack(spacing: 8) {
                Spacer()
                consentButton(title: "Cancel", style: .neutral, action: onCancel)
                consentButton(title: confirmTitle, style: .destructive, action: {
                    onConfirm(selectedTargets)
                }, disabled: selectedTargets.isEmpty)
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 16)
        .frame(width: StatusItemController.popoverWidth)
        .arrowPopoverChrome(arrowX: arrowX)
    }

    private func consentAppRow(_ app: AppInfo) -> some View {
        let isSelected = selection.selectedIDs.contains(app.id)
        return Button {
            selection.toggle(app.id)
        } label: {
            HStack(spacing: 7) {
                QuitXSelectionCheckbox(isSelected: isSelected)
                AppIconView(bundleId: app.bundleId, pid: app.pid, size: 18, cornerRadius: 3)
                Text(app.name)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 3.5)
        }
        .buttonStyle(.plain)
    }

    private enum ButtonStyle {
        case neutral
        case destructive
    }

    private func consentButton(
        title: String,
        style: ButtonStyle,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> some View {
        let isHovered = hover.hovered == title && !disabled
        return Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .foregroundStyle(
            disabled
                ? Color.secondary.opacity(0.5)
                : (style == .destructive ? Color.white : (isHovered ? Color.primary : Color.secondary))
        )
        .background {
            Capsule()
                .fill(
                    style == .destructive
                        ? Color(red: 240/255, green: 70/255, blue: 50/255)
                            .opacity(disabled ? 0.35 : (isHovered ? 1.0 : 0.88))
                        : Color.primary.opacity(isHovered ? 0.18 : 0.1)
                )
        }
        .onHover { hover.hovered = $0 ? title : nil }
    }
}
