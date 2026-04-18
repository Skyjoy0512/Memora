import SwiftUI

// MARK: - Usage Instructions Section

struct UsageInstructionsSection: View {
    var body: some View {
        Section {
            Text("文字起こし・要約の流れ：")
                .font(MemoraTypography.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Files タブでファイルを選択")
                    .font(MemoraTypography.subheadline)

                Text("   → 録音画面を開く")
                    .font(MemoraTypography.caption1)

                Text("2. 詳細画面で「文字起こし」をタップ")
                    .font(MemoraTypography.caption1)

                Text("3. 詳細画面で「要約」をタップ")
                    .font(MemoraTypography.caption1)
            }
        } header: {
            GlassSectionHeader(title: "使用方法", icon: "questionmark.circle")
        }
    }
}
