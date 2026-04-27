import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MemoraSpacing.phi4) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(MemoraColor.textTertiary)

            VStack(spacing: MemoraSpacing.phi2) {
                Text(title)
                    .font(MemoraTypography.chatSegment)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(description)
                    .font(MemoraTypography.chatBody)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                PillButton(title: buttonTitle, action: buttonAction, style: .primary)
                    .padding(.horizontal, MemoraSpacing.xl)
            }
        }
        .padding(MemoraSpacing.xxl)
    }
}
