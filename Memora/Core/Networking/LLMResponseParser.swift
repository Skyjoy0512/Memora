import Foundation

// MARK: - Shared Response Parsing

/// LLM レスポンスの JSON パーサー。全 Provider で共有。
enum LLMResponseParser {
    static func parse(_ rawText: String) throws -> LLMResponse {
        // マークダウンコードブロックを除去
        var cleaned = rawText
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.decodingError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String,
              let keyPoints = json["keyPoints"] as? [String],
              let actionItems = json["actionItems"] as? [String] else {
            throw AIError.decodingError
        }

        let decisions = json["decisions"] as? [String] ?? []

        return LLMResponse(
            rawText: rawText,
            summary: summary,
            keyPoints: keyPoints,
            actionItems: actionItems,
            decisions: decisions
        )
    }
}

// MARK: - Shared Response Models

/// OpenAI / DeepSeek 互換の Chat Completion レスポンス
struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

/// Gemini GenerateContent レスポンス
struct GeminiResponse: Codable {
    let candidates: [Candidate]

    struct Candidate: Codable {
        let content: Content
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String?
    }
}

// MARK: - Provider Extension

extension LLMProviderProtocol {
    func parseSummaryResponse(_ rawText: String) -> LLMResponse {
        // Try structured parse first
        if let result = try? LLMResponseParser.parse(rawText) {
            return result
        }

        // Fallback: return raw text as summary
        return LLMResponse(
            rawText: rawText,
            summary: rawText,
            keyPoints: [],
            actionItems: [],
            decisions: []
        )
    }
}
