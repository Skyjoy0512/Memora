import Foundation

// MARK: - Protocols

protocol AIServiceProtocol {
    func summarize(transcript: String) async throws -> (title: String?, summary: String, keyPoints: [String], actionItems: [String])
    func generate(_ prompt: String) async throws -> String
}

// MARK: - Unified Service

final class AIService: AIServiceProtocol {
    private var llmProvider: (any LLMProvider)?

    /// 要約コアが利用する、ホスト側で構成済みのプロバイダーを注入する。
    func setLLMProvider(_ provider: any LLMProvider) {
        self.llmProvider = provider
    }

    func summarize(transcript: String) async throws -> (title: String?, summary: String, keyPoints: [String], actionItems: [String]) {
        // LLMProvider 経由の統一路線（外部注入された provider があればそちらを優先）
        if let llmProvider {
            let result = try await llmProvider.summarize(transcript: transcript)
            return (result.title, result.summary, result.keyPoints, result.actionItems)
        }

        // フォールバック: LLMProvider 経由で統一呼び出し
        guard let provider = llmProvider else {
            throw AIError.notConfigured
        }
        let r = try await provider.summarize(transcript: transcript)
        return (r.title, r.summary, r.keyPoints, r.actionItems)
    }

    /// LLMProvider 経由でテキスト生成（AskAI などで使用）
    func generate(_ prompt: String) async throws -> String {
        guard let llmProvider else {
            throw AIError.notConfigured
        }
        return try await llmProvider.generate(prompt)
    }
}
