import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - LLM Provider Protocol

/// LLM プロバイダーの共通契約。
/// OpenAI / Gemini / DeepSeek / Local を同じインターフェースで扱う。
protocol LLMProvider: Sendable {
    /// プロバイダー名（UI 表示用）
    var displayName: String { get }

    /// テキスト生成（要約・AskAI などで使用）
    /// - Parameter prompt: プロンプト全文
    /// - Returns: 生成されたテキスト
    func generate(_ prompt: String) async throws -> String

    /// テキスト生成（構造化出力・要約用）
    /// - Parameter transcript: 文字起こしテキスト
    /// - Returns: 要約・キーポイント・アクションアイテム
    func summarize(transcript: String) async throws -> LLMProviderSummary
}

/// 要約結果の共通モデル
struct LLMProviderSummary: Sendable {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}

// MARK: - Provider Registry

/// 利用可能な LLM プロバイダーを管理するレジストリ。
enum LLMProviderKind: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case deepseek = "DeepSeek"
    case local = "Local"

    var id: String { rawValue }

    var supportsTranscription: Bool {
        switch self {
        case .openai: return true
        case .gemini: return false
        case .deepseek: return false
        case .local: return false
        }
    }
}

// MARK: - Local LLM Provider

/// iOS 26 Foundation Models framework を使ったオンデバイス LLM プロバイダー。
/// 利用不可の環境では `notAvailable` を投げる。
final class LocalLLMProvider: LLMProvider {
    let displayName = "Local (On-Device)"

    /// Foundation Models が利用可能か
    static var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            return true
            #else
            return false
            #endif
        }
        return false
    }

    func generate(_ prompt: String) async throws -> String {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession(
                instructions: "あなたは Memora の AI アシスタントです。必ず日本語で簡潔に答えてください。"
            )
            let response = try await session.respond(to: prompt)
            return response.content
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession(
                instructions: """
                あなたは会議の文字起こしから要約を作成するアシスタントです。
                以下のフォーマットで出力してください:
                [要約]
                会議の要約文

                [重要ポイント]
                ・ポイント1
                ・ポイント2

                [アクションアイテム]
                ・アイテム1
                ・アイテム2
                """
            )
            let prompt = "以下の文字起こしから要約を作成してください:\n\n\(transcript)"
            let response = try await session.respond(to: prompt)
            return Self.parseSummaryResponse(response.content)
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    /// レスポンステキストから要約・キーポイント・アクションアイテムを抽出
    private static func parseSummaryResponse(_ text: String) -> LLMProviderSummary {
        let sections = text.components(separatedBy: "\n")
        var currentSection = ""
        var summaryLines: [String] = []
        var keyPoints: [String] = []
        var actionItems: [String] = []

        for line in sections {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("[要約]") || trimmed.contains("## 要約") {
                currentSection = "summary"
                continue
            } else if trimmed.contains("[重要ポイント]") || trimmed.contains("## 重要ポイント") || trimmed.contains("キーポイント") {
                currentSection = "keyPoints"
                continue
            } else if trimmed.contains("[アクションアイテム]") || trimmed.contains("## アクション") {
                currentSection = "actionItems"
                continue
            }

            let content = trimmed
                .replacingOccurrences(of: "^[•\\-・*]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard !content.isEmpty else { continue }

            switch currentSection {
            case "summary":
                summaryLines.append(content)
            case "keyPoints":
                keyPoints.append(content)
            case "actionItems":
                actionItems.append(content)
            default:
                break
            }
        }

        if summaryLines.isEmpty, keyPoints.isEmpty, actionItems.isEmpty {
            summaryLines = [text.prefix(500).description]
        }

        return LLMProviderSummary(
            summary: summaryLines.joined(separator: "\n"),
            keyPoints: keyPoints,
            actionItems: actionItems
        )
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
        }
    }
}
