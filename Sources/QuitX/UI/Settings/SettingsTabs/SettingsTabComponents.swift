import SwiftUI

let labelColumnWidth: CGFloat = 90

func row<Content: View, Help: View>(
    label: String,
    @ViewBuilder content: () -> Content,
    @ViewBuilder help: () -> Help
) -> some View {
    HStack(alignment: .center, spacing: 10) {
        Text(label)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Color.primary)
            .frame(width: labelColumnWidth, alignment: .trailing)

        content().fixedSize()

        Spacer(minLength: 0)

        help()
    }
    .frame(height: 25)
}

func row<Content: View>(
    label: String,
    @ViewBuilder content: () -> Content
) -> some View {
    row(label: label, content: content) {
        EmptyView()
    }
}

func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
    Button {
        isOn.wrappedValue.toggle()
    } label: {
        HStack(spacing: 8) {
            QuitXSelectionCheckbox(isSelected: isOn.wrappedValue)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
    }
    .buttonStyle(.plain)
}

func appearanceRadio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        selected ? Color.accentColor : Color.secondary.opacity(0.5),
                        lineWidth: 1.5
                    )
                    .frame(width: 14, height: 14)
                if selected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
            }
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.primary)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

