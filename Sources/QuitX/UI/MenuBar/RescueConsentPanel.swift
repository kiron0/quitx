import AppKit
import SwiftUI

enum RescueReason {
    case cpu(value: Double, limit: Double)
    case memory

    var title: String {
        switch self {
        case .cpu: return "High CPU usage"
        case .memory: return "Memory pressure"
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
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: return "gauge.with.dots.needle.67percent"
        case .memory: return "memorychip"
        }
    }
}

@MainActor
final class RescueConsentController {
    static let shared = RescueConsentController()
    nonisolated static let promptCooldown: TimeInterval = 60
    fileprivate static let maxVisibleTargets = 6

    private var window: ArrowPopoverWindow?
    private var lastPromptDate: Date = .distantPast
    private var frontmostAtShow: NSRunningApplication?
    private var lastPayload: (targets: [AppInfo], reason: RescueReason)?

    private init() {}

    var isVisible: Bool { window?.isVisible ?? false }

    var canPrompt: Bool {
        Self.shouldPrompt(isVisible: isVisible, lastPrompt: lastPromptDate, now: Date())
    }

    nonisolated static func shouldPrompt(
        isVisible: Bool = false,
        lastPrompt: Date,
        now: Date,
        cooldown: TimeInterval = RescueConsentController.promptCooldown
    ) -> Bool {
        !isVisible && now.timeIntervalSince(lastPrompt) >= cooldown
    }

    func request(targets: [AppInfo], reason: RescueReason) {
        guard !targets.isEmpty else { return }
        let now = Date()
        guard Self.shouldPrompt(isVisible: isVisible, lastPrompt: lastPromptDate, now: now) else { return }
        lastPromptDate = now
        present(targets: targets, reason: reason)
    }

    func confirm(selected: [AppInfo]) {
        close()
        guard !selected.isEmpty else { return }
        Task {
            await AppListViewModel.shared.quitSilently(targets: selected, force: ConfigStore.shared.config.prefersForceQuit)
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
        removeMonitors()
        window?.orderOut(nil)
        restoreFrontmost()
    }

    private var escapeMonitor: Any?
    private var outsideMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var pendingActiveObserver: NSObjectProtocol?

    private func installMonitors() {
        removeMonitors()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible, event.keyCode == 53 else { return event }
            self.cancel()
            return nil
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.cancel()
        }
        armResignObserver()
    }

    private func armResignObserver() {
        guard resignActiveObserver == nil else { return }
        if NSApp.isActive {
            installResignObserver()
            return
        }
        pendingActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.removePendingActiveObserver()
                self.installResignObserver()
            }
        }
    }

    private func installResignObserver() {
        guard resignActiveObserver == nil else { return }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.cancel()
            }
        }
    }

    private func removePendingActiveObserver() {
        if let o = pendingActiveObserver {
            NotificationCenter.default.removeObserver(o)
            pendingActiveObserver = nil
        }
    }

    private func removeMonitors() {
        if let m = escapeMonitor {
            NSEvent.removeMonitor(m)
            escapeMonitor = nil
        }
        if let m = outsideMonitor {
            NSEvent.removeMonitor(m)
            outsideMonitor = nil
        }
        removePendingActiveObserver()
        if let o = resignActiveObserver {
            NotificationCenter.default.removeObserver(o)
            resignActiveObserver = nil
        }
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

        win.contentView = hostView
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
        win.prepareForDisplay()

        frontmostAtShow = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)

        win.makeKeyAndOrderFront(nil)
        installMonitors()
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

    func selectAll(_ ids: Set<AppInfo.ID>) {
        selectedIDs = ids
    }

    func deselectAll() {
        selectedIDs.removeAll()
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

    private var targetListHeight: CGFloat {
        let visibleCount = min(targets.count, RescueConsentController.maxVisibleTargets)
        return CGFloat(visibleCount) * 29
    }

    private var selectedTargets: [AppInfo] {
        targets.filter { selection.selectedIDs.contains($0.id) }
    }

    private var allTargetIDs: Set<AppInfo.ID> {
        Set(targets.map(\.id))
    }

    private var allSelected: Bool {
        !allTargetIDs.isEmpty && allTargetIDs.isSubset(of: selection.selectedIDs)
    }

    private var partiallySelected: Bool {
        let intersection = selection.selectedIDs.intersection(allTargetIDs)
        return !intersection.isEmpty && intersection.count < allTargetIDs.count
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

            VStack(spacing: 0) {
                Button {
                    if allSelected {
                        selection.deselectAll()
                    } else {
                        selection.selectAll(allTargetIDs)
                    }
                } label: {
                    HStack(spacing: 8) {
                        QuitXSelectionCheckbox(
                            isSelected: allSelected,
                            isPartial: partiallySelected
                        )
                        Text(allSelected ? "Deselect All" : "Select All")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text("\(targets.count) apps")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 27)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ScrollView(.vertical, showsIndicators: targets.count > RescueConsentController.maxVisibleTargets) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(targets) { app in
                            consentAppRow(app)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: targetListHeight)
            }
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                consentButton(title: "Cancel", style: .neutral, action: onCancel)
                consentButton(title: confirmTitle, style: .confirm, action: {
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
                Text(rowStatText(for: app))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 3.5)
        }
        .buttonStyle(.plain)
    }

    private func rowStatText(for app: AppInfo) -> String {
        switch reason {
        case .cpu:
            return app.cpuFormatted
        case .memory:
            return BatterySaver.compactMemoryText(
                bytes: app.memoryBytes,
                unit: ConfigStore.shared.config.menuBarMemoryUnit
            )
        }
    }

    private enum ButtonStyle {
        case neutral
        case confirm
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
                .font(.system(size: 11.5, weight: style == .confirm ? .bold : .medium))
                .foregroundStyle(
                    style == .confirm
                        ? (disabled ? Color.secondary : Color.black.opacity(0.88))
                        : Color.primary.opacity(isHovered ? 1.0 : 0.85)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            style == .confirm
                                ? (disabled
                                    ? AnyShapeStyle(QuitXTheme.accent.opacity(0.35))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )))
                                : AnyShapeStyle(Color.primary.opacity(disabled ? 0.04 : (isHovered ? 0.12 : 0.07)))
                        )
                }
                .overlay {
                    if style == .neutral {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(disabled ? 0.06 : 0.12), lineWidth: 0.5)
                    }
                }
                .shadow(
                    color: style == .confirm && !disabled
                        ? QuitXTheme.accent.opacity(isHovered ? 0.35 : 0.15)
                        : .clear,
                    radius: 2,
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hover.hovered = $0 ? title : nil }
    }
}
