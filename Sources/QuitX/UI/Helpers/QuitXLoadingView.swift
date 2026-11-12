import SwiftUI

/// Shared page loading state, using the uninstaller's scanning animation.
struct QuitXLoadingView: View {
    let text: String
    var detail: String? = nil
    var symbol: String = "magnifyingglass"

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            ScanPulse(symbol: symbol)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private final class ScanPulseState: ObservableObject {
    @Published var pulse = false
}

private struct ScanPulse: View {
    @StateObject private var state = ScanPulseState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let symbol: String
    private let tint = Color(nsColor: .systemBlue)

    var body: some View {
        ZStack {
            ForEach(0..<(reduceMotion ? 0 : 2), id: \.self) { index in
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                    .scaleEffect(state.pulse ? 1.8 : 1.0)
                    .opacity(state.pulse ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.7),
                        value: state.pulse
                    )
            }
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 80, height: 80)
        .onAppear { state.pulse = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduced in state.pulse = !reduced }
        .accessibilityHidden(true)
    }
}

