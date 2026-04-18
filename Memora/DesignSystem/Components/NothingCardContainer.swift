import SwiftUI

enum NothingCardVariant {
    case standard
    case prominent
    case minimal

    var cornerRadius: CGFloat {
        switch self {
        case .standard: return MemoraRadius.md
        case .prominent: return MemoraRadius.lg
        case .minimal: return MemoraRadius.sm
        }
    }

    var hasGlow: Bool {
        switch self {
        case .standard: return true
        case .prominent: return true
        case .minimal: return false
        }
    }

    var hasDotMatrix: Bool {
        switch self {
        case .standard: return false
        case .prominent: return true
        case .minimal: return false
        }
    }

    var padding: CGFloat {
        switch self {
        case .standard: return MemoraSpacing.md
        case .prominent: return MemoraSpacing.lg
        case .minimal: return MemoraSpacing.sm
        }
    }
}

struct NothingCardContainer<Content: View>: View {
    let variant: NothingCardVariant
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(variant.padding)
            .glassCard(.init(
                cornerRadius: variant.cornerRadius,
                accentTint: true,
                glow: variant.hasGlow,
                dotMatrix: variant.hasDotMatrix
            ))
    }
}

extension View {
    func nothingCard(
        _ variant: NothingCardVariant = .standard
    ) -> some View {
        NothingCardContainer(variant: variant) { self }
    }
}
