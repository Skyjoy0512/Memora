import SwiftUI

struct PillButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary
    var size: Size = .regular
    var isDisabled: Bool = false
    var isLoading: Bool = false

    enum Style {
        case primary
        case outline
    }

    enum Size {
        case regular
        case small

        var height: CGFloat {
            switch self {
            case .regular: return MemoraHeight.button
            case .small: return 40
            }
        }

        var font: Font {
            switch self {
            case .regular: return MemoraTypography.headline
            case .small: return MemoraTypography.subheadline
            }
        }
    }

    private var effectiveDisabled: Bool {
        isDisabled || isLoading
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MemoraSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : MemoraColor.accentPrimary)
                }

                Text(title)
                    .font(size.font)
                    .foregroundStyle(style == .primary ? .white : MemoraColor.accentPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                style == .primary
                    ? MemoraColor.accentPrimary
                    : Color.clear
            )
            .overlay(
                Capsule()
                    .stroke(
                        style == .primary ? Color.clear : MemoraColor.accentPrimary,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
            .opacity(effectiveDisabled ? 0.5 : 1.0)
        }
        .disabled(effectiveDisabled)
    }
}
