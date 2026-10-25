import Testing
import Foundation
@testable import QuitX

private final class SlowPortService: PortServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let delay: UInt64

    init(delay: UInt64) {
        self.delay = delay
    }

    var calls: Int { lock.withLock { count } }

    func fetchListeningPorts() async -> [PortInfo] {
        lock.withLock { count += 1 }
        try? await Task.sleep(nanoseconds: delay)
        return [PortInfo(port: 3000, pid: 4242, processName: "node")]
    }

    func refreshStats(for ports: [PortInfo]) async -> [PortInfo] { ports }
    func killPort(_ port: PortInfo, mode: TerminationMode, progress: @escaping @Sendable (String) -> Void) async -> Bool { false }
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int { 0 }
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] { [] }
}

@Suite("Refresh cadence", .serialized)
@MainActor
struct RefreshCadenceTests {
    @Test("Port refresh subtracts scan time from the wait")
    func portRefreshDelay() {
        #expect(PortListViewModel.nextRefreshDelay(intervalSeconds: 1, spentNanoseconds: 0) == 1_000_000_000)
        #expect(PortListViewModel.nextRefreshDelay(intervalSeconds: 1, spentNanoseconds: 600_000_000) == 400_000_000)
        #expect(PortListViewModel.nextRefreshDelay(intervalSeconds: 3, spentNanoseconds: 500_000_000) == 2_500_000_000)
        #expect(PortListViewModel.nextRefreshDelay(intervalSeconds: 1, spentNanoseconds: 5_000_000_000) == 100_000_000)
        #expect(PortListViewModel.nextRefreshDelay(intervalSeconds: 0, spentNanoseconds: 0) == 1_000_000_000)
    }

    @Test("Port auto refresh keeps scanning and updates the count")
    func portAutoRefreshRuns() async {
        let saved = ConfigStore.shared.config
        defer { ConfigStore.shared.config = saved }
        ConfigStore.shared.config.portsEnabled = true
        let service = SlowPortService(delay: 200_000_000)
        let vm = PortListViewModel(portService: service, optionKeyPressed: { false })
        vm.startAutoRefresh(interval: 1)
        let deadline = Date().addingTimeInterval(15)
        while service.calls < 3, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        vm.stopAutoRefresh()
        #expect(service.calls >= 3)
        #expect(vm.listenerCount == 1)
    }

    @Test("Stats window and menu bar use the same interval")
    func statsWindowSharesMenuBarInterval() {
        var config = QuitXConfig.default
        for seconds in QuitXConfig.menuBarRefreshChoices {
            config.menuBarRefreshSeconds = seconds
            for lowPower in [false, true] {
                #expect(StatsDetailModel.refreshInterval(config: config, lowPowerMode: lowPower)
                    == BatterySaver.menuBarInterval(refreshSeconds: seconds, lowPowerMode: lowPower))
            }
        }
        config.menuBarRefreshSeconds = 1
        #expect(StatsDetailModel.refreshInterval(config: config, lowPowerMode: false) == 1_000_000_000)
        #expect(StatsDetailModel.refreshInterval(config: config, lowPowerMode: true) == 5_000_000_000)
    }

    @Test("Menu bar sample takes the stats window's CPU and memory")
    func menuBarUsesDetailNumbers() {
        var config = QuitXConfig.default
        config.batteryMenuBarEnabled = false
        config.menuBarShowGpu = false
        let sample = StatusItemController.sampleMenuBar(config: config, cpu: 42.5, memoryUsed: 123_456)
        #expect(sample.cpu == 42.5)
        #expect(sample.memoryUsed == 123_456)
        let own = StatusItemController.sampleMenuBar(config: config)
        #expect(own.memoryUsed > 0)
    }

    @Test("Listener signature ignores order and notices any change")
    func listenerSignature() {
        let a = PortService.RawParsedLsof(pid: 10, port: 3000, process: "node", proto: "TCP", address: "127.0.0.1")
        let b = PortService.RawParsedLsof(pid: 11, port: 5173, process: "vite", proto: "TCP", address: "*")
        #expect(PortService.listenerSignature([a, b]) == PortService.listenerSignature([b, a]))
        var moved = b
        moved.pid = 12
        #expect(PortService.listenerSignature([a, b]) != PortService.listenerSignature([a, moved]))
        var udp = a
        udp.proto = "UDP"
        #expect(PortService.listenerSignature([a]) != PortService.listenerSignature([udp]))
    }
}
