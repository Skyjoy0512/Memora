import SwiftUI

/// AudioFileRow のスケルトンプレースホルダー。
/// 初期ロード中にリスト表示として使用する。
struct SkeletonAudioFileRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SkeletonView(height: 16, cornerRadius: 4)
                .frame(maxWidth: 180)

            HStack(spacing: 8) {
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(maxWidth: 80)
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(maxWidth: 140)
            }
        }
        .padding(.vertical, 4)
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
