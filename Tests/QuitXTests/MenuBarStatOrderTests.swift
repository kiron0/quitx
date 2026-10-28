import Foundation
import Testing
@testable import QuitX

@Suite("Menu bar stat order")
struct MenuBarStatOrderTests {
    typealias Stat = QuitXConfig.MenuBarStat

    @Test("Default order keeps the classic layout")
    func defaultOrder() {
        #expect(QuitXConfig.default.orderedMenuBarStats == [.cpu, .gpu, .memory, .battery, .ports, .cleanup])
    }

    @Test("Normalizing drops duplicates and slots missing stats after their default neighbour")
    func normalizing() {
        #expect(Stat.normalized([]) == Stat.defaultOrder)
        #expect(Stat.normalized([.battery, .cpu, .battery]) == [.battery, .ports, .cleanup, .cpu, .gpu, .memory])
        #expect(Stat.normalized([.memory]) == [.cpu, .gpu, .memory, .battery, .ports, .cleanup])
        #expect(Stat.normalized([.ports, .battery, .memory, .gpu, .cpu]) == [.ports, .cleanup, .battery, .memory, .gpu, .cpu])
    }

    @Test("Moving a stat lands it on the target slot in either direction")
    func moving() {
        let order: [Stat] = [.cpu, .gpu, .memory, .battery, .ports, .cleanup]
        #expect(Stat.moving(.cpu, onto: .battery, in: order) == [.gpu, .memory, .battery, .cpu, .ports, .cleanup])
        #expect(Stat.moving(.battery, onto: .cpu, in: order) == [.battery, .cpu, .gpu, .memory, .ports, .cleanup])
        #expect(Stat.moving(.memory, onto: .memory, in: order) == order)
        #expect(Stat.moving(.ports, onto: .gpu, in: [.cpu]) == [.cpu, .ports, .gpu, .memory, .battery, .cleanup])
        #expect(Stat.moving(.cleanup, onto: .cpu, in: order) == [.cleanup, .cpu, .gpu, .memory, .battery, .ports])
    }

    @Test("Stored order survives a round trip and tolerates junk")
    func coding() throws {
        var config = QuitXConfig.default
        config.menuBarStatOrder = [.cleanup, .battery, .memory, .cpu, .gpu, .ports]
        config.menuBarShowCleanup = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: data)
        #expect(decoded.menuBarStatOrder == [.cleanup, .battery, .memory, .cpu, .gpu, .ports])
        #expect(decoded.menuBarShowCleanup)

        let junk = #"{"menuBarStatOrder": ["battery", "disk", "battery", "cpu"]}"#
        let repaired = try JSONDecoder().decode(QuitXConfig.self, from: Data(junk.utf8))
        #expect(repaired.menuBarStatOrder == [.battery, .ports, .cleanup, .cpu, .gpu, .memory])

        let wrongType = #"{"menuBarStatOrder": 7}"#
        let fallback = try JSONDecoder().decode(QuitXConfig.self, from: Data(wrongType.utf8))
        #expect(fallback.menuBarStatOrder == Stat.defaultOrder)

        let empty = try JSONDecoder().decode(QuitXConfig.self, from: Data("{}".utf8))
        #expect(empty.menuBarStatOrder == Stat.defaultOrder)
        #expect(!empty.menuBarShowCleanup)
    }

    @Test("Settings chips hide stats this Mac can't show")
    func visibleChips() {
        var config = QuitXConfig.default
        config.menuBarStatOrder = [.battery, .ports, .gpu, .memory, .cpu, .cleanup]
        #expect(MenuBarStatChips.visibleStats(in: config, hasBattery: false, hasGpu: false) == [.memory, .cpu, .cleanup])
        config.portsEnabled = true
        #expect(MenuBarStatChips.visibleStats(in: config, hasBattery: true, hasGpu: true) == [.battery, .ports, .gpu, .memory, .cpu, .cleanup])
    }

    @Test("Click hit-testing follows the custom order")
    @MainActor
    func hitTesting() {
        let metrics = StatusItemController.SegmentMetrics(
            segments: [(.battery, 40), (.cpu, 30), (.ports, 20)],
            sepWidth: 10
        )
        #expect(metrics.hit(atOffset: 5)?.stat == .battery)
        #expect(metrics.hit(atOffset: 5)?.midX == 20)
        #expect(metrics.hit(atOffset: 44)?.stat == .battery)
        #expect(metrics.hit(atOffset: 46)?.stat == .cpu)
        #expect(metrics.hit(atOffset: 60)?.midX == 65)
        #expect(metrics.hit(atOffset: 86)?.stat == .ports)
        #expect(metrics.hit(atOffset: 500)?.stat == .ports)
        #expect(metrics.hit(atOffset: -50)?.stat == .battery)
        #expect(StatusItemController.SegmentMetrics().hit(atOffset: 0) == nil)
        #expect(metrics.midX(of: .ports) == 100)
        #expect(metrics.midX(of: .battery) == 20)
        #expect(metrics.midX(of: .gpu) == nil)
        #expect(StatusItemController.detailMode(for: .battery) == .battery)
        #expect(StatusItemController.detailMode(for: .gpu) == .gpu)
        #expect(StatusItemController.detailMode(for: .memory) == .memory)
        #expect(StatusItemController.detailMode(for: .cleanup) == .cleanup)
        #expect(StatusItemController.cleanupText(nil) == "…")
        #expect(StatusItemController.cleanupText(2_000_000_000) == QuickCleanService.format(2_000_000_000))
    }

    @Test("Cleanup alone turns menu bar stats on")
    func cleanupEnablesStats() {
        var config = QuitXConfig.default
        config.showMenuBarStats = true
        config.menuBarShowCpu = false
        config.menuBarShowMemory = false
        config.menuBarShowGpu = false
        config.batteryMenuBarEnabled = false
        #expect(!config.menuBarStatsEnabled(hasBattery: true, hasGpu: true))
        config.menuBarShowCleanup = true
        #expect(config.menuBarStatsEnabled(hasBattery: false, hasGpu: false))
        #expect(config.menuBarStatsEnabled)
    }

    @Test("Chip rows wrap only when the next chip overflows")
    func chipRows() {
        #expect(ChipFlowLayout.rows(widths: [80, 80, 80], maxWidth: 300, spacing: 5) == [[0, 1, 2]])
        #expect(ChipFlowLayout.rows(widths: [80, 80, 80, 80], maxWidth: 300, spacing: 5) == [[0, 1, 2], [3]])
        #expect(ChipFlowLayout.rows(widths: [400, 50], maxWidth: 300, spacing: 5) == [[0], [1]])
        #expect(ChipFlowLayout.rows(widths: [], maxWidth: 300, spacing: 5).isEmpty)
    }
}
