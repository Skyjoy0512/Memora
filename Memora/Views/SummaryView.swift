import SwiftUI

struct SummaryView: View {
    let result: SummaryResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 要約本文
                VStack(alignment: .leading, spacing: 12) {
                    Text("要約")
                        .font(.headline)

                    Text(result.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // 重要ポイント
                if !result.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("重要ポイント")
                            .font(.headline)

                        ForEach(result.keyPoints.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(.gray)

                                Text(result.keyPoints[index])
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }

                // アクションアイテム
                if !result.actionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("アクションアイテム")
                            .font(.headline)

                        ForEach(result.actionItems.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.gray)

                                Text(result.actionItems[index])
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .navigationTitle("要約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SummaryView(
            result: SummaryResult(
                summary: "本会議ではプロジェクトの進捗状況と今後の予定について議論しました。\n\n現在の状況として、UIの実装が80%完了しています。",
                keyPoints: [
                    "UI実装が80%完了",
                    "次は文字起こし機能の実装",
                    "音声からテキスト変換が必要"
                ],
                actionItems: [
                    "文字起こし機能の実装",
                    "音声処理ライブラリの調査",
                    "次回会議の日程調整"
                ]
            )
        )
    }
}
