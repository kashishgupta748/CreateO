import SwiftUI

struct GuideProgressView: View {
    let currentIndex: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? Color.accentColor : Color.primary.opacity(0.12))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
        .accessibilityHidden(true)
    }
}
