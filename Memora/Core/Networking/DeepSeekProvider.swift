import Foundation

final class DeepSeekProvider: LLMProviderProtocol, @unchecked Sendable {
    let provider: AIProvider = .deepseek
    let defaultModel = "deepseek-chat"

    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    func summarize(
        transcript: String,
        prompt: String,
        model: String? = nil
    ) async throws -> LLMResponse {
        let messages: [[String: String]] = [
            ["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。必ずJSON形式のみで応答してください。"],
            ["role": "user", "content": prompt]
        ]

        let rawText = try await sendChat(
            model: model ?? defaultModel,
            messages: messages,
            temperature: 0.3
        )

        return parseSummaryResponse(rawText)
    }

    func chat(
        messages: [ChatMessage],
        model: String? = nil
    ) async throws -> String {
        let mapped = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        return try await sendChat(
            model: model ?? defaultModel,
            messages: mapped,
            temperature: 0.7
        )
    }

    // MARK: - Private

    private func sendChat(
        model: String,
        messages: [[String: String]],
        temperature: Double
    ) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": 4096
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(http.statusCode, msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.decodingError
        }
        return content
    }

    private func parseSummaryResponse(_ rawText: String) -> LLMResponse {
        var cleaned = rawText
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String,
              let keyPoints = json["keyPoints"] as? [String],
              let actionItems = json["actionItems"] as? [String] else {
            return LLMResponse(rawText: rawText, summary: rawText, keyPoints: [], actionItems: [], decisions: [])
        }

        let decisions = json["decisions"] as? [String] ?? []
        return LLMResponse(rawText: rawText, summary: summary, keyPoints: keyPoints, actionItems: actionItems, decisions: decisions)
    }
}
