import Foundation

protocol SummarizationEngineProtocol {
    var isSummarizing: Bool { get }
    var progress: Double { get }

    func summarize(transcript: String) async throws -> SummaryResult
}

struct SummaryResult {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}

final class SummarizationEngine: SummarizationEngineProtocol, ObservableObject {
    @Published var isSummarizing = false
    @Published var progress = 0.0

    func summarize(transcript: String) async throws -> SummaryResult {
        isSummarizing = true
        progress = 0

        // TODO: 実際の AI API を呼び出す
        // ここではシミュレーション

        let totalDuration: TimeInterval = 3 // 3秒のシミュレーション
        let steps = 100
        let stepDuration = totalDuration / Double(steps)

        for i in 0...steps {
            try Task.checkCancellation()
            progress = Double(i) / Double(steps)
            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }

        isSummarizing = false

        // サンプル結果
        let summary = """
        本会議ではプロジェクトの進捗状況と今後の予定について議論しました。

        現在の状況として、UIの実装が80%完了しています。次のフェーズとして文字起こし機能の実装が予定されており、音声からテキストへの変換処理が必要となります。
        """

        let keyPoints = [
            "UI実装が80%完了",
            "次は文字起こし機能の実装",
            "音声からテキスト変換が必要"
        ]

        let actionItems = [
            "文字起こし機能の実装",
            "音声処理ライブラリの調査",
            "次回会議の日程調整"
        ]

        return SummaryResult(
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems
        )
    }
}
