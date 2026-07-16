import Testing
@testable import MemoraSharedSummary
import MemoraSharedCore

private struct SummaryProviderStub: LLMProvider {
    let displayName = "Test"

    func generate(_ prompt: String) async throws -> String {
        ""
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        LLMProviderSummary(
            title: "注入済みプロバイダー",
            summary: "要約結果",
            keyPoints: ["要点"],
            actionItems: ["対応"]
        )
    }
}

@Suite("MemoraSharedSummary")
struct SummarizationEngineTests {
    @Test("構成済みLLMProviderだけで要約できる")
    func summarizeWithInjectedProvider() async throws {
        let engine = SummarizationEngine()
        engine.configure(provider: SummaryProviderStub())

        let result = try await engine.summarize(transcript: "文字起こし")

        #expect(result.suggestedTitle == "注入済みプロバイダー")
        #expect(result.summary == "要約結果")
        #expect(result.keyPoints == ["要点"])
        #expect(result.actionItems == ["対応"])
    }

    @Test("要約結果の保存用テキストを生成できる")
    func summaryResultStorageText() {
        let result = SummaryResult(
            summary: "要約",
            keyPoints: ["要点A", "要点B"],
            actionItems: ["対応A", "対応B"],
            decisions: ["決定A"]
        )

        #expect(result.keyPointsText == "要点A\n要点B")
        #expect(result.actionItemsText == "対応A\n対応B")
        #expect(result.decisionsText == "決定A")
    }
}
