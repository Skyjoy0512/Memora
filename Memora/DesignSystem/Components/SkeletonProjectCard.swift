import SwiftUI

/// ProjectCard のスケルトンプレースホルダー。
/// 初期ロード中にグリッド表示として使用する。
struct SkeletonProjectCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            SkeletonView(height: MemoraSize.iconMedium, cornerRadius: MemoraRadius.sm)

            SkeletonView(height: 18, cornerRadius: 4)
                .frame(maxWidth: 100)

            Spacer(minLength: MemoraSpacing.xxs)

            HStack {
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(maxWidth: 60)
                Spacer()
                SkeletonView(height: 16, cornerRadius: 8)
                    .frame(maxWidth: 28)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .nothingCard(.standard)
        .accessibilityHidden(true)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MemoraSpacing.md) {
        SkeletonProjectCard()
        SkeletonProjectCard()
        SkeletonProjectCard()
        SkeletonProjectCard()
    }
    .padding()
}
