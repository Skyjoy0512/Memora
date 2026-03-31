import Foundation

// MARK: - LLM Provider Protocol

/// 全 LLM プロバイダーが準拠する共通プロトコル。
/// 文字起こし（transcription）は含まず、要約・チャット等のテキスト生成のみを扱う。
protocol LLMProviderProtocol: Sendable {
    var provider: AIProvider { get }
    var defaultModel: String { get }

    func summarize(
        transcript: String,
        prompt: String,
        model: String?
    ) async throws -> LLMResponse

    func chat(
        messages: [ChatMessage],
        model: String?
    ) async throws -> String
}

// MARK: - Data Types

struct LLMResponse: Sendable {
    let rawText: String
    let summary: String?
    let keyPoints: [String]
    let actionItems: [String]
    let decisions: [String]
}

// MARK: - LLM Router

/// ユーザー設定に基づいて適切な LLMProvider を選択・管理する。
@MainActor
final class LLMRouter: ObservableObject {
    static let shared = LLMRouter()

    @Published private(set) var currentProvider: AIProvider = .openai
    @Published private(set) var currentModel: String? = nil

    private var providers: [AIProvider: LLMProviderProtocol] = [:]
    private var apiKeys: [AIProvider: String] = [:]

    // MARK: - Configuration

    func setProvider(_ provider: AIProvider) {
        currentProvider = provider
        rebuildProviderIfNeeded()
    }

    func setAPIKey(_ apiKey: String, for provider: AIProvider) {
        apiKeys[provider] = apiKey
        rebuildProviderIfNeeded()
    }

    func setModel(_ model: String?) {
        currentModel = model
    }

    // MARK: - Provider Access

    var activeProvider: LLMProviderProtocol? {
        providers[currentProvider]
    }

    var isConfigured: Bool {
        guard let key = apiKeys[currentProvider], !key.isEmpty else {
            return false
        }
        return providers[currentProvider] != nil
    }

    // MARK: - Summarization Convenience

    func summarize(
        transcript: String,
        includeSpeakers: Bool = false,
        segments: [SpeakerSegment] = []
    ) async throws -> LLMResponse {
        guard let provider = activeProvider else {
            throw AIError.notConfigured
        }

        let prompt = buildSummarizationPrompt(
            transcript: transcript,
            includeSpeakers: includeSpeakers,
            segments: segments
        )

        return try await provider.summarize(
            transcript: transcript,
            prompt: prompt,
            model: currentModel
        )
    }

    func chat(messages: [ChatMessage]) async throws -> String {
        guard let provider = activeProvider else {
            throw AIError.notConfigured
        }
        return try await provider.chat(messages: messages, model: currentModel)
    }

    // MARK: - Private

    private func rebuildProviderIfNeeded() {
        guard let apiKey = apiKeys[currentProvider], !apiKey.isEmpty else { return }

        switch currentProvider {
        case .openai:
            providers[.openai] = OpenAIProvider(apiKey: apiKey)
        case .gemini:
            providers[.gemini] = GeminiProvider(apiKey: apiKey)
        case .deepseek:
            providers[.deepseek] = DeepSeekProvider(apiKey: apiKey)
        }
    }

    private func buildSummarizationPrompt(
        transcript: String,
        includeSpeakers: Bool,
        segments: [SpeakerSegment]
    ) -> String {
        var transcriptText = transcript

        if includeSpeakers && !segments.isEmpty {
            transcriptText = segments.map { seg in
                let speaker = seg.speakerLabel.isEmpty ? "不明" : seg.speakerLabel
                let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? "" : "[\(speaker)] \(text)"
            }.filter { !$0.isEmpty }.joined(separator: "\n")
        }

        return """
        以下の会議 transcript から、要約、重要ポイント、アクションアイテム、決定事項を抽出してください。
        出力は以下のJSON形式で返してください（マークダウンコードブロックは使わず、素のJSONのみ）：

        {
          "summary": "会議の要約（3〜5文程度）",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"],
          "decisions": ["決定事項1"]
        }

        Transcript:
        \(transcriptText)
        """
    }
}
