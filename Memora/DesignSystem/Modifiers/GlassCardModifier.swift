import SwiftUI

struct GlassCardConfiguration {
    var cornerRadius: CGFloat = MemoraRadius.md
    var accentTint: Bool = true
    var glow: Bool = false
    var dotMatrix: Bool = false

    static let `default` = GlassCardConfiguration()
    static let prominent = GlassCardConfiguration(
        cornerRadius: MemoraRadius.lg,
        glow: false,
        dotMatrix: false
    )
}

struct GlassCardModifier: ViewModifier {
    let config: GlassCardConfiguration

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
            .glassEffect(.regular, in: .rect(cornerRadius: config.cornerRadius))
    }

    private func ios17Body(_ content: Content) -> some View {
        content
            .background(
                MemoraColor.surfaceCard,
                in: RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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
