import SwiftUI

struct SummaryView: View {
    let result: SummaryResult
    @State private var showCopiedToast = false

    var body: some View {
        ScrollView {
            SummaryContentView(result: result)
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
                .transition(MemoraTransition.slideUp)
                .animation(.easeInOut(duration: MemoraAnimation.standardDuration), value: showCopiedToast)
            }
        }
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

struct SummaryContentView: View {
    let result: SummaryResult

    var body: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.lg) {
            SummarySnapshotCard(result: result)

            summaryCard(
                title: "要約",
                icon: "doc.text",
                content: result.summary
            )

            if !result.keyPoints.isEmpty {
                keyPointsCard
            }

            if let decisions = result.decisions, !decisions.isEmpty {
                decisionsCard(decisions)
            }

            if !result.actionItems.isEmpty {
                actionItemsCard
            }

            Spacer()
                .frame(height: MemoraSpacing.xxxl)
        }
    }

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
        .clipShape(.rect(cornerRadius: MemoraRadius.md))
    }

    private var keyPointsCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("重要ポイント", systemImage: "star")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Text("\(index + 1).")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentBlue)
                        .frame(width: 20, alignment: .trailing)

                    Text(point)
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .clipShape(.rect(cornerRadius: MemoraRadius.md))
    }

    private func decisionsCard(_ decisions: [String]) -> some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("決定事項", systemImage: "checkmark.seal")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Image(systemName: "checkmark")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentGreen)

                    Text(decision)
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .clipShape(.rect(cornerRadius: MemoraRadius.md))
    }

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
            Label("アクションアイテム", systemImage: "checklist")
                .font(MemoraTypography.headline)
                .foregroundStyle(MemoraColor.textPrimary)

            ForEach(Array(result.actionItems.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: MemoraSpacing.sm) {
                    Image(systemName: "circle")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)

                    Text(item)
                        .font(MemoraTypography.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(MemoraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MemoraColor.divider.opacity(0.05))
        .clipShape(.rect(cornerRadius: MemoraRadius.md))
    }
}

struct SummarySnapshotCard: View {
    let result: SummaryResult

    private var title: String {
        result.suggestedTitle?.isEmpty == false ? result.suggestedTitle! : "要約ダッシュボード"
    }

    private var subtitle: String {
        result.summary
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "会議内容の概要と次のアクション"
    }

    private var primaryMetric: String {
        let total = result.keyPoints.count + result.actionItems.count + (result.decisions?.count ?? 0)
        return "\(max(total, 1))"
    }

    private var primaryMetricLabel: String {
        "抽出項目"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                roadmapPanel
                impactPanel
                decisionsPanel
                keyPointsPanel
            }

            actionItemsPanel
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.965, green: 0.98, blue: 0.99))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                tag("AI Summary")
                tag("Action Map")
            }

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.62))
                .lineLimit(2)
        }
    }

    private var roadmapPanel: some View {
        snapshotPanel(background: Color(red: 0.91, green: 0.965, blue: 0.985)) {
            Label("要点ロードマップ", systemImage: "calendar")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.keyPoints.prefix(3).enumerated()), id: \.offset) { index, point in
                    timelineItem(
                        title: index == 0 ? "現在の焦点" : "確認事項 \(index + 1)",
                        body: point,
                        isCurrent: index == 0
                    )
                }

                if result.keyPoints.isEmpty {
                    timelineItem(title: "概要", body: result.summary, isCurrent: true)
                }
            }
        }
    }

    private var impactPanel: some View {
        snapshotPanel(background: Color(red: 0.79, green: 0.89, blue: 0.94)) {
            Text("進行インパクト")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 0) {
                Text(primaryMetric)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.black)
                Text(primaryMetricLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("次に動かす項目")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.55))
                Text(result.actionItems.first ?? result.keyPoints.first ?? "要約内容を確認")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.78))
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    private var decisionsPanel: some View {
        snapshotPanel(background: Color(red: 0.94, green: 0.965, blue: 0.99)) {
            Label("決定事項", systemImage: "checkmark.seal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            let decisions = result.decisions ?? []
            ForEach(Array(decisions.prefix(2).enumerated()), id: \.offset) { _, decision in
                compactRow(badge: "OK", text: decision)
            }

            if decisions.isEmpty {
                compactRow(badge: "INFO", text: result.keyPoints.first ?? "決定事項は未抽出です")
            }
        }
    }

    private var keyPointsPanel: some View {
        snapshotPanel(background: Color(red: 0.94, green: 0.955, blue: 0.985)) {
            Label("重要ポイント", systemImage: "cube")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)

            ForEach(Array(result.keyPoints.prefix(2).enumerated()), id: \.offset) { index, point in
                compactRow(badge: index == 0 ? "MAIN" : "SUB", text: point)
            }

            if result.keyPoints.isEmpty {
                compactRow(badge: "MAIN", text: subtitle)
            }
        }
    }

    private var actionItemsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Action Items", systemImage: "checklist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("進行中")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 8
            ) {
                ForEach(Array(result.actionItems.prefix(4).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(actionBadge(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.72))
                            .frame(width: 24, height: 24)
                            .background(Color(red: 0.84, green: 0.92, blue: 0.96))
                            .clipShape(Circle())

                        Text(item)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.76))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if result.actionItems.isEmpty {
                compactRow(badge: "TODO", text: "具体的なアクションは未抽出です")
            }
        }
        .padding(12)
        .background(.white.opacity(0.68))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func snapshotPanel<Content: View>(
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func timelineItem(title: String, body: String, isCurrent: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isCurrent ? Color(red: 0.46, green: 0.7, blue: 0.8) : Color(red: 0.72, green: 0.84, blue: 0.9))
                .frame(width: 9, height: 9)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                Text(body)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.65))
                    .lineLimit(2)
            }
        }
    }

    private func compactRow(badge: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(badge)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.2, green: 0.42, blue: 0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(red: 0.84, green: 0.93, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))
                .lineLimit(3)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.62))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 0.87, green: 0.93, blue: 0.96))
            .clipShape(Capsule())
    }

    private func actionBadge(_ index: Int) -> String {
        ["田", "江", "S2", "石"][safe: index] ?? "\(index + 1)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
