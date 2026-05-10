import SwiftUI

// MARK: - Liquid Glass Modifier (Rect)

/// iOS 26 では `glassEffect(.regular.interactive(), in: .rect(cornerRadius:))`、
/// iOS 17-25 では `.ultraThinMaterial` + 白 overlay + 0.5pt 白 stroke + shadow で
/// Liquid Glass を再現する ViewModifier。
///
/// ## GlassEffectContainer の使い分け
/// - 近接する複数のガラス要素（例: タブバー内のボタン群、FAB展開メニューなど）は
///   `GlassEffectContainer` で囲うことで、要素間のガラス境界が自然に融合する。
/// - 単独のガラスボタンや離れたガラス要素には、この `liquidGlass()` modifier を
///   個別に適用してよい。
/// - iOS 17-25 では `GlassEffectContainer` に相当するものはないため、
///   個別の material 適用でも視覚的な破綻は許容範囲。
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

// MARK: - Liquid Glass Modifier (Circle)

/// 円形の Liquid Glass 用 ViewModifier。
/// iOS 26 では `glassEffect(.regular.interactive(), in: .circle)`、
/// iOS 17-25 では `.ultraThinMaterial` Circle + 白 overlay + 0.5pt stroke + shadow。
struct LiquidGlassCircleModifier: ViewModifier {
    var opacity: Double = 0.72
    var shadowRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(opacity))
                        .blendMode(.overlay)
                }
                .overlay {
                    Circle()
                        .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
                }
                .shadow(color: MemoraColor.shadowMedium, radius: shadowRadius, x: 0, y: 4)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// 角丸の Liquid Glass 効果を適用する。
    /// - Parameters:
    ///   - cornerRadius: 角丸半径（デフォルト `MemoraRadius.lg` = 16）
    ///   - opacity: iOS 17-25 fallback 時の白 overlay 不透明度（デフォルト 0.72）
    ///   - shadowRadius: 影の半径（デフォルト 12）
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

    /// 円形の Liquid Glass 効果を適用する。
    /// - Parameters:
    ///   - opacity: iOS 17-25 fallback 時の白 overlay 不透明度（デフォルト 0.72）
    ///   - shadowRadius: 影の半径（デフォルト 12）
    ///
    /// 円形ボタン（FAB、戻るボタン、AAボタン外円など）に使用する。
    func liquidGlassCircle(
        opacity: Double = 0.72,
        shadowRadius: CGFloat = 12
    ) -> some View {
        modifier(LiquidGlassCircleModifier(
            opacity: opacity,
            shadowRadius: shadowRadius
        ))
    }
}
