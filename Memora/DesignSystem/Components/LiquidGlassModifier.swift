import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = MemoraRadius.lg
    var opacity: Double = 0.72
    var shadowRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            ios26Body(content)
        } else {
            ios17Body(content)
        }
    }

    @available(iOS 26.0, *)
    private func ios26Body(_ content: Content) -> some View {
        content
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }

    private func ios17Body(_ content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(opacity))
                    .blendMode(.overlay)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
            }
            .shadow(color: MemoraColor.shadowMedium, radius: shadowRadius, x: 0, y: 4)
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = MemoraRadius.lg,
        opacity: Double = 0.72,
        shadowRadius: CGFloat = 12
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            opacity: opacity,
            shadowRadius: shadowRadius
        ))
    }
}
