import Foundation
import Testing
@testable import QuitX

@Suite("Menu bar stat order")
struct MenuBarStatOrderTests {
    typealias Stat = QuitXConfig.MenuBarStat

    @Test("Default order keeps the classic layout")
    func defaultOrder() {
        #expect(QuitXConfig.default.orderedMenuBarStats == [.cpu, .gpu, .memory, .battery, .ports])
    }

    @Test("Normalizing drops duplicates and slots missing stats after their default neighbour")
    func normalizing() {
        #expect(Stat.normalized([]) == Stat.defaultOrder)
        #expect(Stat.normalized([.battery, .cpu, .battery]) == [.battery, .ports, .cpu, .gpu, .memory])
        #expect(Stat.normalized([.memory]) == [.cpu, .gpu, .memory, .battery, .ports])
        #expect(Stat.normalized([.ports, .battery, .memory, .gpu, .cpu]) == [.ports, .battery, .memory, .gpu, .cpu])
    }

    @Test("Moving a stat lands it on the target slot in either direction")
    func moving() {
        let order: [Stat] = [.cpu, .gpu, .memory, .battery, .ports]
        #expect(Stat.moving(.cpu, onto: .battery, in: order) == [.gpu, .memory, .battery, .cpu, .ports])
        #expect(Stat.moving(.battery, onto: .cpu, in: order) == [.battery, .cpu, .gpu, .memory, .ports])
        #expect(Stat.moving(.memory, onto: .memory, in: order) == order)
        #expect(Stat.moving(.ports, onto: .gpu, in: [.cpu]) == [.cpu, .ports, .gpu, .memory, .battery])
    }

    @Test("Stored order survives a round trip and tolerates junk")
    func coding() throws {
        var config = QuitXConfig.default
        config.menuBarStatOrder = [.battery, .memory, .cpu, .gpu, .ports]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(QuitXConfig.self, from: data)
        #expect(decoded.menuBarStatOrder == [.battery, .memory, .cpu, .gpu, .ports])

        let junk = #"{"menuBarStatOrder": ["battery", "disk", "battery", "cpu"]}"#
        let repaired = try JSONDecoder().decode(QuitXConfig.self, from: Data(junk.utf8))
        #expect(repaired.menuBarStatOrder == [.battery, .ports, .cpu, .gpu, .memory])

        let wrongType = #"{"menuBarStatOrder": 7}"#
        let fallback = try JSONDecoder().decode(QuitXConfig.self, from: Data(wrongType.utf8))
        #expect(fallback.menuBarStatOrder == Stat.defaultOrder)

        let legacy = try JSONDecoder().decode(QuitXConfig.self, from: Data("{}".utf8))
        #expect(legacy.menuBarStatOrder == Stat.defaultOrder)
    }

    @Test("Settings chips hide stats this Mac can't show")
    func visibleChips() {
        var config = QuitXConfig.default
        config.menuBarStatOrder = [.battery, .ports, .gpu, .memory, .cpu]
        #expect(MenuBarStatChips.visibleStats(in: config, hasBattery: false, hasGpu: false) == [.memory, .cpu])
        config.portsEnabled = true
        #expect(MenuBarStatChips.visibleStats(in: config, hasBattery: true, hasGpu: true) == [.battery, .ports, .gpu, .memory, .cpu])
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
        #expect(StatusItemController.detailMode(for: .battery) == .battery)
        #expect(StatusItemController.detailMode(for: .gpu) == .gpu)
        #expect(StatusItemController.detailMode(for: .memory) == .memory)
    }
}
