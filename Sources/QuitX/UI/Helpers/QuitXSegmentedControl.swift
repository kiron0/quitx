import SwiftUI

struct QuitXSegment<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let symbol: String

    var id: Value { value }
}

private final class SegmentHoverState<Value: Hashable>: ObservableObject {
    @Published var hovered: Value?
}

struct QuitXSegmentedControl<Value: Hashable>: View {
    let segments: [QuitXSegment<Value>]
    @Binding var selection: Value
    var height: CGFloat = 22

    @StateObject private var hover = SegmentHoverState<Value>()

    private static var selectedFill: LinearGradient {
        LinearGradient(
            colors: [QuitXTheme.accent, Color(red: 232/255, green: 155/255, blue: 0/255)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments) { segment in
                button(segment)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func button(_ segment: QuitXSegment<Value>) -> some View {
        let isSelected = selection == segment.value
        let isHovered = hover.hovered == segment.value
        return Button {
            if selection != segment.value { selection = segment.value }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: segment.symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(segment.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.88) : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Self.selectedFill)
                        .shadow(color: QuitXTheme.accent.opacity(0.25), radius: 1.5, y: 0.5)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.06))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hover.hovered = segment.value
            } else if hover.hovered == segment.value {
                hover.hovered = nil
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
