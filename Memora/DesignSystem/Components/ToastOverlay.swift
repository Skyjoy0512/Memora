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
    }

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
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
        .liquidGlass(cornerRadius: MemoraRadius.md)
        .padding(.horizontal, MemoraSpacing.md)
    }
}
