import AppKit
import SwiftUI

protocol PortServicing {
    func fetchListeningPorts() async -> [PortInfo]
    func fetchListeningPorts(metadataMaxAge: TimeInterval) async -> [PortInfo]
    func refreshStats(for ports: [PortInfo]) async -> [PortInfo]
    func killPort(
        _ port: PortInfo,
        mode: TerminationMode,
        progress: @escaping @Sendable (String) -> Void
    ) async -> Bool
    func killMultiplePorts(_ ports: [PortInfo], force: Bool) async -> Int
    func traceProcessTree(pid: pid_t) async -> [ProcessTreeNodeInfo]
}

extension PortServicing {
    func fetchListeningPorts(metadataMaxAge: TimeInterval) async -> [PortInfo] {
        await fetchListeningPorts()
    }
}

extension PortService: PortServicing {}

struct KillConfirmationRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmButtonTitle: String
    let isForced: Bool
    let action: () async -> Void
}

@MainActor
final class PortListViewModel: ObservableObject {
    static let shared = PortListViewModel()

    @Published var ports: [PortInfo] = [] {
        didSet { portsVersion &+= 1 }
    }
    @Published var selectedPorts: Set<String> = []
    @Published var searchQuery: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published var hasLoadedOnce = false
    @Published var pendingKillConfirmation: KillConfirmationRequest? {
        didSet { StatusItemController.shared?.scheduleUpdatePopoverSize() }
    }
    @Published var pendingPortIds: Set<String> = []
    @Published var isBatchKilling: Bool = false
    @Published var terminationStages: [String: String] = [:]
    @Published private(set) var currentQuote: String = "Find and kill the process using a port ⚡"

    private let quotes = [
        "Find and kill the process using a port ⚡",
        "Free up port 3000 in one click 🤘",
        "Free up occupied ports 🧹",
        "Kill the port and everything behind it 🎯",
        "Clean ports, clear mind 🚀",
        "Docker containers stop cleanly 🐳"
    ]

    private var hasInitializedSelection = false
    private var fetchGeneration = 0
    private var statsGeneration = 0
    private var activeRefreshes = 0
    private var portsVersion = 0
    private var filterCache: (version: Int, query: String, excluded: [Int], result: [PortInfo])?
    private let portService: PortServicing
    private let configStore: ConfigStore
    private var autoRefreshTask: Task<Void, Never>?
    private var autoRefreshInterval: Int = 0
    private var autoRefreshGeneration = 0
    private let optionKeyPressed: @MainActor () -> Bool

    init(
        portService: PortServicing = PortService.shared,
        configStore: ConfigStore? = nil,
        optionKeyPressed: (@MainActor () -> Bool)? = nil
    ) {
        self.portService = portService
        self.configStore = configStore ?? ConfigStore.shared
        self.optionKeyPressed = optionKeyPressed ?? { AppListViewModel.shared.isOptionKeyPressed }
        randomizeQuote()
    }

    func randomizeQuote() {
        currentQuote = quotes.randomElement() ?? currentQuote
    }

    var isEnabled: Bool { configStore.config.portsEnabled }

    var isOptionKeyPressed: Bool { optionKeyPressed() }

    var isForceMode: Bool { isOptionKeyPressed || configStore.config.portsForceKill }

    var filteredPorts: [PortInfo] {
        let excludedList = configStore.config.portsExcluded
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if let cache = filterCache,
           cache.version == portsVersion,
           cache.query == q,
           cache.excluded == excludedList {
            return cache.result
        }
        let excluded = Set(excludedList)
        let result = ports.filter { port in
            if port.isSystemProtected || excluded.contains(port.port) { return false }
            guard !q.isEmpty else { return true }
            return "\(port.port)".contains(q) ||
                port.displayAppName.lowercased().contains(q) ||
                port.processName.lowercased().contains(q) ||
                port.command.lowercased().contains(q) ||
                (port.docker?.name.lowercased().contains(q) == true) ||
                (port.cwd?.lowercased().contains(q) == true)
        }
        filterCache = (portsVersion, q, excludedList, result)
        return result
    }

    var listenerCount: Int {
        let excluded = Set(configStore.config.portsExcluded)
        return ports.reduce(0) { count, port in
            (port.isSystemProtected || excluded.contains(port.port)) ? count : count + 1
        }
    }

    static func groupKey(for port: PortInfo, mode: ListenerGrouping) -> String {
        switch mode {
        case .none: return ""
        case .project: return port.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Other"
        case .docker: return port.docker?.name ?? "Local processes"
        case .process: return port.processGroup ?? port.displayAppName
        }
    }

    var groupedPorts: [(String, [PortInfo])] {
        let mode = configStore.config.portsGrouping
        let visible = filteredPorts
        guard mode != .none else { return [("", visible)] }
        let groups = Dictionary(grouping: visible) { Self.groupKey(for: $0, mode: mode) }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    var visibleGroupCount: Int {
        let mode = configStore.config.portsGrouping
        guard mode != .none else { return 0 }
        return Set(filteredPorts.map { Self.groupKey(for: $0, mode: mode) }).count
    }

    var visibleCount: Int { filteredPorts.count }

    var selectedVisibleCount: Int {
        selectedPorts.intersection(Set(filteredPorts.map(\.id))).count
    }

    private var killablePorts: [PortInfo] {
        let excluded = Set(configStore.config.portsExcluded)
        return ports.filter { !$0.isSystemProtected && !excluded.contains($0.port) }
    }

    var isAllSelected: Bool {
        let visible = filteredPorts
        return !visible.isEmpty && visible.allSatisfy { selectedPorts.contains($0.id) }
    }

    var isPartiallySelected: Bool {
        let visibleIds = Set(filteredPorts.map(\.id))
        let intersection = selectedPorts.intersection(visibleIds)
        return !intersection.isEmpty && intersection.count < visibleIds.count
    }

    var isEverythingSelected: Bool {
        let all = Set(killablePorts.map(\.id))
        return !all.isEmpty && all.isSubset(of: selectedPorts)
    }

    func toggleSelectAll() {
        let visibleIds = Set(filteredPorts.filter { !$0.isSystemProtected }.map(\.id))
        if visibleIds.isSubset(of: selectedPorts) {
            selectedPorts.subtract(visibleIds)
        } else {
            selectedPorts.formUnion(visibleIds)
        }
    }

    func toggleSelection(for port: PortInfo) {
        guard !port.isSystemProtected else { return }
        if selectedPorts.contains(port.id) {
            selectedPorts.remove(port.id)
        } else {
            selectedPorts.insert(port.id)
        }
    }

    func excludePort(_ portNumber: Int) {
        guard !configStore.config.portsExcluded.contains(portNumber) else { return }
        configStore.config.portsExcluded = QuitXConfig.validPorts(configStore.config.portsExcluded + [portNumber])
        configStore.save()
        showToastMessage("Port :\(portNumber) added to exclude list")
        StatusItemController.shared?.scheduleUpdatePopoverSize()
    }

    var isAutoRefreshing: Bool { autoRefreshTask != nil }

    func startAutoRefresh(interval seconds: Int? = nil) {
        let interval = max(1, seconds ?? configStore.config.portsRefreshSeconds)
        guard isEnabled else {
            stopAutoRefresh()
            return
        }
        if autoRefreshTask != nil, autoRefreshInterval == interval { return }
        autoRefreshTask?.cancel()
        autoRefreshGeneration += 1
        let generation = autoRefreshGeneration
        autoRefreshInterval = interval
        autoRefreshTask = Task { [weak self] in
            defer {
                if let self, self.autoRefreshGeneration == generation {
                    self.autoRefreshTask = nil
                    self.autoRefreshInterval = 0
                }
            }
            while !Task.isCancelled {
                guard let self, self.isEnabled, self.autoRefreshGeneration == generation else { return }
                let started = DispatchTime.now().uptimeNanoseconds
                await self.refresh()
                let spent = DispatchTime.now().uptimeNanoseconds &- started
                do {
                    try await Task.sleep(nanoseconds: Self.nextRefreshDelay(intervalSeconds: interval, spentNanoseconds: spent))
                } catch {
                    return
                }
            }
        }
    }

    nonisolated static func nextRefreshDelay(intervalSeconds: Int, spentNanoseconds: UInt64) -> UInt64 {
        let period = UInt64(max(1, intervalSeconds)) * 1_000_000_000
        return max(100_000_000, period > spentNanoseconds ? period - spentNanoseconds : 0)
    }

    func stopAutoRefresh() {
        autoRefreshGeneration += 1
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        autoRefreshInterval = 0
    }

    func clearWhenDisabled() {
        stopAutoRefresh()
        PortDetailsWindowController.shared.close()
        ProcessTraceWindowController.shared.close()
        ExcludePortPickerWindowController.shared.close()
        ports = []
        selectedPorts = []
        pendingKillConfirmation = nil
        hasInitializedSelection = false
        hasLoadedOnce = false
        StatusItemController.shared?.updateMenuBarPortCount(nil)
    }

    func refresh() async {
        guard isEnabled else { return }
        activeRefreshes += 1
        if !hasLoadedOnce { isLoading = true }
        fetchGeneration += 1
        let gen = fetchGeneration
        let selectedAllBeforeRefresh = isAllSelected
        defer {
            activeRefreshes -= 1
            if activeRefreshes == 0 { isLoading = false }
        }

        let isVisible = StatusItemController.shared.map { $0.isShown && $0.isPortsTabActive } ?? true
        let fetchedPorts = isVisible
            ? await portService.fetchListeningPorts()
            : await portService.fetchListeningPorts(metadataMaxAge: PortService.backgroundMetadataReuseSeconds)
        guard gen == fetchGeneration, isEnabled else { return }
        statsGeneration += 1
        let previousPorts = ports
        let sortedPorts = sort(ports: fetchedPorts)
        if sortedPorts != ports { ports = sortedPorts }
        if hasLoadedOnce {
            ListenerHistoryStore.shared.recordChanges(previous: previousPorts, current: sortedPorts)
        }

        var nextSelection = selectedPorts.intersection(Set(ports.map(\.id)))
        let selectAll = configStore.config.portsSelectAllByDefault
        if !hasInitializedSelection {
            nextSelection = selectAll ? Set(filteredPorts.map(\.id)) : []
            hasInitializedSelection = true
        } else if selectedAllBeforeRefresh && selectAll {
            nextSelection = Set(filteredPorts.map(\.id))
        }
        if nextSelection != selectedPorts { selectedPorts = nextSelection }

        let firstLoad = !hasLoadedOnce
        hasLoadedOnce = true
        StatusItemController.shared?.updateMenuBarPortCount(listenerCount)
        if firstLoad || sortedPorts.count != previousPorts.count {
            StatusItemController.shared?.scheduleUpdatePopoverSize()
        }
    }

    func resort() {
        let sortedPorts = sort(ports: ports)
        if sortedPorts != ports { ports = sortedPorts }
    }

    func confirmAndKillPort(_ port: PortInfo, force: Bool = false) {
        confirmAndKillPort(port, mode: force ? .force : .terminate)
    }

    func confirmAndInterruptPort(_ port: PortInfo) {
        confirmAndKillPort(port, mode: .interrupt)
    }

    private func confirmAndKillPort(_ port: PortInfo, mode: TerminationMode) {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }
        let effectiveMode: TerminationMode = isForceMode ? .force : mode
        let isForced = effectiveMode == .force
        guard configStore.config.portsConfirmKill else {
            Task { await killPort(port, mode: effectiveMode) }
            return
        }
        let title: String
        if isForced {
            title = "Force Kill Port :\(port.port)?"
        } else if effectiveMode == .interrupt {
            title = "Interrupt Port :\(port.port)?"
        } else {
            title = "Kill Port :\(port.port)?"
        }
        var msg = "\(port.processName) (PID \(port.pid))"
        if let cwd = port.cwd, !cwd.isEmpty {
            msg += " in \((cwd as NSString).lastPathComponent)"
        }
        pendingKillConfirmation = KillConfirmationRequest(
            title: title,
            message: msg,
            confirmButtonTitle: isForced ? "Force Kill" : (effectiveMode == .interrupt ? "Interrupt" : "Kill"),
            isForced: isForced,
            action: { [weak self] in
                await self?.killPort(port, mode: effectiveMode)
            }
        )
    }

    func confirmAndKillSelectedPorts(force: Bool = false) {
        let targets = killablePorts.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }
        let isForced = force || isForceMode
        guard configStore.config.portsConfirmKill else {
            Task { await killSelectedPorts(force: isForced) }
            return
        }
        let count = targets.count
        let noun = count == 1 ? "Port" : "Ports"
        let portList = targets.prefix(5).map { ":\($0.port)" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""
        pendingKillConfirmation = KillConfirmationRequest(
            title: isForced ? "Force Kill \(count) \(noun)?" : "Kill \(count) \(noun)?",
            message: "\(portList)\(remainder)",
            confirmButtonTitle: isForced ? "Force Kill" : "Kill",
            isForced: isForced,
            action: { [weak self] in
                await self?.killSelectedPorts(force: isForced)
            }
        )
    }

    func confirmAndForceKillAll() {
        let targets = killablePorts
        guard !targets.isEmpty else { return }
        guard configStore.config.portsConfirmKill else {
            Task { await forceKillAll() }
            return
        }
        let count = targets.count
        let portList = targets.prefix(5).map { ":\($0.port)" }.joined(separator: ", ")
        let remainder = targets.count > 5 ? " and \(targets.count - 5) more" : ""
        pendingKillConfirmation = KillConfirmationRequest(
            title: "Force Kill All \(count) Ports?",
            message: "\(portList)\(remainder)",
            confirmButtonTitle: "Force Kill All",
            isForced: true,
            action: { [weak self] in
                await self?.forceKillAll()
            }
        )
    }

    func confirmPending() {
        guard let request = pendingKillConfirmation else { return }
        pendingKillConfirmation = nil
        Task { await request.action() }
    }

    func killPort(_ port: PortInfo, force: Bool = false) async {
        await killPort(port, mode: force ? .force : .terminate)
    }

    func killPort(_ port: PortInfo, mode: TerminationMode) async {
        guard !port.isSystemProtected else {
            showToastMessage("Port is protected by system", isError: true)
            return
        }
        guard !pendingPortIds.contains(port.id) else { return }
        pendingPortIds.insert(port.id)
        terminationStages[port.id] = "Sending \(mode.signalName)"
        ListenerHistoryStore.shared.record(port: port, event: "signal", detail: mode.signalName)
        defer {
            pendingPortIds.remove(port.id)
            terminationStages.removeValue(forKey: port.id)
        }
        let ok = await portService.killPort(port, mode: mode) { [weak self] stage in
            Task { @MainActor [weak self] in
                guard let self, self.pendingPortIds.contains(port.id) else { return }
                self.terminationStages[port.id] = stage
            }
        }
        if ok {
            ListenerHistoryStore.shared.record(port: port, event: "released", detail: mode.signalName)
            SoundService.playQuitSingle()
            showToastMessage("Killed :\(port.port) (\(port.processName))")
        } else {
            ListenerHistoryStore.shared.record(port: port, event: "failed", detail: mode.signalName)
            showToastMessage("Couldn't free :\(port.port), it kept re-opening", isError: true)
        }
        await refresh()
    }

    func killSelectedPorts(force: Bool = false) async {
        guard !isBatchKilling else { return }
        let targets = killablePorts.filter { selectedPorts.contains($0.id) }
        guard !targets.isEmpty else { return }
        await killBatch(targets, force: force, verb: force ? "Force killed" : "Killed")
    }

    func forceKillAll() async {
        guard !isBatchKilling else { return }
        let targets = killablePorts
        guard !targets.isEmpty else { return }
        await killBatch(targets, force: true, verb: "Force killed")
    }

    private func killBatch(_ targets: [PortInfo], force: Bool, verb: String) async {
        isBatchKilling = true
        pendingPortIds.formUnion(targets.map(\.id))
        defer {
            isBatchKilling = false
            pendingPortIds.subtract(targets.map(\.id))
        }
        let count = await portService.killMultiplePorts(targets, force: force)
        if count > 0 {
            SoundService.playQuitAll()
            showToastMessage("\(verb) \(count) \(count == 1 ? "port" : "ports")")
        } else {
            showToastMessage("No ports freed, listeners kept re-opening", isError: true)
        }
        await refresh()
    }

    func showToastMessage(_ msg: String, isError: Bool = false) {
        AppListViewModel.shared.showToastMessage(msg, isError: isError)
    }

    func sort(ports: [PortInfo]) -> [PortInfo] {
        let byPortThenPid: (PortInfo, PortInfo) -> Bool = {
            $0.port != $1.port ? $0.port < $1.port : $0.pid < $1.pid
        }
        switch configStore.config.portsSortBy {
        case .portAsc:
            return ports.sorted(by: byPortThenPid)
        case .portDesc:
            return ports.sorted { $0.port != $1.port ? $0.port > $1.port : $0.pid < $1.pid }
        case .name:
            return ports.sorted {
                let order = $0.processName.localizedCaseInsensitiveCompare($1.processName)
                return order != .orderedSame ? order == .orderedAscending : byPortThenPid($0, $1)
            }
        case .memoryDesc:
            return ports.sorted { $0.memoryBytes != $1.memoryBytes ? $0.memoryBytes > $1.memoryBytes : byPortThenPid($0, $1) }
        case .cpuDesc:
            return ports.sorted { $0.cpuUsage != $1.cpuUsage ? $0.cpuUsage > $1.cpuUsage : byPortThenPid($0, $1) }
        }
    }
}
