import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = MemoraRadius.lg
    var opacity: Double = 0.72
    var shadowRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(opacity))
                    .blendMode(.overlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
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
