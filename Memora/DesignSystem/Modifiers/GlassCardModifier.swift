import SwiftUI

struct GlassCardConfiguration {
    var cornerRadius: CGFloat = MemoraRadius.md
    var accentTint: Bool = true
    var glow: Bool = true
    var dotMatrix: Bool = false

    static let `default` = GlassCardConfiguration()
    static let prominent = GlassCardConfiguration(
        cornerRadius: MemoraRadius.lg,
        glow: true,
        dotMatrix: true
    )
}

struct GlassCardModifier: ViewModifier {
    let config: GlassCardConfiguration

    func body(content: Content) -> some View {
        content
            .modifier(AdaptiveGlassModifier(cornerRadius: config.cornerRadius))
            .if(config.accentTint) { view in
                view.overlay {
                    RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                        .fill(MemoraColor.glassTint)
                }
            }
            .if(config.glow) { view in
                view.nothingGlow(.subtle)
            }
            .if(config.dotMatrix) { view in
                view.nothingDotMatrix()
            }
    }
}

private struct AdaptiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

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
                    .fill(Color.white.opacity(0.15))
                    .blendMode(.overlay)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MemoraColor.glassBorder, lineWidth: 0.5)
            }
            .shadow(color: MemoraColor.glassShadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Conditional View Modifier Helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    func glassCard(
        _ config: GlassCardConfiguration = .default
    ) -> some View {
        modifier(GlassCardModifier(config: config))
    }
}
