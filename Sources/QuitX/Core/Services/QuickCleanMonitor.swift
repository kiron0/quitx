import Foundation

@MainActor
final class QuickCleanMonitor: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case cleaning
    }

    struct Outcome: Equatable {
        let freedBytes: Int64
        let removed: Int
        let skipped: Int

        var message: String {
            let freed = QuickCleanService.format(freedBytes)
            guard skipped > 0 else { return "Freed \(freed)" }
            return "Freed \(freed), \(skipped) in use"
        }
    }

    typealias Scanner = @Sendable () async -> [QuickCleanGroup]
    typealias Remover = @Sendable ([URL]) async -> AppUninstaller.RemovalResult

    static let shared = QuickCleanMonitor()

    @Published private(set) var groups: [QuickCleanGroup] = []
    @Published private(set) var selection: Set<QuickCleanGroup.Kind> = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastScan: Date?
    @Published var confirmationShown = false

    private let scanner: Scanner
    private let remover: Remover
    private var task: Task<Void, Never>?
    var onChange: (() -> Void)?

    init(
        scanner: @escaping Scanner = { await QuickCleanService.scan() },
        remover: @escaping Remover = { await AppUninstaller.removePermanently($0, allowAdministrator: false) }
    ) {
        self.scanner = scanner
        self.remover = remover
    }

    var reclaimableBytes: Int64? {
        guard lastScan != nil else { return nil }
        return QuickCleanService.bytes(of: groups, selected: QuickCleanService.defaultSelection(for: groups))
    }

    var selectedBytes: Int64 {
        QuickCleanService.bytes(of: groups, selected: selection)
    }

    var selectedItemCount: Int {
        groups.filter { selection.contains($0.kind) }.reduce(0) { $0 + $1.items.count }
    }

    var selectedTitles: [String] {
        groups.filter { selection.contains($0.kind) }.map(\.title)
    }

    func isStale(maxAge: TimeInterval, now: Date = Date()) -> Bool {
        guard let lastScan else { return true }
        return now.timeIntervalSince(lastScan) >= maxAge
    }

    func refreshIfStale(maxAge: TimeInterval) {
        guard phase == .idle, isStale(maxAge: maxAge) else { return }
        rescan()
    }

    func rescan() {
        guard phase != .cleaning else { return }
        task?.cancel()
        phase = .scanning
        let scanner = scanner
        task = Task { [weak self] in
            let found = await scanner()
            guard !Task.isCancelled, let self else { return }
            self.apply(found)
        }
    }

    func waitForWork() async {
        await task?.value
    }

    func apply(_ found: [QuickCleanGroup]) {
        selection = Self.carriedSelection(
            previous: selection,
            previousKinds: lastScan == nil ? nil : Set(groups.map(\.kind)),
            found: found
        )
        groups = found
        lastScan = Date()
        phase = .idle
        onChange?()
    }

    nonisolated static func carriedSelection(
        previous: Set<QuickCleanGroup.Kind>,
        previousKinds: Set<QuickCleanGroup.Kind>?,
        found: [QuickCleanGroup]
    ) -> Set<QuickCleanGroup.Kind> {
        let defaults = QuickCleanService.defaultSelection(for: found)
        guard let previousKinds else { return defaults }
        let foundKinds = Set(found.map(\.kind))
        return previous.intersection(foundKinds).union(defaults.subtracting(previousKinds))
    }

    func toggle(_ kind: QuickCleanGroup.Kind) {
        guard phase == .idle, groups.contains(where: { $0.kind == kind }) else { return }
        if selection.contains(kind) {
            selection.remove(kind)
        } else {
            selection.insert(kind)
        }
    }

    func requestClean() {
        guard phase == .idle, selectedBytes > 0 else { return }
        confirmationShown = true
    }

    func cancelClean() {
        confirmationShown = false
    }

    func clean(completion: @escaping (Outcome) -> Void) {
        confirmationShown = false
        guard phase == .idle else { return }
        let chosen = groups.filter { selection.contains($0.kind) }.flatMap(\.items)
        guard !chosen.isEmpty else { return }
        task?.cancel()
        phase = .cleaning
        let remover = remover
        let scanner = scanner
        task = Task { [weak self] in
            let result = await remover(chosen.map(\.url))
            let removedPaths = Set(result.trashed.map { $0.standardizedFileURL.path })
            let freed = chosen.filter { removedPaths.contains($0.id) }.reduce(0) { $0 + $1.bytes }
            let outcome = Outcome(freedBytes: freed, removed: removedPaths.count, skipped: result.failed.count)
            completion(outcome)
            guard let self else { return }
            self.phase = .scanning
            let found = await scanner()
            self.apply(found)
        }
    }
}
