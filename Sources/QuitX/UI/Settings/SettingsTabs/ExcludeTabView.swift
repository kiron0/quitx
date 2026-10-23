import SwiftUI
import AppKit

struct ExcludeTabView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var state = ExcludeTabState()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Apps on this list stay out of manual and automatic Quit actions.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)

                Spacer()

                HelpPopoverButton(text: "VIP velvet rope immunity! Apps on this list get total immunity from all manual quits, hotkeys, and automated sweeps. 🎟️🛡️")
            }

            Group {
                if configStore.config.exclude.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "nosign")
                            .font(.system(size: 24))
                            .foregroundStyle(QuitXTheme.accent)
                        Text("No excluded apps")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text("Use an app's ••• menu in the QuitX popover to add it.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Button {
                            state.toggleAll(configStore.config.exclude)
                        } label: {
                            HStack(spacing: 8) {
                                QuitXSelectionCheckbox(
                                    isSelected: state.allSelected(configStore.config.exclude),
                                    isPartial: state.partiallySelected(configStore.config.exclude)
                                )
                                Text(state.allSelected(configStore.config.exclude) ? "Deselect All" : "Select All")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(configStore.config.exclude.count) excluded")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 27)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )

            HStack {
                Button {
                    ExcludeAppPickerWindowController.shared.show()
                } label: {
                    Label("Add Apps…", systemImage: "plus")
                }

                Spacer()

                Button(removeButtonTitle) {
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 480, height: 306, alignment: .topLeading)
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
            }
        }
        .animation(.easeInOut(duration: 0.18), value: state.pendingRemoval != nil)
    }

    private var removeButtonTitle: String {
        if state.allSelected(configStore.config.exclude) {
            return "Remove All"
        }
        if state.selectedIdentifiers.count > 1 {
            return "Remove Selected (\(state.selectedIdentifiers.count))"
        }
        return "Remove Selected"
    }
}

final class ExcludeTabState: ObservableObject {
    @Published var pendingRemoval: ExcludeRemovalRequest?
    @Published var selectedIdentifiers: Set<String> = []

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
