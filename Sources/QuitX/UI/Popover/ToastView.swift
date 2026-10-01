import SwiftUI

struct ToastView: View {
    let count: Int

    var body: some View {
        Text(count == 1 ? "1 app quit" : "\(count) apps quit")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.black.opacity(0.75), in: Capsule())
    }
}
