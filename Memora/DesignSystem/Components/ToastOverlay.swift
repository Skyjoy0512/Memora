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
            case .info: return MemoraColor.accentNothing
            }
        }

        var accentColor: Color {
            switch self {
            case .error: return MemoraColor.accentRed
            case .success: return MemoraColor.accentGreen
            case .info: return MemoraColor.accentNothing
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
                .font(MemoraTypography.subheadline)
                .foregroundStyle(MemoraColor.textPrimary)
                .lineLimit(2)

            Spacer()

            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .font(MemoraTypography.caption1)
                    .foregroundStyle(MemoraColor.textTertiary)
            }
        }
        .padding(.horizontal, MemoraSpacing.md)
        .padding(.vertical, MemoraSpacing.sm)
        .glassCard(.default)
        .padding(.horizontal, MemoraSpacing.md)
    }
}
