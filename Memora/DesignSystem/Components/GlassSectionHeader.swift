import SwiftUI

struct GlassSectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
            HStack(spacing: MemoraSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(MemoraColor.textTertiary)
                }

                Text(title)
                    .font(MemoraTypography.chatLabel)
                    .foregroundStyle(MemoraColor.textSecondary)
            }

            Rectangle()
                .fill(MemoraColor.interactiveSecondaryBorder)
                .frame(height: 1)
        }
    }
}
