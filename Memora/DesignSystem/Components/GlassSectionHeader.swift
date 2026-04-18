import SwiftUI

struct GlassSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
            HStack(spacing: MemoraSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(MemoraTypography.phiCaption)
                        .foregroundStyle(MemoraColor.accentNothing)
                }

                Text(title)
                    .font(MemoraTypography.phiCaption)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Rectangle()
                .fill(MemoraColor.divider.opacity(0.4))
                .frame(height: 0.5)
        }
    }
}
