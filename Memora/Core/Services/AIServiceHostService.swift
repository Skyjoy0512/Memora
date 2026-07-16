import Foundation

/// APIキーと具体プロバイダーをホスト側に閉じ込める互換アダプタ。
/// 共有するAIServiceは構成済みLLMProviderのみを扱う。
final class AIServiceHostService: AIServiceProtocol {
    private let core = AIService()
    private var provider: AIProvider = .openai
    private var llmProvider: (any LLMProvider)?

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    func configure(apiKey: String) async throws {
        let provider = try AIServiceProviderFactory.make(apiKey: apiKey, provider: provider)
        llmProvider = provider
        core.setLLMProvider(provider)
    }

    func transcribeRemote(audioURL: URL) async throws -> String {
        guard let provider = provider.transcriptionProvider else {
            throw AIError.transcriptionNotSupported
        }

        switch provider {
        case .openai:
            guard let service = llmProvider as? OpenAIService else { throw AIError.notConfigured }
            return try await service.transcribe(audioURL: audioURL)
        case .gemini:
            guard let service = llmProvider as? GeminiService else { throw AIError.notConfigured }
            return try await service.transcribe(audioURL: audioURL)
        case .deepseek, .local:
            throw AIError.transcriptionNotSupported
        }
    }

    func summarize(transcript: String) async throws -> (title: String?, summary: String, keyPoints: [String], actionItems: [String]) {
        try await core.summarize(transcript: transcript)
    }

    func generate(_ prompt: String) async throws -> String {
        try await core.generate(prompt)
    }
}
