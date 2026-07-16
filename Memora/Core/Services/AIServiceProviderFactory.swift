import Foundation

/// APIキーを受け取って具体的な LLMProvider を構成するホスト側ファクトリ。
/// 共有する要約コアには、ここで構成済みの provider だけを注入する。
enum AIServiceProviderFactory {
    static func make(apiKey: String, provider: AIProvider) throws -> any LLMProvider {
        switch provider {
        case .local:
            if Gemma4ExperimentalProvider.isReady {
                return Gemma4ExperimentalProvider()
            }
            guard LocalLLMProvider.isAvailable else {
                throw AIError.notConfigured
            }
            return LocalLLMProvider()
        case .openai:
            return OpenAIService(apiKey: apiKey)
        case .gemini:
            return GeminiService(apiKey: apiKey)
        case .deepseek:
            return DeepSeekService(apiKey: apiKey)
        }
    }
}
