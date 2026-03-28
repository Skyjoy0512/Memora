import SwiftUI

struct SummaryView: View {
    let result: SummaryResult
    @State private var showCopiedToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MemoraSpacing.lg) {
                // 要約本文
                summaryCard(
                    title: "要約",
                    icon: "doc.text",
                    content: result.summary
                )

                // 重要ポイント
                if !result.keyPoints.isEmpty {
                    keyPointsCard
                }

                // 決定事項
                if let decisions = result.decisions, !decisions.isEmpty {
                    decisionsCard(decisions)
                }

                // アクションアイテム
                if !result.actionItems.isEmpty {
                    actionItemsCard
                }

                Spacer()
                    .frame(height: MemoraSpacing.xxxl)
            }
            .padding(MemoraSpacing.md)
        }
        .navigationTitle("要約")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    copyAll()
                    showCopiedToast = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        .overlay {
            if showCopiedToast {
                ToastOverlay(
                    icon: "checkmark.circle.fill",
                    message: "コピーしました",
                    style: .success,
                    onDismiss: { showCopiedToast = false }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showCopiedToast)
            }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label(title, systemImage: icon)
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            Text(content)
                .font(MemoraTypography.body)
                .foregroundStyle(.primary)
                .lineSpacing(6)
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Key Points Card

    private var keyPointsCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("重要ポイント", systemImage: "star")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(result.keyPoints.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Text("\(index + 1).")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentBlue)
                        .frame(width: 20, alignment: .trailing)

                    Text(result.keyPoints[index])
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Decisions Card

    private func decisionsCard(_ decisions: [String]) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("決定事項", systemImage: "checkmark.seal")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(decisions.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Image(systemName: "checkmark")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text(decisions[index])
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Action Items Card

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("アクションアイテム", systemImage: "checklist")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(result.actionItems.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Image(systemName: "circle")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text(result.actionItems[index])
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .cornerRadius(MemoraRadius.md)
    }

    // MARK: - Helpers

    private func copyAll() {
        var text = "## 要約\n\(result.summary)\n\n"

        if !result.keyPoints.isEmpty {
            text += "## 重要ポイント\n"
            for (i, point) in result.keyPoints.enumerated() {
                text += "\(i + 1). \(point)\n"
            }
            text += "\n"
        }

        if let decisions = result.decisions, !decisions.isEmpty {
            text += "## 決定事項\n"
            for decision in decisions {
                text += "- \(decision)\n"
            }
            text += "\n"
        }

        if !result.actionItems.isEmpty {
            text += "## アクションアイテム\n"
            for item in result.actionItems {
                text += "- \(item)\n"
            }
        }

        UIPasteboard.general.string = text
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
                ],
                decisions: [
                    "次回リリースは5月中旬",
                    "文字起こしはローカル優先で実装"
                ]
            )
        )
    }
}
