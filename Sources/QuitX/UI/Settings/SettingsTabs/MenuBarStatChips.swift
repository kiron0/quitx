import SwiftUI

@MainActor
final class MenuBarStatChipState: ObservableObject {
    @Published var targeted: QuitXConfig.MenuBarStat?
}

struct MenuBarStatChips: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = MenuBarStatChipState()

    static func visibleStats(
        in config: QuitXConfig,
        hasBattery: Bool = HardwareCapabilities.hasBattery,
        hasGpu: Bool = HardwareCapabilities.hasGpuStatistics
    ) -> [QuitXConfig.MenuBarStat] {
        config.orderedMenuBarStats.filter { stat in
            switch stat {
            case .cpu, .memory: true
            case .gpu: hasGpu
            case .battery: hasBattery
            case .ports: config.portsEnabled
            case .cleanup: true
            }
        }
    }

    var body: some View {
        ChipFlowLayout(spacing: 5) {
            ForEach(Self.visibleStats(in: configStore.config), id: \.self) { stat in
                chip(stat)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: configStore.config.orderedMenuBarStats)
    }

    private func isOn(_ stat: QuitXConfig.MenuBarStat) -> Bool {
        switch stat {
        case .cpu: configStore.config.menuBarShowCpu
        case .gpu: configStore.config.menuBarShowGpu
        case .memory: configStore.config.menuBarShowMemory
        case .battery: configStore.config.batteryMenuBarEnabled
        case .ports: configStore.config.portsShowMenuBarCount
        case .cleanup: configStore.config.menuBarShowCleanup
        }
    }

    private func isEnabled(_ stat: QuitXConfig.MenuBarStat) -> Bool {
        stat == .ports || configStore.config.showMenuBarStats
    }

    private func setOn(_ stat: QuitXConfig.MenuBarStat, _ value: Bool) {
        switch stat {
        case .cpu: configStore.config.menuBarShowCpu = value
        case .gpu: configStore.config.menuBarShowGpu = value
        case .memory: configStore.config.menuBarShowMemory = value
        case .battery: configStore.config.batteryMenuBarEnabled = value
        case .ports: configStore.config.portsShowMenuBarCount = value
        case .cleanup: configStore.config.menuBarShowCleanup = value
        }
        if stat != .ports {
            configStore.config.showMenuBarStats = configStore.config.availableMenuBarStatsEnabled
        }
        configStore.save()
        StatusItemController.shared?.updateMenuBarStats()
    }

    private func move(_ raw: String?, onto target: QuitXConfig.MenuBarStat) -> Bool {
        state.targeted = nil
        guard let raw, let stat = QuitXConfig.MenuBarStat(rawValue: raw), stat != target else { return false }
        let order = QuitXConfig.MenuBarStat.moving(stat, onto: target, in: configStore.config.menuBarStatOrder)
        guard order != configStore.config.orderedMenuBarStats else { return false }
        configStore.config.menuBarStatOrder = order
        configStore.save()
        StatusItemController.shared?.updateMenuBarStats()
        return true
    }

    private func label(_ stat: QuitXConfig.MenuBarStat, isOn: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .frame(width: 8)
            SettingsSwitchIndicator(isOn: isOn)
            Text(stat.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary)
                .fixedSize()
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(height: 28)
    }

    private func chip(_ stat: QuitXConfig.MenuBarStat) -> some View {
        let on = isOn(stat)
        let enabled = isEnabled(stat)
        let targeted = state.targeted == stat
        return label(stat, isOn: on)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(targeted ? 0.10 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(targeted ? QuitXTheme.accent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.42)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onTapGesture {
                guard enabled else { return }
                withAnimation(.easeInOut(duration: 0.16)) { setOn(stat, !on) }
            }
            .draggable(stat.rawValue) {
                label(stat, isOn: on)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(nsColor: .windowBackgroundColor)))
            }
            .dropDestination(for: String.self) { items, _ in
                move(items.first, onto: stat)
            } isTargeted: { inside in
                if inside {
                    state.targeted = stat
                } else if state.targeted == stat {
                    state.targeted = nil
                }
            }
            .help("Click to show or hide \(stat.title). Drag to reorder.")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stat.title)
            .accessibilityValue(on ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { setOn(stat, !on) } }
    }
}

struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 5

    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var used: CGFloat = 0
        for (index, width) in widths.enumerated() {
            let needed = current.isEmpty ? width : used + spacing + width
            if !current.isEmpty && needed > maxWidth {
                rows.append(current)
                current = [index]
                used = width
            } else {
                current.append(index)
                used = needed
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? .infinity
        let rows = Self.rows(widths: sizes.map(\.width), maxWidth: maxWidth, spacing: spacing)
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            let rowWidth = row.reduce(CGFloat(0)) { $0 + sizes[$1].width } + spacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            width = max(width, rowWidth)
            height += rowHeight + (rowIndex > 0 ? spacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = Self.rows(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: spacing)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            for index in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += rowHeight + spacing
        }
    }
}
