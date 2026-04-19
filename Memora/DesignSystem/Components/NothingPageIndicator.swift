import SwiftUI

struct NothingPageIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .animation(reduceMotion ? nil : MemoraAnimation.springSnappy, value: currentPage)
            }
        }
    }
}
