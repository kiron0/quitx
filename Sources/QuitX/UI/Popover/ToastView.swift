import SwiftUI

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isError ? Color.red.opacity(0.88) : Color.black.opacity(0.78), in: Capsule())
    }
}
