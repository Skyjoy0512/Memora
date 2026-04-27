import SwiftUI

/// AudioFileRow のスケルトンプレースホルダー。
/// 初期ロード中にリスト表示として使用する。
struct SkeletonAudioFileRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.xxs) {
            SkeletonView(height: 18, cornerRadius: 4)
                .frame(maxWidth: 200)

            HStack(spacing: MemoraSpacing.xs) {
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(maxWidth: 70)
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(maxWidth: 120)
            }

            HStack(spacing: MemoraSpacing.xxs) {
                SkeletonView(height: 14, cornerRadius: 7)
                    .frame(maxWidth: 60)
                SkeletonView(height: 14, cornerRadius: 7)
                    .frame(maxWidth: 48)
            }
        }
        .padding(.vertical, MemoraSpacing.xxxs)
        .accessibilityHidden(true)
    }
}

#Preview {
    List {
        SkeletonAudioFileRow()
        SkeletonAudioFileRow()
        SkeletonAudioFileRow()
    }
}
