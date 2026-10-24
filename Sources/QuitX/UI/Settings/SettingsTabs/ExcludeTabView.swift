import SwiftUI
import AppKit

enum ExcludeSection: String, CaseIterable {
    case apps
    case ports

    static let defaultsKey = "QuitXExcludeTab"

    static func stored(defaults: UserDefaults = .standard) -> ExcludeSection {
        defaults.string(forKey: defaultsKey).flatMap(ExcludeSection.init(rawValue:)) ?? .apps
    }
}

struct PortRemovalRequest: Equatable {
    let ports: [Int]
    let removesAll: Bool

    var title: String {
        if removesAll { return "Remove all excluded ports?" }
        if ports.count == 1 { return "Remove port :\(ports[0])?" }
        return "Remove \(ports.count) excluded ports?"
    }

    var message: String {
        if removesAll { return "Every port will show in the Ports tab again and can be killed." }
        if ports.count == 1 { return ":\(ports[0]) will show in the Ports tab again and can be killed." }
        return "These ports will show in the Ports tab again and can be killed."
    }
}

struct ExcludeTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = ExcludeTabState()
    @ObservedObject private var portsModel = PortListViewModel.shared

    static let contentHeight: CGFloat = 336

    private var section: ExcludeSection {
        configStore.config.portsEnabled ? state.section : .apps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if configStore.config.portsEnabled {
                QuitXSegmentedControl(
                    segments: [
                        QuitXSegment(value: ExcludeSection.apps, title: "Apps", symbol: "square.grid.2x2"),
                        QuitXSegment(value: ExcludeSection.ports, title: "Ports", symbol: "network")
                    ],
                    selection: Binding(get: { state.section }, set: { state.select($0) })
                )
                .frame(maxWidth: .infinity)
            }

            HStack(alignment: .center) {
                Text(section == .apps
                     ? "Apps on this list stay out of manual and automatic Quit actions."
                     : "Ports on this list never show in the Ports tab and are never killed.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)

                Spacer()

                HelpPopoverButton(text: section == .apps
                    ? "VIP velvet rope immunity! Apps on this list get total immunity from all manual quits, hotkeys, and automated sweeps. 🎟️🛡️"
                    : "Keep your database, proxy or anything else safe from Kill. Add ports from the ones listening now, or type numbers and ranges like 8000-8010. 🔌🛡️")
            }

            Group {
                if section == .apps {
                    appsList
                } else {
                    portsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )

            if section == .apps {
                appsFooter
            } else {
                portsFooter
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: SettingsTab.contentWidth, height: Self.contentHeight, alignment: .topLeading)
        .background(QuitXTheme.paneBackground)
        .overlay {
            if let request = state.pendingRemoval {
                QuitConfirmationOverlay(
                    title: request.title,
                    subtitle: request.message,
                    confirmTitle: request.removesAll ? "Remove All" : "Remove",
                    systemImage: "trash.fill",
                    isForced: true,
                    cardWidth: 260,
                    onConfirm: {
                        configStore.removeExcludedApps(Set(request.identifiers))
                        state.selectedIdentifiers.removeAll()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingRemoval = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingRemoval = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let request = state.pendingPortRemoval {
                QuitConfirmationOverlay(
                    title: request.title,
                    subtitle: request.message,
                    confirmTitle: request.removesAll ? "Remove All" : "Remove",
                    systemImage: "trash.fill",
                    isForced: true,
                    cardWidth: 260,
                    onConfirm: {
                        let removed = Set(request.ports)
                        configStore.config.portsExcluded = configStore.config.portsExcluded.filter { !removed.contains($0) }
                        configStore.save()
                        state.selectedPorts.subtract(removed)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingPortRemoval = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.pendingPortRemoval = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.pendingRemoval != nil || state.pendingPortRemoval != nil)
        .onChange(of: configStore.config.portsExcluded) { _, ports in
            state.selectedPorts.formIntersection(Set(ports))
        }
    }

    @ViewBuilder
    private var appsList: some View {
        if configStore.config.exclude.isEmpty {
            emptyState(symbol: "nosign", title: "No excluded apps", detail: "Use an app's ••• menu in the QuitX popover, or Add Apps below.")
        } else {
            VStack(spacing: 0) {
                selectAllHeader(
                    isAll: state.allSelected(configStore.config.exclude),
                    isPartial: state.partiallySelected(configStore.config.exclude),
                    count: "\(configStore.config.exclude.count) excluded",
                    toggle: { state.toggleAll(configStore.config.exclude) }
                )

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(configStore.config.exclude, id: \.self) { identifier in
                            let normalized = identifier.lowercased()
                            ExcludedAppRow(
                                identifier: identifier,
                                isSelected: state.selectedIdentifiers.contains(normalized),
                                onToggle: {
                                    state.toggle(normalized)
                                },
                                onRemove: {
                                    state.pendingRemoval = ExcludeRemovalRequest(
                                        identifiers: [identifier],
                                        totalCount: configStore.config.exclude.count
                                    )
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var portsList: some View {
        let ports = configStore.config.portsExcluded
        if ports.isEmpty {
            emptyState(symbol: "network", title: "No excluded ports", detail: "Use a port's ••• menu in the Ports tab, or Add Ports below.")
        } else {
            VStack(spacing: 0) {
                selectAllHeader(
                    isAll: state.allPortsSelected(ports),
                    isPartial: state.portsPartiallySelected(ports),
                    count: "\(ports.count) excluded",
                    toggle: { state.toggleAllPorts(ports) }
                )

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(ports, id: \.self) { port in
                            ExcludedPortRow(
                                port: port,
                                listener: portsModel.ports.first { $0.port == port },
                                isSelected: state.selectedPorts.contains(port),
                                onToggle: { state.togglePort(port) },
                                onRemove: {
                                    state.pendingPortRemoval = PortRemovalRequest(ports: [port], removesAll: ports.count == 1)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var appsFooter: some View {
        HStack {
            Button {
                ExcludeAppPickerWindowController.shared.show()
            } label: {
                Label("Add Apps…", systemImage: "plus")
            }

            Spacer()

            Button(removeTitle(selected: state.selectedIdentifiers.count, all: state.allSelected(configStore.config.exclude))) {
                let identifiers = configStore.config.exclude.filter {
                    state.selectedIdentifiers.contains($0.lowercased())
                }
                state.pendingRemoval = ExcludeRemovalRequest(
                    identifiers: identifiers,
                    totalCount: configStore.config.exclude.count
                )
            }
            .disabled(state.selectedIdentifiers.isEmpty)
        }
        .font(.system(size: 11.5))
    }

    private var portsFooter: some View {
        let ports = configStore.config.portsExcluded
        let selected = ports.filter { state.selectedPorts.contains($0) }
        return HStack {
            Button {
                ExcludePortPickerWindowController.shared.show()
            } label: {
                Label("Add Ports…", systemImage: "plus")
            }

            Spacer()

            Button(removeTitle(selected: selected.count, all: state.allPortsSelected(ports))) {
                state.pendingPortRemoval = PortRemovalRequest(ports: selected, removesAll: selected.count == ports.count)
            }
            .disabled(selected.isEmpty)
        }
        .font(.system(size: 11.5))
    }

    private func removeTitle(selected: Int, all: Bool) -> String {
        if all { return "Remove All" }
        if selected > 1 { return "Remove Selected (\(selected))" }
        return "Remove Selected"
    }

    private func selectAllHeader(isAll: Bool, isPartial: Bool, count: String, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                QuitXSelectionCheckbox(isSelected: isAll, isPartial: isPartial)
                Text(isAll ? "Deselect All" : "Select All")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                Spacer()
                Text(count)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 27)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(QuitXTheme.accent)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.primary)
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

final class ExcludeTabState: ObservableObject {
    @Published var pendingRemoval: ExcludeRemovalRequest?
    @Published var selectedIdentifiers: Set<String> = []
    @Published var section: ExcludeSection = ExcludeSection.stored()
    @Published var selectedPorts: Set<Int> = []
    @Published var pendingPortRemoval: PortRemovalRequest?

    func select(_ newSection: ExcludeSection) {
        guard newSection != section else { return }
        section = newSection
        pendingRemoval = nil
        pendingPortRemoval = nil
        UserDefaults.standard.set(newSection.rawValue, forKey: ExcludeSection.defaultsKey)
    }

    func togglePort(_ port: Int) {
        if selectedPorts.contains(port) {
            selectedPorts.remove(port)
        } else {
            selectedPorts.insert(port)
        }
    }

    func allPortsSelected(_ ports: [Int]) -> Bool {
        !ports.isEmpty && Set(ports).isSubset(of: selectedPorts)
    }

    func portsPartiallySelected(_ ports: [Int]) -> Bool {
        let count = selectedPorts.intersection(Set(ports)).count
        return count > 0 && count < ports.count
    }

    func toggleAllPorts(_ ports: [Int]) {
        if allPortsSelected(ports) {
            selectedPorts.subtract(ports)
        } else {
            selectedPorts.formUnion(ports)
        }
    }

    func toggle(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
        }
    }

    func allSelected(_ identifiers: [String]) -> Bool {
        let all = Set(identifiers.map { $0.lowercased() })
        return !all.isEmpty && all.isSubset(of: selectedIdentifiers)
    }

    func partiallySelected(_ identifiers: [String]) -> Bool {
        let all = Set(identifiers.map { $0.lowercased() })
        let intersection = selectedIdentifiers.intersection(all)
        return !intersection.isEmpty && intersection.count < all.count
    }

    func toggleAll(_ identifiers: [String]) {
        let all = Set(identifiers.map { $0.lowercased() })
        if all.isSubset(of: selectedIdentifiers) {
            selectedIdentifiers.subtract(all)
        } else {
            selectedIdentifiers.formUnion(all)
        }
    }
}

struct ExcludeRemovalRequest: Identifiable {
    let identifiers: [String]
    let removesAll: Bool
    let displayName: String

    var id: String { identifiers.map { $0.lowercased() }.sorted().joined(separator: "|") }

    @MainActor
    static func appDisplayName(for identifier: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
              let bundle = Bundle(url: appURL),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String else {
            if let last = identifier.split(separator: ".").last, !last.isEmpty {
                return String(last)
            }
            return identifier
        }
        return name
    }

    var title: String {
        if removesAll {
            return "Remove all excluded apps?"
        }
        if identifiers.count == 1 {
            return "Remove \(displayName)?"
        }
        return "Remove \(identifiers.count) excluded apps?"
    }

    var message: String {
        if removesAll {
            return "All apps will no longer be protected from quit actions and Auto Quit."
        }
        if identifiers.count == 1 {
            return "\(displayName) will no longer be protected from quit actions and Auto Quit."
        }
        return "These \(identifiers.count) apps will no longer be protected from quit actions and Auto Quit."
    }

    @MainActor
    init(identifiers: [String], totalCount: Int) {
        self.identifiers = identifiers
        self.removesAll = !identifiers.isEmpty && identifiers.count == totalCount
        if identifiers.count == 1 {
            self.displayName = Self.appDisplayName(for: identifiers[0])
        } else {
            self.displayName = ""
        }
    }
}

private struct ExcludedAppRow: View {
    let identifier: String
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @StateObject private var state: ExcludedAppRowState

    init(identifier: String, isSelected: Bool, onToggle: @escaping () -> Void, onRemove: @escaping () -> Void) {
        self.identifier = identifier
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onRemove = onRemove
        _state = StateObject(wrappedValue: ExcludedAppRowState(identifier: identifier))
    }

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onToggle) {
                QuitXSelectionCheckbox(isSelected: isSelected)
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                Group {
                    if let icon = state.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app.dashed")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.secondary)
                            .padding(3)
                    }
                }
                .frame(width: 18, height: 18)

                Text(state.displayName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggle()
            }

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(state.isRemoveHovered ? Color.red : Color.secondary.opacity(state.isHovered ? 0.75 : 0.35))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(state.isRemoveHovered ? Color.red.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Remove \(state.displayName) from exclusions")
            .onHover { state.isRemoveHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}

@MainActor
private final class ExcludedAppRowState: ObservableObject {
    @Published var isHovered = false
    @Published var isRemoveHovered = false
    @Published var icon: NSImage?
    @Published var displayName: String

    init(identifier: String) {
        displayName = identifier
        Task { @MainActor [weak self] in
            let resolved = ExcludeRemovalRequest.appDisplayName(for: identifier)
            self?.displayName = resolved
        }
        AppIconCache.loadIcon(for: identifier) { [weak self] loaded in
            self?.icon = loaded
        }
    }
}

private final class ExcludedPortRowState: ObservableObject {
    @Published var isHovered = false
    @Published var isRemoveHovered = false
}

private struct ExcludedPortRow: View {
    let port: Int
    let listener: PortInfo?
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @StateObject private var state = ExcludedPortRowState()

    var body: some View {
        HStack(spacing: 9) {
            Button(action: onToggle) {
                QuitXSelectionCheckbox(isSelected: isSelected)
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                Text(verbatim: ":\(port)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.8)
                    .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.primary.opacity(0.08)))

                if let listener {
                    Text(listener.displayAppName)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                } else {
                    Text("Not listening")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }

                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(state.isRemoveHovered ? Color.red : Color.secondary.opacity(state.isHovered ? 0.75 : 0.35))
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(state.isRemoveHovered ? Color.red.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Remove :\(port) from exclusions")
            .onHover { state.isRemoveHovered = $0 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(state.isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { state.isHovered = $0 }
    }
}
