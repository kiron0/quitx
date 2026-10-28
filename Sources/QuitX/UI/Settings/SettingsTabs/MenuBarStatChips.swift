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
            }
        }
    }

    var body: some View {
        HStack(spacing: 5) {
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
