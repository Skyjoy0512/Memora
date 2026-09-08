import Foundation
import SwiftData
import Testing
@testable import MemoraRN
internal import MemoraNative
import MemoraSharedCore
import MemoraSharedSchema

/// Ask AI が要約 API（summarize）ではなく回答生成 API（generate）を呼ぶことを検証する。
private struct FixedAskAIKeyReader: MemoraRNSummaryKeyReading {
  func apiKey(for provider: MemoraRNSummaryProvider) throws -> String? {
    "native-only-test-key"
  }
}

/// generate / summarize のどちらが呼ばれたかを記録するプロバイダー。
private actor AnswerPathTracker {
  private(set) var generateCount = 0
  private(set) var summarizeCount = 0

  func recordGenerate() {
    generateCount += 1
  }

  func recordSummarize() {
    summarizeCount += 1
  }
}

private struct RecordingAnswerProvider: LLMProvider {
  let displayName = "Test"
  let answer: String
  let tracker: AnswerPathTracker

  func generate(_ prompt: String) async throws -> String {
    await tracker.recordGenerate()
    return answer
  }

  func summarize(transcript: String) async throws -> LLMProviderSummary {
    // 誤って要約経路が使われた場合、回答本文が一致せず呼び出し記録でも検出できるようにする。
    await tracker.recordSummarize()
    return LLMProviderSummary(title: "要約", summary: "要約経路の回答", keyPoints: [], actionItems: [])
  }
}

@Suite("RN Ask AI answer path")
struct MemoraKnowledgeQueryAnswerPathTests {
  @Test("Ask AIは会議要約API(summarize)でなく回答生成API(generate)を使い、会話を保存する")
  @MainActor
  func askAIUsesGenerateNotSummarize() async throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-rn-askai-answer-path-\(UUID().uuidString).store")
    defer { try? FileManager.default.removeItem(at: storeURL) }

    let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
    let tracker = AnswerPathTracker()
    let query = MemoraSharedStoreKnowledgeQuery(
      container: container,
      keyReader: FixedAskAIKeyReader(),
      providerFactory: { _, _ in RecordingAnswerProvider(answer: "生成経路の回答", tracker: tracker) }
    )

    let response = try await query.queryKnowledge(MemoraKnowledgeQueryRequestDTO(dictionary: [
      "scope": "global",
      "question": "直近の進捗を教えてください。"
    ]))

    #expect(response.answer == "生成経路の回答")
    #expect(await tracker.generateCount == 1)
    #expect(await tracker.summarizeCount == 0)

    // 会話（質問＋回答）が SwiftData へ保存される（R15 のセッション追記契約を保持）。
    let context = ModelContext(container)
    let sessionID = try #require(UUID(uuidString: response.sessionId))
    let messages = try context.fetch(FetchDescriptor<AskAIMessage>(
      predicate: #Predicate { $0.sessionID == sessionID }
    ))
    #expect(messages.count == 2)
    #expect(messages.contains { $0.role == .user && $0.content == "直近の進捗を教えてください。" })
    #expect(messages.contains { $0.role == .assistant && $0.content == "生成経路の回答" })
  }
}
