import AppKit
import SwiftUI

enum PortEntryParser {
    enum Problem: Equatable {
        case invalid(String)
        case outOfRange(String)
        case tooLarge(String)
    }

    struct Result: Equatable {
        var ports: [Int] = []
        var problems: [Problem] = []
    }

    static let maxRange = 1000

    static func parse(_ text: String) -> Result {
        var result = Result()
        var seen = Set<Int>()
        let tokens = text
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")) }
            .filter { !$0.isEmpty }
        for token in tokens {
            let bounds = token.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
            if bounds.count == 1 {
                guard let port = Int(bounds[0]) else {
                    result.problems.append(.invalid(token))
                    continue
                }
                guard (1...65535).contains(port) else {
                    result.problems.append(.outOfRange(token))
                    continue
                }
                if seen.insert(port).inserted { result.ports.append(port) }
            } else if bounds.count == 2, let low = Int(bounds[0]), let high = Int(bounds[1]), low <= high {
                guard (1...65535).contains(low), (1...65535).contains(high) else {
                    result.problems.append(.outOfRange(token))
                    continue
                }
                guard high - low < maxRange else {
                    result.problems.append(.tooLarge(token))
                    continue
                }
                for port in low...high where seen.insert(port).inserted {
                    result.ports.append(port)
                }
            } else {
                result.problems.append(.invalid(token))
            }
        }
        return result
    }

    static func message(for problem: Problem) -> String {
        switch problem {
        case let .invalid(token): return "\u{201C}\(token)\u{201D} isn't a port number."
        case let .outOfRange(token): return "\(token) is outside 1–65535."
        case let .tooLarge(token): return "\(token) covers more than \(maxRange) ports."
        }
    }
}

@MainActor
final class ExcludePortPickerViewModel: ObservableObject {
    @Published private(set) var listeners: [PortInfo] = []
    @Published private(set) var isLoading = true
    @Published var selectedPorts: Set<Int> = []
    @Published var searchQuery = ""
    @Published var manualEntry = ""

    func load() async {
        isLoading = true
        let fetched = await PortService.shared.fetchListeningPorts()
        var seen = Set<Int>()
        listeners = fetched
            .filter { !$0.isSystemProtected }
            .sorted { $0.port < $1.port }
            .filter { seen.insert($0.port).inserted }
        isLoading = false
    }

    func visible(excluded: [Int]) -> [PortInfo] {
        let excludedSet = Set(excluded)
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return listeners.filter { port in
            guard !excludedSet.contains(port.port) else { return false }
            guard !query.isEmpty else { return true }
            return "\(port.port)".contains(query)
                || port.displayAppName.lowercased().contains(query)
                || port.processName.lowercased().contains(query)
        }
    }

    var manualResult: PortEntryParser.Result { PortEntryParser.parse(manualEntry) }

    func toggle(_ port: Int) {
        if selectedPorts.contains(port) {
            selectedPorts.remove(port)
        } else {
            selectedPorts.insert(port)
        }
    }

    func toggleAll(_ ports: [PortInfo]) {
        let ids = Set(ports.map(\.port))
        if ids.isSubset(of: selectedPorts) {
            selectedPorts.subtract(ids)
        } else {
            selectedPorts.formUnion(ids)
        }
    }
}

@MainActor
final class ExcludePortPickerWindowController: NSObject, NSWindowDelegate {
    static let shared = ExcludePortPickerWindowController()
    private var window: NSWindow?

    var isOpen: Bool { window != nil }

    func show() {
        if let window {
            WindowAnimator.activateExisting(window)
            return
        }
        let view = ExcludePortPickerView { [weak self] in self?.close() }
            .environmentObject(ConfigStore.shared)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 500, height: 540))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.animationBehavior = .none
        window.delegate = self

        let targetFrame: NSRect
        if let screen = WindowPositioner.targetScreen {
            targetFrame = WindowPositioner.topBiasedFrame(for: window.frame.size, on: screen)
        } else {
            window.center()
            targetFrame = window.frame
        }
        self.window = window
        WindowActivationCoordinator.update()
        WindowAnimator.present(window, targetFrame: targetFrame)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        WindowActivationCoordinator.update()
    }
}

private final class PortPickerRowState: ObservableObject {
    @Published var isHovered = false
}

private struct PortPickerRow: View {
    let port: PortInfo
    let isSelected: Bool
    @StateObject private var state = PortPickerRowState()

    var body: some View {
        HStack(spacing: 8) {
            QuitXSelectionCheckbox(isSelected: isSelected)
            AppIconView(bundleId: port.appBundleId, pid: port.pid, size: 18, cornerRadius: 3.5)
            Text(verbatim: ":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.8)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.primary.opacity(0.08)))
            Text(port.displayAppName)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(port.protocolName)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}

struct ExcludePortPickerView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var viewModel = ExcludePortPickerViewModel()
    let onClose: () -> Void

    var body: some View {
        let manual = viewModel.manualResult
        let excluded = configStore.config.portsExcluded
        let newManual = manual.ports.filter { !excluded.contains($0) }
        VStack(spacing: 0) {
            Text("Add Ports to Exclude List")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(QuitXTheme.paneBackground)

            VStack(alignment: .leading, spacing: 6) {
                Text("Type ports")
                    .font(.system(size: 11.5, weight: .medium))
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .foregroundStyle(Color.secondary)
                    TextField("3000, 5173 or 8000-8010", text: $viewModel.manualEntry)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .disableInitialFocus()
                        .onSubmit { addManual(newManual, problems: manual.problems) }
                    if !viewModel.manualEntry.isEmpty {
                        Button {
                            viewModel.manualEntry = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(SearchFieldGlassBackground(isFocused: !viewModel.manualEntry.isEmpty, cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(manual.problems.isEmpty ? Color.clear : Color.red.opacity(0.7), lineWidth: 1)
                )

                Group {
                    if let problem = manual.problems.first {
                        Label(PortEntryParser.message(for: problem), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red)
                    } else if !manual.ports.isEmpty && newManual.isEmpty {
                        Label("Already excluded.", systemImage: "checkmark.circle")
                            .foregroundStyle(Color.secondary)
                    } else if !newManual.isEmpty {
                        Label("\(newManual.count) \(newManual.count == 1 ? "port" : "ports") will be added.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    } else {
                        Text("Separate ports with commas or spaces. Ranges like 8000-8010 work too.")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.system(size: 11))
                .frame(height: 14, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.secondary)
                TextField("Search listening ports", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .disableInitialFocus()
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(SearchFieldGlassBackground(isFocused: !viewModel.searchQuery.isEmpty, cornerRadius: 6))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Scanning listening ports…")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                    }
                } else {
                    let ports = viewModel.visible(excluded: excluded)
                    if ports.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.searchQuery.isEmpty ? "network" : "magnifyingglass")
                                .font(.system(size: 26))
                                .foregroundStyle(QuitXTheme.accent)
                            Text(viewModel.searchQuery.isEmpty ? "No other ports are listening" : "No matching ports")
                                .font(.system(size: 13, weight: .medium))
                            Text("Type port numbers above to exclude them anyway.")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.secondary)
                        }
                    } else {
                        listView(ports)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
            .padding(.horizontal, 16)

            HStack {
                let total = Set(viewModel.selectedPorts).union(newManual).count
                Text("\(total) selected")
                    .foregroundStyle(Color.secondary)
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button(total == 1 ? "Add Port" : "Add Ports") {
                    let ports = Array(viewModel.selectedPorts) + newManual
                    configStore.config.portsExcluded = QuitXConfig.validPorts(excluded + ports)
                    configStore.save()
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(total == 0 || !manual.problems.isEmpty)
            }
            .font(.system(size: 11.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
        .background {
            if LiquidGlass.enabled {
                LiquidGlassFill(shape: Rectangle())
                    .ignoresSafeArea()
            } else {
                QuitXTheme.windowBackground
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .task { await viewModel.load() }
    }

    private func listView(_ ports: [PortInfo]) -> some View {
        let all = !ports.isEmpty && ports.allSatisfy { viewModel.selectedPorts.contains($0.port) }
        let some = ports.contains { viewModel.selectedPorts.contains($0.port) }
        return VStack(spacing: 0) {
            Button {
                viewModel.toggleAll(ports)
            } label: {
                HStack(spacing: 8) {
                    QuitXSelectionCheckbox(isSelected: all, isPartial: some && !all)
                    Text(all ? "Deselect All" : "Select All")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Text("\(ports.count) listening")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 27)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 2) {
                    ForEach(ports) { port in
                        Button {
                            viewModel.toggle(port.port)
                        } label: {
                            PortPickerRow(port: port, isSelected: viewModel.selectedPorts.contains(port.port))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
    }

    private func addManual(_ ports: [Int], problems: [PortEntryParser.Problem]) {
        guard problems.isEmpty, !ports.isEmpty else { return }
        configStore.config.portsExcluded = QuitXConfig.validPorts(configStore.config.portsExcluded + ports)
        configStore.save()
        viewModel.manualEntry = ""
    }
}
