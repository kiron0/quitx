import AppKit
import Foundation

struct LowBatteryRescueGate {
    static let armDelay: TimeInterval = 15
    static let sustainInterval: TimeInterval = 15
    static let hysteresis = 5

    private(set) var lowSince: Date?

    mutating func evaluate(percent: Int, threshold: Int, armedAt: Date?, now: Date) -> Bool {
        guard let armedAt, now.timeIntervalSince(armedAt) >= Self.armDelay else {
            lowSince = nil
            return false
        }
        if percent <= threshold {
            if lowSince == nil { lowSince = now }
            guard let lowSince else { return false }
            return now.timeIntervalSince(lowSince) >= Self.sustainInterval
        }
        if percent > threshold + Self.hysteresis {
            lowSince = nil
        }
        return false
    }

    mutating func reset() {
        lowSince = nil
    }
}

@MainActor
final class BatteryTriggerService {
    static let shared = BatteryTriggerService()
    static let checkInterval: TimeInterval = 15
    static let rescueCooldown: TimeInterval = 60

    private var timer: Timer?
    private var gate = LowBatteryRescueGate()
    private var armedAt: Date?
    private var wasEnabled = false
    private var lastRescueDate: Date = .distantPast

    private init() {}

    func start() {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        gate.reset()
        armedAt = nil
        wasEnabled = false
    }

    private func tick() {
        let config = ConfigStore.shared.config
        if config.batteryQuitEnabled, !wasEnabled {
            armedAt = Date()
            gate.reset()
        }
        wasEnabled = config.batteryQuitEnabled
        guard config.batteryQuitEnabled, let armedAt else { return }
        guard let snapshot = BatteryDetailSampler.snapshot(), !snapshot.isACPower else {
            gate.reset()
            return
        }
        let threshold = config.effectiveBatteryQuitThreshold
        guard gate.evaluate(percent: snapshot.percent, threshold: threshold, armedAt: armedAt, now: Date()) else {
            return
        }
        rescue(percent: Double(snapshot.percent), threshold: Double(threshold), config: config)
    }

    private func rescue(percent: Double, threshold: Double, config: QuitXConfig) {
        guard Date().timeIntervalSince(lastRescueDate) >= Self.rescueCooldown else { return }
        lastRescueDate = Date()
        let vm = AppListViewModel.shared
        Task { @MainActor in
            if Date().timeIntervalSince(vm.lastRefreshDate) > 2.0 {
                await vm.refresh()
            }
            let targets = InactiveRescueTargets.select(
                apps: vm.apps,
                config: config,
                frontmostPid: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                ownPid: ProcessInfo.processInfo.processIdentifier
            )
            guard !targets.isEmpty else { return }
            RescueConsentController.shared.request(
                targets: targets,
                reason: .battery(percent: percent, threshold: threshold)
            )
        }
    }
}
