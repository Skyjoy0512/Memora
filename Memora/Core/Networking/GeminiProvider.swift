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
            systemPrompt: systemPrompt,
            userPrompt: prompt
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
            "generationConfig": [
                "temperature": 0.7
            ]
        ]

        return try await sendRequest(model: model ?? defaultModel, body: body)
    }

    // MARK: - Private

    private func sendGenerate(
        model: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": "\(systemPrompt)\n\n\(userPrompt)"]]]
            ],
            "generationConfig": [
                "temperature": 0.3
            ]
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

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.decodingError
        }
        return content
    }
}
