import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Local LLM Provider

/// iOS 26 Foundation Models framework を使ったオンデバイス LLM プロバイダー。
/// 利用不可の環境では `notAvailable` を投げる。
///
/// C3 実装完了:
/// - SystemLanguageModel.default.availability によるモデル可用性チェック
/// - streamResponse を使ったリアルストリーミング
/// - prewarm によるレイテンシ最適化
/// - バックグラウンド実行時は非ストリーミング respond を使用
final class LocalLLMProvider: LLMProvider {
    let displayName = "Local (On-Device)"

    // MARK: - Availability

    /// Foundation Models フレームワークがコンパイル時に存在するか
    static var isFrameworkAvailable: Bool {
        #if canImport(FoundationModels)
        return true
        #else
        return false
        #endif
    }

    /// Foundation Models がランタイムで利用可能か（iOS バージョン + フレームワーク存在）
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

    /// Foundation Models モデルのダウンロード・可用性状態を詳しく取得
    static var modelAvailabilityDescription: String {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            switch SystemLanguageModel.default.availability {
            case .available:
                return "オンデバイスモデルが利用可能"
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "このデバイスはオンデバイス AI をサポートしていません"
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence が有効化されていません（設定アプリで有効にしてください）"
                case .modelNotReady:
                    return "モデルのダウンロードが完了していません（設定アプリを確認してください）"
                @unknown default:
                    return "不明な理由で利用できません"
                }
            }
            #else
            return "Foundation Models フレームワークが存在しません"
            #endif
        }
        return "iOS 26 以降が必要です"
    }

    var isAvailable: Bool {
        get async {
            guard Self.isAvailable else { return false }
            if #available(iOS 26.0, *) {
                #if canImport(FoundationModels)
                // SystemLanguageModel.default.availability でモデルダウンロード状態も確認
                if case .available = SystemLanguageModel.default.availability {
                    return true
                }
                return false
                #else
                return false
                #endif
            }
            return false
        }
    }

    // MARK: - Generate (non-streaming)

    func generate(_ prompt: String) async throws -> String {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    // MARK: - Generate Stream

    func generateStream(prompt: String, onChunk: @Sendable (String) -> Void) async throws -> String {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession()
            let stream = session.streamResponse(to: Prompt(prompt))

            // ResponseStream の各 Snapshot で onChunk を呼ぶ
            // partial content が更新されるたびに UI にフィードバックされる
            var fullText = ""
            for try await partial in stream {
                let newContent = partial.content
                // 前回から追加された差分のみをチャンクとして送信
                let delta = String(newContent.dropFirst(fullText.count))
                if !delta.isEmpty {
                    onChunk(delta)
                }
                fullText = newContent
            }
            return fullText
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    // MARK: - Summarize

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

    // MARK: - Prewarm

    /// モデルリソースを事前ロードし、初回応答のレイテンシを削減する。
    /// 呼び出しは任意。UI でユーザーが Ask AI 画面を開く直前などに使う。
    func prewarm(promptPrefix: String = "") async {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession()
            if promptPrefix.isEmpty {
                session.prewarm()
            } else {
                session.prewarm(promptPrefix: Prompt(promptPrefix))
            }
            #endif
        }
    }

    // MARK: - Response Parsing

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
