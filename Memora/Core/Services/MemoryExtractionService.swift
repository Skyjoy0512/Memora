import Foundation

struct MemoryCandidateDraft {
    let key: String
    let value: String
    let confidence: Double
    let source: String
}

@MainActor
final class MemoryExtractionService {

    private var aiService: AIService?

    func configure(apiKey: String, provider: AIProvider) async throws {
        let service = AIService()
        service.setProvider(provider)
        try await service.configure(apiKey: apiKey)
        self.aiService = service
    }

    /// transcript + summary から記憶候補を抽出する。
    /// AI が返す keyPoints を "カテゴリ: 内容" 形式でパースし、MemoryCandidateDraft 配列に変換する。
    func extractCandidates(
        transcript: String,
        summary: String?
    ) async throws -> [MemoryCandidateDraft] {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        let combinedText = buildInputText(transcript: transcript, summary: summary)
        guard !combinedText.isEmpty else { return [] }

        let (_, keyPoints, _) = try await service.summarize(transcript: combinedText)

        let sourceTag = summary != nil ? "auto:summary" : "auto:transcription"

        return keyPoints.compactMap { point in
            parseKeyColonValue(point, source: sourceTag)
        }
    }

    // MARK: - Private

    private func buildInputText(transcript: String, summary: String?) -> String {
        var parts: [String] = []

        parts.append("""
        以下の会議内容から、ユーザーに関する記憶すべき事実を抽出してください。
        カテゴリ: 好み・役割・スケジュール・人間関係・用語・継続タスク
        各事実を "カテゴリ: 内容" 形式で keyPoints に出力してください。
        一般的な内容ではなく、ユーザー個人に関連する事実のみを抽出してください。
        """)

        if let summary, !summary.isEmpty {
            parts.append("要約:\n\(summary)")
        }

        let transcriptExcerpt = String(transcript.prefix(4000))
        parts.append("文字起こし:\n\(transcriptExcerpt)")

        return parts.joined(separator: "\n\n")
    }

    /// "好み: 日本語で要約を好む" → MemoryCandidateDraft(key: "好み", value: "日本語で要約を好む", ...)
    private func parseKeyColonValue(_ raw: String, source: String) -> MemoryCandidateDraft? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colonRange = trimmed.range(of: ":", options: [], range: trimmed.startIndex..<trimmed.endIndex) else {
            return nil
        }

        let key = String(trimmed[trimmed.startIndex..<colonRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let value = String(trimmed[colonRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)

        guard !key.isEmpty, !value.isEmpty else { return nil }

        return MemoryCandidateDraft(
            key: key,
            value: value,
            confidence: 0.6,
            source: source
        )
    }
}
