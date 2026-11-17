import SwiftUI

final class QuickCleanThresholdInput: ObservableObject {
    @Published var text = ""
}

struct QuickCleanThresholdField: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var input = QuickCleanThresholdInput()
    @FocusState private var focused: Bool

    private var unit: QuickCleanSizeUnit { configStore.config.quickCleanAutoThresholdUnit }
    private var savedMB: Int { configStore.config.quickCleanAutoThresholdMB }

    private var problem: QuickCleanThreshold.Problem? {
        if case .failure(let problem) = QuickCleanThreshold.parse(input.text, unit: unit) { return problem }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(problem == nil ? Color.secondary.opacity(0.85) : Color.red.opacity(0.85))
                        .accessibilityHidden(true)

                    TextField("", text: $input.text, prompt: Text(QuickCleanThreshold.format(savedMB, unit: unit)).foregroundColor(Color.secondary))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                        .disableInitialFocus()
                        .onSubmit { commit() }
                        .onExitCommand { revert() }
                        .accessibilityLabel("Auto clean size limit in \(unit.rawValue)")

                    Text(unit.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 8)
                .frame(width: 112, height: 26)
                .background(SearchFieldGlassBackground(isFocused: focused, cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(problem == nil ? Color.clear : Color.red.opacity(0.7), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.12), value: problem)

                Stepper("") {
                    step(up: true)
                } onDecrement: {
                    step(up: false)
                }
                .labelsHidden()

                Picker("", selection: Binding(get: { unit }, set: { switchUnit(to: $0) })) {
                    ForEach(QuickCleanSizeUnit.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 84)
            }

            if let problem {
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.red)
                    .transition(.opacity)
            }
        }
        .onAppear { syncFromConfig() }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onChange(of: savedMB) { _, _ in
            if !focused { syncFromConfig() }
        }
    }

    private func syncFromConfig() {
        input.text = QuickCleanThreshold.format(savedMB, unit: unit)
    }

    private func commit() {
        guard case .success(let parsed) = QuickCleanThreshold.parse(input.text, unit: unit) else { return }
        save(megabytes: parsed.megabytes, unit: parsed.unit)
    }

    private func revert() {
        syncFromConfig()
        focused = false
    }

    private func step(up: Bool) {
        let base: Int
        if case .success(let parsed) = QuickCleanThreshold.parse(input.text, unit: unit) {
            base = parsed.megabytes
        } else {
            base = savedMB
        }
        save(megabytes: QuickCleanThreshold.stepped(base, unit: unit, up: up), unit: unit)
    }

    private func switchUnit(to newUnit: QuickCleanSizeUnit) {
        let megabytes: Int
        if case .success(let parsed) = QuickCleanThreshold.parse(input.text, unit: unit) {
            megabytes = parsed.megabytes
        } else {
            megabytes = savedMB
        }
        save(megabytes: megabytes, unit: newUnit)
    }

    private func save(megabytes: Int, unit newUnit: QuickCleanSizeUnit) {
        let clamped = QuickCleanThreshold.clamped(megabytes)
        configStore.config.quickCleanAutoThresholdMB = clamped
        configStore.config.quickCleanAutoThresholdUnit = newUnit
        configStore.save()
        input.text = QuickCleanThreshold.format(clamped, unit: newUnit)
        QuickCleanAutoService.shared.evaluateNow()
    }
}
