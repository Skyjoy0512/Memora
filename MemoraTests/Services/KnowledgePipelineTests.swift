import Testing
import Foundation
@testable import Memora

struct KnowledgePipelineTests {

    @Test("KnowledgeIndexingService は長文を複数 chunk に分割する")
    func chunkTextSplitsLongContent() {
        let text = Array(repeating: "API移行の期限と担当を確認します。", count: 20).joined()

        let chunks = KnowledgeIndexingService.chunkText(
            text,
            targetLength: 64,
            hardLimit: 80
        )

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { !$0.isEmpty && $0.count <= 80 })
    }

    @Test("KnowledgeIndexingService は検索向けキーワードを重複なく抽出する")
    func extractKeywordsDeduplicatesTerms() {
        let keywords = KnowledgeIndexingService.extractKeywords(
            from: "API migration API 移行 移行 next-step next-step"
        )

        #expect(keywords.contains("api"))
        #expect(keywords.contains("migration"))
        #expect(keywords.contains("移行"))
        #expect(keywords.contains("next-step"))
        #expect(keywords.count == Set(keywords).count)
    }

    @Test("LocalRetrievalEngine は summary の直接一致を優先する")
    func retrievalScorePrioritizesDirectSummaryMatch() {
        let summaryChunk = KnowledgeChunk(
            scopeType: .file,
            scopeID: UUID(),
            sourceType: .summary,
            sourceID: UUID(),
            text: "API 移行は来週開始。担当は Hashimoto。",
            keywords: ["api", "移行", "hashimoto"],
            rankHint: 1.0
        )
        let transcriptChunk = KnowledgeChunk(
            scopeType: .file,
            scopeID: UUID(),
            sourceType: .transcript,
            sourceID: UUID(),
            text: "雑談のあとで次の議題へ進んだ。",
            keywords: ["雑談", "議題"],
            rankHint: 0.9
        )

        let summaryScore = LocalRetrievalEngine.score(query: "API 移行", for: summaryChunk)
        let transcriptScore = LocalRetrievalEngine.score(query: "API 移行", for: transcriptChunk)

        #expect(summaryScore.score > transcriptScore.score)
        #expect(summaryScore.matchedTerms.contains("api"))
        #expect(summaryScore.matchedTerms.contains("移行"))
    }

    @Test("空クエリでは rankHint を基準に返す")
    func retrievalScoreFallsBackToRankHintForEmptyQuery() {
        let chunk = KnowledgeChunk(
            scopeType: .global,
            scopeID: nil,
            sourceType: .memo,
            sourceID: UUID(),
            text: "次回までにレビュー",
            keywords: ["レビュー"],
            rankHint: 0.42
        )

        let result = LocalRetrievalEngine.score(query: "   ", for: chunk)

        #expect(result.score == 0.42)
        #expect(result.matchedTerms.isEmpty)
    }
}
