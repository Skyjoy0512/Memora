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

// MARK: - KnowledgeIndexing Static Method Tests (CO-02 Smoke Tests)

struct KnowledgeIndexingStaticTests {

    // MARK: - chunkText

    @Test("chunkText は空文字で空配列を返す")
    func chunkTextEmpty() {
        let chunks = KnowledgeIndexingService.chunkText("")
        #expect(chunks.isEmpty)
    }

    @Test("chunkText は短い文字列を1要素で返す")
    func chunkTextShortString() {
        let text = "短いテスト文です。"
        let chunks = KnowledgeIndexingService.chunkText(text, targetLength: 220, hardLimit: 320)
        #expect(chunks.count == 1)
        #expect(chunks[0].contains("短いテスト文"))
    }

    @Test("chunkText は長い文字列を複数要素に分割し hardLimit を超えない")
    func chunkTextLongStringRespectsHardLimit() {
        let text = Array(repeating: "これはテストセンテンス。", count: 50).joined()
        let hardLimit = 100

        let chunks = KnowledgeIndexingService.chunkText(text, targetLength: 60, hardLimit: hardLimit)

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= hardLimit })
    }

    @Test("chunkText は改行区切りのテキストを分割する")
    func chunkTextNewlineSeparated() {
        let lines = (1...10).map { "項目\($0)の内容について説明します。" }
        let text = lines.joined(separator: "\n")

        let chunks = KnowledgeIndexingService.chunkText(text, targetLength: 40, hardLimit: 80)

        #expect(chunks.count >= 2)
        #expect(chunks.allSatisfy { !$0.isEmpty })
    }

    // MARK: - extractKeywords

    @Test("extractKeywords は空文字で空配列を返す")
    func extractKeywordsEmpty() {
        let keywords = KnowledgeIndexingService.extractKeywords(from: "")
        #expect(keywords.isEmpty)
    }

    @Test("extractKeywords は英語キーワードを抽出する")
    func extractKeywordsEnglish() {
        let keywords = KnowledgeIndexingService.extractKeywords(from: "API migration plan for next quarter")

        #expect(keywords.contains("api"))
        #expect(keywords.contains("migration"))
        #expect(keywords.contains("plan"))
        #expect(keywords.contains("quarter"))
    }

    @Test("extractKeywords は日本語文字列を含むキーワードを抽出する")
    func extractKeywordsJapanese() {
        let keywords = KnowledgeIndexingService.extractKeywords(from: "プロジェクトの予算承認について議論")

        // 正規表現は連続する日本語文字を1トークンとして抽出する
        #expect(!keywords.isEmpty)
        #expect(keywords.allSatisfy { $0.count >= 2 })
    }

    @Test("extractKeywords は limit パラメータを尊重する")
    func extractKeywordsLimit() {
        let text = "apple banana cherry date elderberry fig grape honey"
        let keywords = KnowledgeIndexingService.extractKeywords(from: text, limit: 3)

        #expect(keywords.count == 3)
    }

    @Test("extractKeywords はストップワードを除外する")
    func extractKeywordsStopWords() {
        let keywords = KnowledgeIndexingService.extractKeywords(from: "the for with database query optimization")

        #expect(!keywords.contains("the"))
        #expect(!keywords.contains("for"))
        #expect(!keywords.contains("with"))
        #expect(keywords.contains("database"))
    }

    // MARK: - normalizedIndexableText

    @Test("normalizedIndexableText は nil を返す")
    func normalizedNil() {
        #expect(KnowledgeIndexingService.normalizedIndexableText(nil) == nil)
    }

    @Test("normalizedIndexableText は空文字を nil として返す")
    func normalizedEmpty() {
        #expect(KnowledgeIndexingService.normalizedIndexableText("") == nil)
        #expect(KnowledgeIndexingService.normalizedIndexableText("   ") == nil)
    }

    @Test("normalizedIndexableText は正常テキストをトリムして返す")
    func normalizedNormal() {
        let result = KnowledgeIndexingService.normalizedIndexableText("  hello world  ")
        #expect(result == "hello world")
    }

    @Test("normalizedIndexableText は連続空白を正規化する")
    func normalizedWhitespace() {
        let result = KnowledgeIndexingService.normalizedIndexableText("a  \t  b  \t  c")
        #expect(result == "a b c")
    }

    @Test("normalizedIndexableText は連続改行を正規化する")
    func normalizedNewlines() {
        let result = KnowledgeIndexingService.normalizedIndexableText("line1\n\n\n\nline2")
        #expect(result == "line1\n\nline2")
    }
}
