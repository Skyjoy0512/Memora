import Foundation

// MARK: - OpenAI Service

final class OpenAIService: LLMProvider {
    let displayName = "OpenAI"
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw LLMProviderError.decodingError
        }
        return content
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        let prompt = """
        以下の会議 transcript から、タイトル、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "title": "会議内容を表す簡潔なタイトル（20字以内）",
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw OpenAIError.apiError(httpResponse.statusCode, errorString)
            }
            throw OpenAIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw OpenAIError.decodingError
        }

        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw OpenAIError.decodingError
        }

        let title = summaryData["title"] as? String
        return LLMProviderSummary(title: title, summary: summary, keyPoints: keyPoints, actionItems: actionItems)
    }

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        let filename = audioURL.lastPathComponent.isEmpty ? "audio.m4a" : audioURL.lastPathComponent
        let mimeType = Self.mimeType(for: audioURL)

        var request = URLRequest(url: URL(string: "\(baseURL)/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("gpt-4o-transcribe\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("ja\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append(Self.transcriptionPrompt.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)

        // Add file parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw OpenAIError.apiError(httpResponse.statusCode, errorString)
            }
            throw OpenAIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    private static let transcriptionPrompt = """
    日本語のビジネス会議音声です。固有名詞、商品名、決済、解約、請求、バンドル、ローンチ、集計基準などの業務用語を文脈に合わせて正確に文字起こししてください。
    """

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3", "mpga":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "mp4":
            return "audio/mp4"
        case "webm":
            return "audio/webm"
        case "m4a", "aac":
            return "audio/mp4"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Gemini Service

final class GeminiService: LLMProvider {
    let displayName = "Gemini"
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 1,
                "topP": 1
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw LLMProviderError.decodingError
        }
        return content
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        let prompt = """
        以下の会議 transcript から、タイトル、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "title": "会議内容を表す簡潔なタイトル（20字以内）",
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "あなたは会議の文字起こしから要約を作成するアシスタントです。\n\n\(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 1,
                "topP": 1
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.decodingError
        }

        guard let jsonData = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw AIError.decodingError
        }

        let title = summaryData["title"] as? String
        return LLMProviderSummary(title: title, summary: summary, keyPoints: keyPoints, actionItems: actionItems)
    }

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        let prompt = "この音声を文字起こししてください。会議の内容であれば、発言をそのままテキストとして出力してください。"

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": [
                            "mime_type": "audio/mp4",
                            "data": audioData.base64EncodedString()
                        ]]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "topK": 1,
                "topP": 1
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.decodingError
        }

        return content
    }
}

// MARK: - DeepSeek Service

final class DeepSeekService: LLMProvider {
    let displayName = "DeepSeek"
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw LLMProviderError.decodingError
        }
        return content
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        let prompt = """
        以下の会議 transcript から、タイトル、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "title": "会議内容を表す簡潔なタイトル（20字以内）",
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw AIError.decodingError
        }

        guard let jsonData = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw AIError.decodingError
        }

        let title = summaryData["title"] as? String
        return LLMProviderSummary(title: title, summary: summary, keyPoints: keyPoints, actionItems: actionItems)
    }
}

// MARK: - Response Models

private struct TranscriptionResponse: Codable {
    let text: String
}

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct GeminiResponse: Codable {
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

private struct DeepSeekResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
