import Foundation
import Testing
@testable import QuitX

private final class StubPortService: PortServicing, @unchecked Sendable {
    var ports: [PortInfo]
    var killResult: Bool

    init(ports: [PortInfo] = [], killResult: Bool = true) {
        self.ports = ports
        self.killResult = killResult
    }

    func fetchListeningPorts() async -> [PortInfo] { ports }
    func refreshStats(for ports: [PortInfo]) async -> [PortInfo] { ports }
    func killPort(_ port: PortInfo, mode: TerminationMode, progress: @escaping @Sendable (String) -> Void) async -> Bool {
        progress(killResult ? "Port released" : "Failed")
        return killResult
    }
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int { killResult ? ports.count : 0 }
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] { [] }
}

private final class SequencedPortService: PortServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    func fetchListeningPorts() async -> [PortInfo] {
        let call: Int = lock.withLock {
            calls += 1
            return calls
        }
        try? await Task.sleep(nanoseconds: call == 1 ? 50_000_000 : 5_000_000)
        return [PortInfo(port: call == 1 ? 3000 : 8080, pid: pid_t(100 + call), processName: "node")]
    }

    func refreshStats(for ports: [PortInfo]) async -> [PortInfo] { ports }
    func killPort(_ port: PortInfo, mode: TerminationMode, progress: @escaping @Sendable (String) -> Void) async -> Bool { true }
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int { ports.count }
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo] { [] }
}

@Suite("Ports tab view model", .serialized)
@MainActor
struct PortListViewModelTests {
    let port1 = PortInfo(port: 3000, pid: 101, processName: "node", command: "next dev", isDevServer: true)
    let port2 = PortInfo(port: 5432, pid: 102, processName: "postgres", command: "postgres -D /data")
    let port3 = PortInfo(port: 8080, pid: 103, processName: "python", command: "uvicorn main:app", isDevServer: true)

    private func withConfig(_ change: (inout QuitXConfig) -> Void, _ body: (ConfigStore) async -> Void) async {
        var config = QuitXConfig.default
        config.portsExcluded = []
        change(&config)
        await body(ConfigStore(isolated: config))
    }

    @Test("Port settings decode with defaults and sanitize ranges")
    func decoding() throws {
        let json = #"{"portsEnabled":true,"portsExcluded":[0,80,80,70000],"portsRefreshSeconds":0,"portsSortBy":"cpuDesc"}"#
        let config = try JSONDecoder().decode(QuitXConfig.self, from: Data(json.utf8))
        #expect(config.portsEnabled)
        #expect(config.portsExcluded == [80])
        #expect(config.portsRefreshSeconds == 1)
        #expect(config.portsSortBy == .cpuDesc)
        #expect(!QuitXConfig.default.portsEnabled)
        let empty = try JSONDecoder().decode(QuitXConfig.self, from: Data("{}".utf8))
        #expect(!empty.portsEnabled)
        #expect(empty.portsConfirmKill)
        #expect(empty.portsRefreshSeconds == 3)
    }

    @Test("Typed ports are validated")
    func portEntryParsing() {
        let ok = PortEntryParser.parse("3000, :5173 8000-8002 3000")
        #expect(ok.ports == [3000, 5173, 8000, 8001, 8002])
        #expect(ok.problems.isEmpty)
        let bad = PortEntryParser.parse("abc 70000 1-5000 9-3")
        #expect(bad.ports.isEmpty)
        #expect(bad.problems == [.invalid("abc"), .outOfRange("70000"), .tooLarge("1-5000"), .invalid("9-3")])
        #expect(PortEntryParser.parse("   ").ports.isEmpty)
        #expect(PortEntryParser.message(for: .outOfRange("0")).contains("1–65535"))
    }

    @Test("Last popover tab is remembered")
    func tabPersistence() {
        let suite = "QuitXTests.tab.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { TestDefaults.discard(suite) }
        #expect(PopoverTab.stored(defaults: defaults) == .apps)
        PopoverTab.ports.store(defaults: defaults)
        #expect(PopoverTab.stored(defaults: defaults) == .ports)
        defaults.set("bogus", forKey: PopoverTab.defaultsKey)
        #expect(PopoverTab.stored(defaults: defaults) == .apps)
    }

    @Test("Search, exclusions and selection")
    func filteringAndSelection() async {
        await withConfig({ $0.portsEnabled = true; $0.portsExcluded = [] }) { store in
            let vm = PortListViewModel(portService: StubPortService(), configStore: store, optionKeyPressed: { false })
            vm.ports = [port1, port2, port3]
            #expect(vm.filteredPorts.count == 3)
            vm.searchQuery = "PYTHON"
            #expect(vm.filteredPorts.map(\.port) == [8080])
            vm.searchQuery = "54"
            #expect(vm.filteredPorts.map(\.port) == [5432])
            vm.searchQuery = ""
            vm.toggleSelectAll()
            #expect(vm.isAllSelected)
            #expect(vm.selectedVisibleCount == 3)
            vm.toggleSelectAll()
            #expect(vm.selectedPorts.isEmpty)
            store.config.portsExcluded = [5432]
            #expect(vm.filteredPorts.map(\.port) == [3000, 8080])
            #expect(vm.listenerCount == 2)
        }
    }

    @Test("Kill asks first when confirmation is on, force title when forced")
    func confirmation() async {
        await withConfig({ $0.portsEnabled = true; $0.portsConfirmKill = true; $0.portsForceKill = false }) { store in
            let vm = PortListViewModel(portService: StubPortService(), configStore: store, optionKeyPressed: { false })
            vm.ports = [port1, port2]
            vm.confirmAndKillPort(port1)
            #expect(vm.pendingKillConfirmation?.title.contains("3000") == true)
            #expect(vm.pendingKillConfirmation?.confirmButtonTitle == "Kill")
            vm.pendingKillConfirmation = nil
            vm.confirmAndKillPort(port1, force: true)
            #expect(vm.pendingKillConfirmation?.isForced == true)
            #expect(vm.pendingKillConfirmation?.confirmButtonTitle == "Force Kill")
            vm.pendingKillConfirmation = nil
            vm.selectedPorts = [port1.id, port2.id]
            vm.confirmAndKillSelectedPorts()
            #expect(vm.pendingKillConfirmation?.title == "Kill 2 Ports?")
            #expect(vm.pendingKillConfirmation?.message.contains(":3000") == true)
            vm.pendingKillConfirmation = nil
            store.config.portsExcluded = [5432]
            vm.confirmAndForceKillAll()
            #expect(vm.pendingKillConfirmation?.title == "Force Kill All 1 Ports?")
            #expect(vm.pendingKillConfirmation?.message.contains(":5432") == false)
            vm.pendingKillConfirmation = nil
            store.config.portsConfirmKill = false
            vm.confirmAndKillPort(port1)
            #expect(vm.pendingKillConfirmation == nil)
        }
    }

    @Test("Sort modes apply")
    func sorting() async {
        await withConfig({ $0.portsSortBy = .portDesc }) { store in
            let vm = PortListViewModel(portService: StubPortService(), configStore: store, optionKeyPressed: { false })
            #expect(vm.sort(ports: [port1, port2, port3]).map(\.port) == [8080, 5432, 3000])
            store.config.portsSortBy = .name
            #expect(vm.sort(ports: [port1, port2, port3]).map(\.processName) == ["node", "postgres", "python"])
        }
    }

    @Test("Refresh does nothing while ports are disabled")
    func disabled() async {
        await withConfig({ $0.portsEnabled = false }) { store in
            let vm = PortListViewModel(portService: StubPortService(ports: [port1]), configStore: store, optionKeyPressed: { false })
            await vm.refresh()
            #expect(vm.ports.isEmpty)
            #expect(!vm.hasLoadedOnce)
        }
    }

    @Test("Overlapping refresh keeps the newest result")
    func overlappingRefresh() async {
        await withConfig({ $0.portsEnabled = true; $0.portsExcluded = [] }) { store in
            let vm = PortListViewModel(portService: SequencedPortService(), configStore: store, optionKeyPressed: { false })
            let first = Task { await vm.refresh() }
            try? await Task.sleep(nanoseconds: 1_000_000)
            let second = Task { await vm.refresh() }
            await first.value
            await second.value
            #expect(vm.ports.map(\.port) == [8080])
            #expect(!vm.isLoading)
            #expect(vm.hasLoadedOnce)
        }
    }
}
