import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(QuitXTheme.accent.opacity(0.12))
                    .frame(width: 24, height: 24)

                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(QuitXTheme.accent)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)

            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(height: 0.5)
        }
    }
}

struct SettingsRow<Content: View, Help: View>: View {
    let label: String
    let content: Content
    let help: Help

    private var title: String {
        label.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    private var symbol: String {
        switch title.lowercased() {
        case "startup": return "power"
        case "sounds": return "speaker.wave.2"
        case "updates": return "arrow.triangle.2.circlepath"
        case "menu bar": return "menubar.rectangle"
        case "appearance": return "paintpalette"
        case "sort": return "arrow.up.arrow.down"
        case "default": return "cursorarrow.click.2"
        case "reset": return "arrow.counterclockwise"
        case "schedule": return "calendar.badge.clock"
        case "sleep": return "moon.zzz"
        case "windows": return "macwindow"
        case "health": return "heart.text.square"
        case "last window": return "macwindow.badge.plus"
        case "cpu hogs": return "cpu"
        case "memory pressure": return "memorychip"
        case "auto quit": return "hourglass"
        case "background": return "square.3.layers.3d"
        case "protection": return "shield"
        case "behavior": return "switch.2"
        case "extras": return "plus.square"
        case "port killing": return "network"
        case "refresh": return "arrow.clockwise"
        case "discovery": return "dot.radiowaves.left.and.right"
        case "group by": return "square.stack.3d.up"
        case "safety": return "checkmark.shield"
        case "selection": return "checklist"
        case "exclude": return "nosign"
        default: return "slider.horizontal.3"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !title.isEmpty {
                SettingsSectionHeader(title: title, symbol: symbol)
                    .padding(.top, 14)
            }

            HStack(alignment: .center, spacing: 10) {
                content

                Spacer(minLength: 0)

                help
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .padding(.leading, 33)
        }
    }
}

func row<Content: View, Help: View>(
    label: String,
    @ViewBuilder content: () -> Content,
    @ViewBuilder help: () -> Help
) -> some View {
    SettingsRow(label: label, content: content(), help: help())
}

func row<Content: View>(
    label: String,
    @ViewBuilder content: () -> Content
) -> some View {
    row(label: label, content: content) {
        EmptyView()
    }
}

struct SettingsSwitchIndicator: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(isOn ? QuitXTheme.accent : Color.primary.opacity(0.13))
                .frame(width: 30, height: 18)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.16), radius: 1, y: 0.5)
                .offset(x: isOn ? 6 : -6)
        }
        .accessibilityHidden(true)
    }
}

private struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 9) {
                SettingsSwitchIndicator(isOn: isOn)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
    SettingsToggle(title: title, isOn: isOn)
}

private struct SettingsRadio: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(
                        colors: [QuitXTheme.accent.opacity(selected ? 0.23 : 0.10), Color.primary.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? QuitXTheme.accent : Color.secondary)
                }
                .frame(width: 70, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
            .padding(5)
            .background(QuitXTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? QuitXTheme.accent : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var symbol: String {
        switch title.lowercased() {
        case "classic": return "rectangle.fill"
        case "liquid glass": return "drop.fill"
        case "icon": return "gauge.with.dots.needle.67percent"
        case "text": return "textformat"
        case "gb": return "internaldrive"
        case "percentage": return "percent"
        case "24-hour": return "clock"
        case "12-hour": return "clock.badge"
        default: return "checkmark.circle"
        }
    }
}

func appearanceRadio(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    SettingsRadio(title: title, selected: selected, action: action)
}

struct SettingsChoiceOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    let symbol: String
    var iconStyle: SettingsChoiceIconStyle = .system

    var id: Value { value }
}

enum SettingsChoiceIconStyle {
    case system
    case dockerOutline
}

private struct DockerOutlineIcon: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)

            var containers = Path()
            for rect in [
                CGRect(x: 3, y: 8, width: 4, height: 4),
                CGRect(x: 8, y: 8, width: 4, height: 4),
                CGRect(x: 13, y: 8, width: 4, height: 4),
                CGRect(x: 8, y: 3, width: 4, height: 4),
                CGRect(x: 13, y: 3, width: 4, height: 4)
            ] {
                containers.addRoundedRect(in: rect, cornerSize: CGSize(width: 0.7, height: 0.7))
            }
            context.stroke(containers, with: .color(color), lineWidth: 1.35)

            var whale = Path()
            whale.move(to: CGPoint(x: 2, y: 13.5))
            whale.addLine(to: CGPoint(x: 17.5, y: 13.5))
            whale.addCurve(
                to: CGPoint(x: 10.5, y: 21),
                control1: CGPoint(x: 17, y: 18.5),
                control2: CGPoint(x: 14.5, y: 21)
            )
            whale.addCurve(
                to: CGPoint(x: 2, y: 13.5),
                control1: CGPoint(x: 6, y: 21),
                control2: CGPoint(x: 3, y: 18)
            )
            whale.move(to: CGPoint(x: 17.2, y: 13.5))
            whale.addCurve(
                to: CGPoint(x: 21.5, y: 9.5),
                control1: CGPoint(x: 19.3, y: 13.3),
                control2: CGPoint(x: 20.7, y: 12)
            )
            whale.move(to: CGPoint(x: 19.2, y: 10.8))
            whale.addLine(to: CGPoint(x: 18.5, y: 7.5))
            whale.addLine(to: CGPoint(x: 21.5, y: 9.5))
            whale.addLine(to: CGPoint(x: 23, y: 7))
            context.stroke(whale, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

struct SettingsChoiceTiles<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsChoiceOption<Value>]
    var width: CGFloat = 500

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 92), spacing: 7)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(options) { option in
                let selected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    VStack(spacing: 5) {
                        Group {
                            if option.iconStyle == .dockerOutline {
                                DockerOutlineIcon(color: selected ? QuitXTheme.accent : Color.secondary)
                            } else {
                                Image(systemName: option.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(selected ? QuitXTheme.accent : Color.secondary)
                            }
                        }
                        .frame(height: 22)

                        Text(option.title)
                            .font(.system(size: 9.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        selected ? QuitXTheme.accent.opacity(0.09) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selected ? QuitXTheme.accent : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 0.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct SettingsMenuChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.menu)
            .controlSize(.small)
            .padding(.horizontal, 5)
            .frame(minHeight: 30)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
    }
}

extension View {
    func settingsMenu() -> some View {
        modifier(SettingsMenuChrome())
    }
}

struct NativeFilterPicker<T: Hashable & CaseIterable & RawRepresentable>: NSViewRepresentable where T.RawValue == String, T.AllCases: RandomAccessCollection {
    @Binding var selection: T

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11.5)
        button.target = context.coordinator
        button.action = #selector(Coordinator.valueChanged(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for item in T.allCases {
            button.addItem(withTitle: item.rawValue)
        }
        if let idx = Array(T.allCases).firstIndex(of: selection) {
            button.selectItem(at: idx)
        }
        return button
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let cases = Array(T.allCases)
        if nsView.numberOfItems != cases.count {
            nsView.removeAllItems()
            for item in cases {
                nsView.addItem(withTitle: item.rawValue)
            }
        }
        if let idx = cases.firstIndex(of: selection), nsView.indexOfSelectedItem != idx {
            nsView.selectItem(at: idx)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: NativeFilterPicker

        init(_ parent: NativeFilterPicker) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            let cases = Array(T.allCases)
            if index >= 0 && index < cases.count {
                parent.selection = cases[index]
            }
        }
    }
}

struct SettingsInlineNote: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(QuitXTheme.accent)
                .frame(width: 28, height: 28)
                .background(QuitXTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(QuitXTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(QuitXTheme.accent.opacity(0.14), lineWidth: 0.5)
        )
    }
}
