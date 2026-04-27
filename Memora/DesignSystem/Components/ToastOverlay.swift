import SwiftUI

struct ToastOverlay: View {
    let icon: String
    let message: String
    var style: Style = .error
    var onDismiss: (() -> Void)? = nil

    enum Style {
        case error
        case success
        case info

        var iconColor: Color {
            switch self {
            case .error: return MemoraColor.accentRed
            case .success: return MemoraColor.accentGreen
            case .info: return MemoraColor.accentBlue
            }
        }

        var accentColor: Color {
            switch self {
            case .error: return MemoraColor.accentRed
            case .success: return MemoraColor.accentGreen
            case .info: return MemoraColor.accentBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            Rectangle()
                .fill(style.accentColor)
                .frame(width: 3)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: 13))

            Image(systemName: icon)
                .font(MemoraTypography.body)
                .foregroundStyle(style.iconColor)

            Text(message)
                .font(MemoraTypography.chatBody)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(MemoraColor.textTertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
        .background(
            MemoraColor.surfaceCard,
            in: RoundedRectangle(cornerRadius: MemoraRadius.md, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: MemoraRadius.md, style: .continuous)
                .stroke(MemoraColor.interactiveSecondaryBorder, lineWidth: 1)
        }
        .padding(.horizontal, MemoraSpacing.md)
    }
}
