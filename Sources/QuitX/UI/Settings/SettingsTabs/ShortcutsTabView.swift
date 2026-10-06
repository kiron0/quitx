import SwiftUI
import AppKit

@MainActor
final class ShortcutsViewState: ObservableObject {
    @Published var recordingRow: String? = nil
    var localMonitor: Any? = nil

    func startMonitor(sm: ShortcutManager) {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak sm] event in
            guard let self = self, let row = self.recordingRow, let sm = sm else { return event }
            if self.processEvent(event, row: row, sm: sm) {
                return nil
            }
            return event
        }
    }

    func stopMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func processEvent(_ event: NSEvent, row: String, sm: ShortcutManager) -> Bool {
        if event.keyCode == 53 {
            DispatchQueue.main.async { self.recordingRow = nil }
            return true
        }
        if event.keyCode == 51 {
            DispatchQueue.main.async {
                self.applyKeys([], for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }

        let keys = ShortcutManager.eventToKeys(event)
        if !keys.isEmpty {
            DispatchQueue.main.async {
                self.applyKeys(keys, for: row, sm: sm)
                self.recordingRow = nil
            }
            return true
        }
        return false
    }

    func applyKeys(_ keys: [String], for row: String, sm: ShortcutManager) {
        let slot: ShortcutManager.Slot?
        switch row {
        case "activate": slot = .activateMenu
        case "quit": slot = .quitAll
        case "force": slot = .forceQuitAll
        default: slot = nil
        }
        if let slot {
            sm.setKeys(keys, for: slot)
        }
    }
}

struct ShortcutsTabCloneView: View {
    @ObservedObject private var sm = ShortcutManager.shared
    @StateObject private var viewState = ShortcutsViewState()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                shortcutLine(
                    id: "activate",
                    label: "Activate menu:",
                    isEnabled: $sm.activateMenuEnabled,
                    keys: $sm.activateMenuKeys
                )
                shortcutLine(
                    id: "quit",
                    label: "Quit all:",
                    isEnabled: $sm.quitAllEnabled,
                    keys: $sm.quitAllKeys
                )
                shortcutLine(
                    id: "force",
                    label: "Force quit all:",
                    isEnabled: $sm.forceQuitAllEnabled,
                    keys: $sm.forceQuitAllKeys
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)

            if let error = sm.shortcutError ?? sm.registrationError {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
            } else {
                HStack(spacing: 10) {
                    Text("⌥")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))

                    Text("Hold down Option to toggle “Quit” and “Force Quit”.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 400, height: 215)
        .background(QuitXTheme.windowBackground)
        .onAppear {
            viewState.startMonitor(sm: sm)
        }
        .onDisappear {
            viewState.stopMonitor()
        }
    }

    private func shortcutLine(id: String, label: String, isEnabled: Binding<Bool>, keys: Binding<[String]>) -> some View {
        let active = isEnabled.wrappedValue
        let isRecording = (viewState.recordingRow == id)
        let keyList = keys.wrappedValue

        return HStack(spacing: 9) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(width: 105, alignment: .trailing)

            Button {
                isEnabled.wrappedValue.toggle()
            } label: {
                QuitXSelectionCheckbox(isSelected: active)
            }
            .buttonStyle(.plain)

            Button {
                if active {
                    viewState.recordingRow = (viewState.recordingRow == id ? nil : id)
                }
            } label: {
                HStack(spacing: 3) {
                    if isRecording {
                        Text("Type keys...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(QuitXTheme.accent)
                    } else if keyList.isEmpty {
                        Text("None")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    } else {
                        ForEach(keyList, id: \.self) { key in
                            Text(key)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(active ? Color.primary : Color.secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 3.5)
                                        .fill(active ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06))
                                 )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .frame(width: 105, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(active ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? QuitXTheme.accent : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                viewState.applyKeys([], for: id, sm: sm)
                if viewState.recordingRow == id { viewState.recordingRow = nil }
            } label: {
                if let img = AssetImages.load("recorder-delete") {
                    Image(nsImage: img)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 13, height: 13)
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle((active && !keyList.isEmpty) ? Color.secondary : Color.secondary.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .disabled(!active || keyList.isEmpty)
            .frame(width: 18, height: 18)

            Spacer()
        }
    }
}

