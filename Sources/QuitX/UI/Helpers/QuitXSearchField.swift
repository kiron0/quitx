import SwiftUI

struct QuitXSearchField: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 28
    var cornerRadius: CGFloat = 7
    var horizontalPadding: CGFloat = 8
    var disableInitialFocus: Bool = true
    var animateClearButton: Bool = false
    var accessibilityClearLabel: String = "Clear search"
    var onSubmit: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(text.isEmpty ? Color.secondary.opacity(0.85) : QuitXTheme.accent)
                .accessibilityHidden(true)

            textField

            if !text.isEmpty {
                clearButton
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .background(SearchFieldGlassBackground(isFocused: !text.isEmpty, cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var clearButton: some View {
        let button = Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityClearLabel)

        if animateClearButton {
            button.transition(.opacity)
        } else {
            button
        }
    }

    private var textField: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Color.primary)
            .applyIf(disableInitialFocus) { $0.disableInitialFocus() }
            .applyIf(onSubmit != nil) {
                $0.onSubmit { onSubmit?() }
            }
            .applyIf(onMoveDown != nil) {
                $0.onKeyPress(.downArrow) {
                    onMoveDown?()
                    return .handled
                }
            }
            .applyIf(onMoveUp != nil) {
                $0.onKeyPress(.upArrow) {
                    onMoveUp?()
                    return .handled
                }
            }
    }
}

private extension View {
    @ViewBuilder
    func applyIf<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

