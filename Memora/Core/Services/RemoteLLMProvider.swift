import Foundation

// MARK: - Remote LLM Provider

/// AIService の既存リモートプロバイダー（OpenAI / Gemini / DeepSeek）を
/// LLMProvider protocol に適合させるラッパー。
/// AIService 本体は変更せず、外部から LLMProvider として扱うためのアダプター。
final class RemoteLLMProvider: LLMProvider {
    let displayName: String
    private let kind: LLMProviderKind
    private let underlyingProvider: any LLMProvider

    var isAvailable: Bool {
        get async {
            // リモートプロバイダーは API キー設定済みなら利用可能
            // 実際の可用性チェックは underlyingProvider に委譲
            await underlyingProvider.isAvailable
        }
    }

    init(kind: LLMProviderKind, provider: any LLMProvider) {
        self.kind = kind
        self.underlyingProvider = provider
        self.displayName = provider.displayName
    }

    /// 利便性イニシャライザ: OpenAIService 用
    convenience init(openAIService: OpenAIService) {
        self.init(kind: .openai, provider: openAIService)
    }

    /// 利便性イニシャライザ: GeminiService 用
    convenience init(geminiService: GeminiService) {
        self.init(kind: .gemini, provider: geminiService)
    }

    /// 利便性イニシャライタ: DeepSeekService 用
    convenience init(deepSeekService: DeepSeekService) {
        self.init(kind: .deepseek, provider: deepSeekService)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        try await underlyingProvider.generate(prompt)
    }

    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String {
        // リモートプロバイダーはデフォルト実装（非ストリーミング）にフォールバック
        // 将来 OpenAI SSE ストリーミングを実装する場合はここを拡張
        try await underlyingProvider.generateStream(prompt: prompt, onChunk: onChunk)
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        try await underlyingProvider.summarize(transcript: transcript)
    }
}
