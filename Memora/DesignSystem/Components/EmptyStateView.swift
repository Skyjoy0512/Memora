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
                .font(.system(.largeTitle))
                .foregroundStyle(MemoraColor.accentNothing.opacity(0.6))
                .nothingGlow(.subtle)

            VStack(spacing: MemoraSpacing.xs) {
                Text(title)
                    .font(MemoraTypography.title2)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(description)
                    .font(MemoraTypography.footnote)
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
