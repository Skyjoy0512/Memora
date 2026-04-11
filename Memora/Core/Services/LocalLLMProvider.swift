import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Local LLM Provider

/// iOS Foundation Models framework を使ったオンデバイス LLM プロバイダー。
/// 利用不可の環境では `notAvailable` を投げる。
///
/// C3 で本格実装予定。現在は iOS 26 Foundation Models の基本パスのみ。
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

    var isAvailable: Bool {
        get async {
            Self.isAvailable
        }
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

    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String {
        // C3 で Foundation Models のストリーミング API に対応予定
        // 現在は protocol extension のデフォルト実装（generate → onChunk）を使用
        return try await generate(prompt)
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
