import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case openai = "OpenAI", gemini = "Gemini", deepseek = "DeepSeek", local = "Local"
    public var id: String { rawValue }
    public var supportsTranscription: Bool { self == .openai || self == .gemini }
    public var transcriptionProvider: AIProvider? { supportsTranscription ? self : nil }
    public var requiresAPIKey: Bool { self != .local }
}

public enum TranscriptionMode: String, CaseIterable, Identifiable, Sendable {
    case local = "ローカル", api = "API"
    public var id: String { rawValue }
}

public enum AIError: LocalizedError, Sendable {
    case notConfigured, transcriptionNotSupported, apiKeyMissing, invalidResponse, decodingError, apiError(Int, String)
    public var errorDescription: String? { switch self {
    case .notConfigured: return "AIサービスが設定されていません"
    case .transcriptionNotSupported: return "選択されたプロバイダーは文字起こしをサポートしていません"
    case .apiKeyMissing: return "APIキーが設定されていません"
    case .invalidResponse: return "無効なレスポンスです"
    case .decodingError: return "レスポンスの解析に失敗しました"
    case let .apiError(code, message): return "APIエラー (\(code)): \(message)" }
    }
}

public enum OpenAIError: LocalizedError, Sendable {
    case invalidResponse, decodingError, apiError(Int, String)
    public var errorDescription: String? { switch self {
    case .invalidResponse: return "無効なレスポンスです"
    case .decodingError: return "レスポンスの解析に失敗しました"
    case let .apiError(code, message): return "APIエラー (\(code)): \(message)" }
    }
}

public struct STTExecutionConfiguration: Sendable {
    public let apiKey: String; public let provider: AIProvider; public let transcriptionMode: TranscriptionMode; public let allowsSpeechAnalyzer: Bool
    public init(apiKey: String, provider: AIProvider, transcriptionMode: TranscriptionMode, allowsSpeechAnalyzer: Bool) { self.apiKey = apiKey; self.provider = provider; self.transcriptionMode = transcriptionMode; self.allowsSpeechAnalyzer = allowsSpeechAnalyzer }
    public static let localDefault = STTExecutionConfiguration(apiKey: "", provider: .openai, transcriptionMode: .local, allowsSpeechAnalyzer: true)
    public func withSpeechAnalyzerAllowed(_ isAllowed: Bool) -> STTExecutionConfiguration { STTExecutionConfiguration(apiKey: apiKey, provider: provider, transcriptionMode: transcriptionMode, allowsSpeechAnalyzer: isAllowed) }
}

public enum STTErrorMapper {
    public static func mapToCoreError(_ error: Error) -> CoreError {
        if let error = error as? CoreError { return error }
        if let error = error as? TranscriptionError { return .transcriptionError(error) }
        if let error = error as? AudioChunkerError { return .pipelineError(.transcriptionFailed(error.localizedDescription)) }
        if let error = error as? AIError { return .transcriptionError(.transcriptionFailed(error.localizedDescription)) }
        if let error = error as? OpenAIError { return .transcriptionError(.transcriptionFailed(error.localizedDescription)) }
        if let error = error as? OnDeviceTranscriptionTimeoutError { return .transcriptionError(.transcriptionFailed(error.localizedDescription)) }
        return .transcriptionError(.transcriptionFailed(error.localizedDescription))
    }
}
