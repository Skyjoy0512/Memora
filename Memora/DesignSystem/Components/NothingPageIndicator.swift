import SwiftUI

struct NothingPageIndicator: View {
    let totalPages: Int
    @Binding var currentPage: Int

    var body: some View {
        HStack(spacing: MemoraSpacing.xs) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? MemoraColor.accentNothing : MemoraColor.divider)
                    .frame(
                        width: index == currentPage ? 8 : 6,
                        height: index == currentPage ? 8 : 6
                    )
                    .nothingGlow(index == currentPage ? .subtle : .init(color: .clear, radius: 0, intensity: 0, animated: false))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
}
