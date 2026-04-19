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
            .background(
                MemoraColor.surfaceSecondary,
                in: RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: variant.cornerRadius, style: .continuous)
                    .stroke(MemoraColor.divider.opacity(0.5), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func nothingCard(
        _ variant: NothingCardVariant = .standard
    ) -> some View {
        NothingCardContainer(variant: variant) { self }
    }
}
