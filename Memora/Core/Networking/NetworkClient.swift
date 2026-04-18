//
//  NetworkClient.swift
//  Memora
//
//  汎用HTTPクライアント
//  リトライ機能、タイムアウト設定、エラーハンドリング、DebugLogger連携を提供
//

import Foundation

// MARK: - Network Error

enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case noConnection
    case timedOut
    case cancelled
    case encodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .httpError(let code, _):
            return "HTTPエラー: \(code)"
        case .decodingFailed(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .noConnection:
            return "ネットワーク接続がありません"
        case .timedOut:
            return "リクエストがタイムアウトしました"
        case .cancelled:
            return "リクエストがキャンセルされました"
        case .encodingFailed(let error):
            return "データのエンコードに失敗しました: \(error.localizedDescription)"
        }
    }

    static func from(_ urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        default:
            return .httpError(statusCode: -1, data: Data())
        }
    }
}

// MARK: - Request Builder

struct NetworkRequest {
    let url: URL
    let method: String
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval?

    func build() throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if let timeout = timeout {
            request.timeoutInterval = timeout
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}

// MARK: - Network Client Protocol

protocol NetworkClientProtocol: Sendable {
    func send(request: NetworkRequest) async throws -> Data
    func send<T: Decodable>(request: NetworkRequest, responseType: T.Type) async throws -> T
}

// MARK: - Network Client Implementation

final class NetworkClient: NetworkClientProtocol {

    // MARK: - Configuration

    private let session: URLSession
    private let defaultTimeout: TimeInterval
    private let uploadTimeout: TimeInterval
    private let maxRetries: Int

    // MARK: - Init

    init(
        session: URLSession = .shared,
        defaultTimeout: TimeInterval = 30,
        uploadTimeout: TimeInterval = 120,
        maxRetries: Int = 3
    ) {
        self.defaultTimeout = defaultTimeout
        self.uploadTimeout = uploadTimeout
        self.maxRetries = maxRetries

        // カスタムURLSessionを作成（デフォルト設定）
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = defaultTimeout
        configuration.timeoutIntervalForResource = defaultTimeout
        configuration.waitsForConnectivity = true

        // ユーザーがカスタムセッションを渡した場合はそれを使用
        self.session = session
    }

    // MARK: - Public API

    func send(request: NetworkRequest) async throws -> Data {
        var request = request

        // タイムアウトが設定されていない場合はデフォルトを使用
        if request.timeout == nil {
            request.timeout = defaultTimeout
        }

        return try await withRetry { [self] in
            try await self.performRequest(request)
        }
    }

    func send<T: Decodable>(request: NetworkRequest, responseType: T.Type) async throws -> T {
        let data = try await send(request: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Convenience Methods

    /// GETリクエストを送信
    func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        let request = NetworkRequest(
            url: url,
            method: "GET",
            headers: headers
        )
        return try await send(request: request)
    }

    /// GETリクエストを送信（デコード）
    func get<T: Decodable>(url: URL, headers: [String: String] = [:], responseType: T.Type) async throws -> T {
        let data = try await get(url: url, headers: headers)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    /// POSTリクエストを送信
    func post(url: URL, headers: [String: String] = [:], body: Data? = nil) async throws -> Data {
        let request = NetworkRequest(
            url: url,
            method: "POST",
            headers: headers,
            body: body,
            timeout: uploadTimeout
        )
        return try await send(request: request)
    }

    /// POSTリクエストを送信（デコード）
    func post<T: Decodable>(url: URL, headers: [String: String] = [:], body: Data? = nil, responseType: T.Type) async throws -> T {
        let data = try await post(url: url, headers: headers, body: body)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    /// JSONボディでのPOSTリクエスト
    func postJSON<T: Encodable, U: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        body: T,
        responseType: U.Type
    ) async throws -> U {
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        var finalHeaders = headers
        finalHeaders["Content-Type"] = "application/json"

        return try await post(url: url, headers: finalHeaders, body: bodyData, responseType: responseType)
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: NetworkRequest) async throws -> Data {
        let urlRequest = try request.build()

        DebugLogger.shared.addLog(
            "NetworkClient",
            "Sending \(request.method) to \(request.url.absoluteString)",
            level: .info
        )

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        DebugLogger.shared.addLog(
            "NetworkClient",
            "Received HTTP \(httpResponse.statusCode) from \(request.url.absoluteString)",
            level: .info
        )

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }

    private func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // キャンセル時は即時終了
                if error is CancellationError {
                    throw error
                }

                // 4xxエラー（429除く）はリトライしない
                if case NetworkError.httpError(let code, _) = error {
                    if (400..<500).contains(code) && code != 429 {
                        throw error
                    }
                }

                // 最後の試行であれば終了
                if attempt == maxRetries - 1 {
                    break
                }

                // Exponential backoff
                let delay = pow(2.0, Double(attempt))
                DebugLogger.shared.addLog(
                    "NetworkClient",
                    "Retry \(attempt + 1)/\(maxRetries) after \(delay)s delay: \(error.localizedDescription)",
                    level: .warning
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? NetworkError.invalidResponse
    }
}

// MARK: - Multipart Form Data Support

extension NetworkClient {

    struct MultipartFormData {
        private var parts: [Part] = []

        struct Part {
            let name: String
            let filename: String?
            let mimeType: String?
            let data: Data
        }

        mutating func add(name: String, value: String) {
            if let data = value.data(using: .utf8) {
                parts.append(Part(name: name, filename: nil, mimeType: nil, data: data))
            }
        }

        mutating func add(name: String, filename: String, mimeType: String, data: Data) {
            parts.append(Part(name: name, filename: filename, mimeType: mimeType, data: data))
        }

        func encode() throws -> Data {
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()

            for part in parts {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)

                if let filename = part.filename, let mimeType = part.mimeType {
                    body.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                    body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                } else {
                    body.append("Content-Disposition: form-data; name=\"\(part.name)\"\r\n\r\n".data(using: .utf8)!)
                }

                body.append(part.data)
                body.append("\r\n".data(using: .utf8)!)
            }

            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            return body
        }

        func contentType() -> String {
            let boundary = "Boundary-\(UUID().uuidString)"
            return "multipart/form-data; boundary=\(boundary)"
        }
    }

    /// Multipart/Form-DataでPOST
    func postMultipart<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        formData: MultipartFormData,
        responseType: T.Type
    ) async throws -> T {
        var finalHeaders = headers
        finalHeaders["Content-Type"] = formData.contentType()

        let body = try formData.encode()

        let request = NetworkRequest(
            url: url,
            method: "POST",
            headers: finalHeaders,
            body: body,
            timeout: uploadTimeout
        )

        return try await send(request: request, responseType: responseType)
    }
}
