import Foundation

/// Webhook ペイロード
struct WebhookPayload: Codable {
    let event: String
    let timestamp: String
    let data: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case event
        case timestamp
        case data
    }

    init(event: String, timestamp: String, data: [String: AnyCodable]) {
        self.event = event
        self.timestamp = timestamp
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        data = try container.decode([String: AnyCodable].self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(data, forKey: .data)
    }
}

/// Any 型を Codable に対応させるラッパー
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

/// Webhook サービス
final class WebhookService {
    private let session: URLSession
    private let iso8601Formatter: ISO8601DateFormatter

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Webhook を送信
    func sendWebhook(
        eventType: WebhookEventType,
        data: [String: Any],
        settings: WebhookSettings
    ) async throws {
        guard settings.isEnabled else { return }
        guard settings.isEventEnabled(eventType) else { return }
        guard !settings.url.isEmpty else { return }

        // URL を検証
        guard let url = URL(string: settings.url) else {
            throw WebhookError.invalidURL
        }

        // ペイロードを構築
        let payload = WebhookPayload(
            event: eventType.rawValue,
            timestamp: iso8601Formatter.string(from: Date()),
            data: data.mapValues { AnyCodable($0) }
        )

        // JSON にエンコード
        let jsonData = try JSONEncoder().encode(payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // 送信
        let (responseData, response) = try await session.data(for: request)

        // ステータスコードを確認
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebhookError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // レスポンスをログ
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("Webhook レスポンス: \(responseString)")
        }
    }
}

/// Webhook エラー
enum WebhookError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効な Webhook URL です"
        case .httpError(let code):
            return "HTTP エラー: \(code)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}
