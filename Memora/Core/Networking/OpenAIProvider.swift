import Foundation

final class OpenAIProvider: LLMProviderProtocol, @unchecked Sendable {
    let provider: AIProvider = .openai
    let defaultModel = "gpt-4o-mini"

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
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

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw AIError.decodingError
        }
        return content
    }
}
