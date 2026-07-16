import Foundation

public protocol LLMProvider: Sendable {
    var isAvailable: Bool { get async }
    var displayName: String { get }
    func generate(_ prompt: String) async throws -> String
    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String
    func summarize(transcript: String) async throws -> LLMProviderSummary
}

public extension LLMProvider {
    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String {
        let result = try await generate(prompt)
        onChunk(result)
        return result
    }

    var isAvailable: Bool { true }
}

public struct LLMProviderSummary: Sendable {
    public let title: String?
    public let summary: String
    public let keyPoints: [String]
    public let actionItems: [String]

    public init(title: String?, summary: String, keyPoints: [String], actionItems: [String]) {
        self.title = title
        self.summary = summary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
    }
}

public enum LLMProviderKind: String, Codable, CaseIterable, Identifiable {
    case openai = "openai"
    case gemini = "gemini"
    case deepseek = "deepseek"
    case local = "local"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        case .local: return "Local"
        }
    }

    public var supportsTranscription: Bool {
        switch self {
        case .openai: return true
        case .gemini: return true
        case .deepseek: return false
        case .local: return false
        }
    }
}

public enum LLMProviderError: LocalizedError {
    case notAvailable
    case notConfigured
    case apiKeyMissing
    case invalidResponse
    case decodingError
    case apiError(Int, String)
    case streamingNotSupported

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "このプロバイダーは現在利用できません"
        case .notConfigured: return "プロバイダーが設定されていません"
        case .apiKeyMissing: return "APIキーが設定されていません"
        case .invalidResponse: return "無効なレスポンスです"
        case .decodingError: return "レスポンスの解析に失敗しました"
        case .apiError(let code, let message): return "APIエラー (\(code)): \(message)"
        case .streamingNotSupported: return "このプロバイダーはストリーミングをサポートしていません"
        }
    }
}
