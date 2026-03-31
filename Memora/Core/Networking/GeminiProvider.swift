import Foundation

final class GeminiProvider: LLMProviderProtocol, @unchecked Sendable {
    let provider: AIProvider = .gemini
    let defaultModel = "gemini-2.0-flash"

    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
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
        let systemPrompt = "あなたは会議の文字起こしから要約を作成するアシスタントです。必ずJSON形式のみで応答してください。"

        let rawText = try await sendGenerate(
            model: model ?? defaultModel,
            prompt: "\(systemPrompt)\n\n\(prompt)"
        )

        return parseSummaryResponse(rawText)
    }

    func chat(
        messages: [ChatMessage],
        model: String? = nil
    ) async throws -> String {
        let parts = messages.map { msg -> [String: String] in
            return ["text": msg.content]
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["temperature": 0.7]
        ]

        return try await sendRequest(model: model ?? defaultModel, body: body)
    }

    // MARK: - Private

    private func sendGenerate(model: String, prompt: String) async throws -> String {
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3]
        ]
        return try await sendRequest(model: model, body: body)
    }

    private func sendRequest(model: String, body: [String: Any]) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(http.statusCode, msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIError.decodingError
        }
        return text
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
