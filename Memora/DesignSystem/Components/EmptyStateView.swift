import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MemoraSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(MemoraColor.textTertiary)

            VStack(spacing: MemoraSpacing.xs) {
                Text(title)
                    .font(MemoraTypography.title3)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(description)
                    .font(MemoraTypography.subheadline)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                PillButton(title: buttonTitle, action: buttonAction)
                    .padding(.horizontal, MemoraSpacing.xl)
            }
        }
        .padding(MemoraSpacing.xl)
    }
}
