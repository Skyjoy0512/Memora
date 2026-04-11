import Foundation

// MARK: - LLM Provider Protocol

/// LLM 呼び出しの抽象化。remote / local 両対応。
/// OpenAI / Gemini / DeepSeek / Local を同じインターフェースで扱う。
protocol LLMProvider: Sendable {
    /// プロバイダーが現在利用可能か
    var isAvailable: Bool { get async }

    /// プロバイダー名（UI 表示用）
    var displayName: String { get }

    /// 同期生成（全テキストを一度に返す）
    /// - Parameter prompt: プロンプト全文
    /// - Returns: 生成されたテキスト
    func generate(_ prompt: String) async throws -> String

    /// ストリーミング生成（チャンクごとにコールバック）
    /// - Parameters:
    ///   - prompt: プロンプト全文
    ///   - onChunk: チャンク受信時のコールバック
    /// - Returns: 最終的な全テキスト
    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String

    /// テキスト生成（構造化出力・要約用）
    /// - Parameter transcript: 文字起こしテキスト
    /// - Returns: 要約・キーポイント・アクションアイテム
    func summarize(transcript: String) async throws -> LLMProviderSummary
}

// MARK: - Default Implementations

extension LLMProvider {
    /// デフォルト実装: ストリーミング非対応の場合は generate にフォールバック
    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String {
        let result = try await generate(prompt)
        onChunk(result)
        return result
    }

    /// デフォルト実装: isAvailable は true
    var isAvailable: Bool { true }
}

// MARK: - Summary Model

/// 要約結果の共通モデル
struct LLMProviderSummary: Sendable {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}

// MARK: - Provider Kind

/// プロバイダー種別
enum LLMProviderKind: String, Codable, CaseIterable, Identifiable {
    case openai = "openai"
    case gemini = "gemini"
    case deepseek = "deepseek"
    case local = "local"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .deepseek: return "DeepSeek"
        case .local: return "Local"
        }
    }

    var supportsTranscription: Bool {
        switch self {
        case .openai: return true
        case .gemini: return false
        case .deepseek: return false
        case .local: return false
        }
    }
}

// MARK: - Errors

enum LLMProviderError: LocalizedError {
    case notAvailable
    case notConfigured
    case apiKeyMissing
    case invalidResponse
    case decodingError
    case apiError(Int, String)
    case streamingNotSupported

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "このプロバイダーは現在利用できません"
        case .notConfigured:
            return "プロバイダーが設定されていません"
        case .apiKeyMissing:
            return "APIキーが設定されていません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .decodingError:
            return "レスポンスの解析に失敗しました"
        case .apiError(let code, let message):
            return "APIエラー (\(code)): \(message)"
        case .streamingNotSupported:
            return "このプロバイダーはストリーミングをサポートしていません"
        }
    }
}
