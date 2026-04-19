import SwiftUI

struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var height: CGFloat = 16
    var cornerRadius: CGFloat = MemoraRadius.sm
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hex: "E8E8EA"))
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: MemoraColor.accentNothingSubtle, location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 300 : -300)
            }
            .clipped()
            .onAppear {
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            }
    }
}
