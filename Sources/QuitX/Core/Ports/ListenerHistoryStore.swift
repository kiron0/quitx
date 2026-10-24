import Foundation

struct ListenerHistoryEntry: Codable, Equatable {
    let date: Date
    let port: Int
    let pid: pid_t
    let event: String
    let detail: String
}

@MainActor
final class ListenerHistoryStore: ObservableObject {
    static let shared = ListenerHistoryStore()
    @Published private(set) var entries: [ListenerHistoryEntry] = []
    private let limit = 200
    private let defaultsKey = "QuitXPortListenerHistory"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ListenerHistoryEntry].self, from: data) else { return }
        entries = Array(decoded.prefix(limit))
    }

    func record(port: PortInfo, event: String, detail: String) {
        commit([Self.makeEntry(port: port, event: event, detail: detail)])
    }

    func recordChanges(previous: [PortInfo], current: [PortInfo]) {
        let oldIds = Set(previous.map(\.id))
        let newIds = Set(current.map(\.id))
        var batch: [ListenerHistoryEntry] = []
        for port in current where !oldIds.contains(port.id) {
            batch.append(Self.makeEntry(port: port, event: "opened", detail: port.command))
        }
        for port in previous where !newIds.contains(port.id) {
            batch.append(Self.makeEntry(port: port, event: "closed", detail: port.command))
        }
        commit(batch)
    }

    private static func makeEntry(port: PortInfo, event: String, detail: String) -> ListenerHistoryEntry {
        ListenerHistoryEntry(date: Date(), port: port.port, pid: port.pid, event: event, detail: redact(detail))
    }

    private func commit(_ newEntries: [ListenerHistoryEntry]) {
        guard !newEntries.isEmpty else { return }
        var updated = Array(newEntries.reversed()) + entries
        if updated.count > limit { updated.removeLast(updated.count - limit) }
        entries = updated
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    nonisolated private static let redactRules: [(regex: NSRegularExpression, template: String)] = {
        let rules: [(String, String)] = [
            (#"(?i)(token|password|passwd|secret|api[_-]?key)=([^\s]+)"#, "$1=<redacted>"),
            (#"(?i)(--?(?:token|password|passwd|secret|api[_-]?key)\s+)([^\s-][^\s]*)"#, "$1<redacted>"),
            (#"(?i)(authorization:\s*bearer\s+)([^\s]+)"#, "$1<redacted>")
        ]
        return rules.compactMap { rule in
            (try? NSRegularExpression(pattern: rule.0)).map { (regex: $0, template: rule.1) }
        }
    }()

    func diagnostics(ports: [PortInfo], metrics: PortScanMetrics) -> String {
        var lines = [
            "QuitX port diagnostics",
            "Generated: \(Date().formatted(.iso8601))",
            "Ports: \(ports.count)",
            String(format: "Scan: %.3fs total, %.3fs discovery, %.3fs metadata", metrics.total, metrics.discovery, metrics.metadata)
        ]
        lines += ports.map {
            ":\($0.port) \($0.protocolName) \($0.bindAddress) pid=\($0.pid) app=\($0.displayAppName) command=\(Self.redact($0.command))"
        }
        lines.append("History:")
        lines += entries.prefix(50).map { "\($0.date) :\($0.port) pid=\($0.pid) \($0.event) \($0.detail)" }
        return lines.joined(separator: "\n")
    }

    nonisolated static func redact(_ text: String) -> String {
        redactRules.reduce(text) { value, rule in
            let range = NSRange(value.startIndex..., in: value)
            return rule.regex.stringByReplacingMatches(in: value, range: range, withTemplate: rule.template)
        }
    }
}
