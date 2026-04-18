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
                .font(.system(size: 36))
                .foregroundStyle(MemoraColor.accentNothing)
                .frame(width: 100, height: 100)
                .nothingCard(.prominent)

            VStack(spacing: MemoraSpacing.phi2) {
                Text(title)
                    .font(MemoraTypography.phiTitle)
                    .foregroundStyle(MemoraColor.textPrimary)

                Text(description)
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(MemoraColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let buttonTitle, let buttonAction {
                PillButton(title: buttonTitle, action: buttonAction, style: .nothing)
                    .padding(.horizontal, MemoraSpacing.xl)
            }
        }
        .padding(MemoraSpacing.xxl)
    }
}
