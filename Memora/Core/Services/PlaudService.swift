import Foundation

/// Plaud デバイス連携サービス（Plaud Toolkit 互換 API）
final class PlaudService {
    // MARK: - Types

    enum PlaudError: LocalizedError {
        case invalidURL
        case invalidResponse
        case authenticationFailed
        case networkError(Error)
        case serverError(Int, String?)
        case decodingError(Error)
        case noAudioFile
        case invalidCredentials
        case tokenExpired

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効な URL です"
            case .invalidResponse:
                return "無効なレスポンスです"
            case .authenticationFailed:
                return "認証に失敗しました"
            case .networkError(let error):
                return "ネットワークエラー: \(error.localizedDescription)"
            case .serverError(let code, let message):
                return "サーバーエラー (\(code)): \(message ?? "不明なエラー")"
            case .decodingError(let error):
                return "デコードエラー: \(error.localizedDescription)"
            case .noAudioFile:
                return "オーディオファイルが見つかりません"
            case .invalidCredentials:
                return "メールアドレスまたはパスワードが正しくありません"
            case .tokenExpired:
                return "トークンの有効期限が切れました。再ログインしてください"
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // ISO8601 形式を試す
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Unix timestamp 形式を試す
            if let timestamp = Double(dateString) {
                return Date(timeIntervalSince1970: timestamp)
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        self.decoder = decoder
    }

    // MARK: - Authentication

    /// ログイン（メールアドレス + パスワード）
    func login(apiServer: String, email: String, password: String) async throws -> PlaudAuthResponse {
        let request = try buildAuthRequest(
            serverURL: apiServer,
            path: "/api/auth/login",
            method: "POST",
            body: [
                "email": email,
                "password": password
            ]
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw PlaudError.invalidCredentials
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }

        do {
            let authResponse = try decoder.decode(PlaudAuthResponse.self, from: data)

            // トークン有効期限を設定（デフォルト 300 日）
            if let expiresIn = authResponse.expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                var response = authResponse
                response.calculatedExpiresAt = expirationDate
                return response
            }

            return authResponse
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    /// トークンリフレッシュ
    func refreshToken(apiServer: String, refreshToken: String) async throws -> PlaudAuthResponse {
        let request = try buildAuthRequest(
            serverURL: apiServer,
            path: "/api/auth/refresh",
            method: "POST",
            body: [
                "refreshToken": refreshToken
            ]
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw PlaudError.tokenExpired
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }

        do {
            let authResponse = try decoder.decode(PlaudAuthResponse.self, from: data)

            // トークン有効期限を設定
            if let expiresIn = authResponse.expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                var response = authResponse
                response.calculatedExpiresAt = expirationDate
                return response
            }

            return authResponse
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    /// ユーザー情報を取得
    func getUserInfo(apiServer: String, token: String) async throws -> PlaudUserInfo {
        let request = try buildRequest(serverURL: apiServer, token: token, path: "/api/user/info")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw PlaudError.tokenExpired
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }

        do {
            return try decoder.decode(PlaudUserInfo.self, from: data)
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    // MARK: - Recording Operations

    /// 接続テスト
    func testConnection(apiServer: String, token: String) async throws -> Bool {
        let request = try buildRequest(serverURL: apiServer, token: token, path: "/api/recordings")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return true
        case 401, 403:
            throw PlaudError.tokenExpired
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    /// 録音データを同期
    func syncRecordings(apiServer: String, token: String) async throws -> [PlaudRecording] {
        let request = try buildRequest(serverURL: apiServer, token: token, path: "/api/recordings")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw PlaudError.tokenExpired
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }

        do {
            let result = try decoder.decode(PlaudRecordingListResponse.self, from: data)
            return result.recordings
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    /// 録音をダウンロードして Memora に保存
    func importRecordingToMemora(
        recording: PlaudRecording,
        apiServer: String,
        token: String
    ) async throws -> URL {
        // 音声ファイルをダウンロード
        let tempUrl = try await downloadRecording(
            apiServer: apiServer,
            token: token,
            recordingId: recording.id
        )

        // Memora のドキュメントフォルダにコピー
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "plaud_\(recording.id).m4a"
        let destinationUrl = documentsDir.appendingPathComponent(filename)

        // 既存ファイルがあれば削除
        if FileManager.default.fileExists(atPath: destinationUrl.path) {
            try FileManager.default.removeItem(at: destinationUrl)
        }

        // ファイルをコピー
        try FileManager.default.copyItem(at: tempUrl, to: destinationUrl)

        // 一時ファイルを削除
        try? FileManager.default.removeItem(at: tempUrl)

        return destinationUrl
    }

    /// 録音をダウンロード
    func downloadRecording(
        apiServer: String,
        token: String,
        recordingId: String
    ) async throws -> URL {
        let request = try buildRequest(serverURL: apiServer, token: token, path: "/api/recordings/\(recordingId)/audio")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaudError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            throw PlaudError.tokenExpired
        case 404:
            throw PlaudError.noAudioFile
        case 400...499:
            throw PlaudError.authenticationFailed
        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw PlaudError.serverError(httpResponse.statusCode, errorMessage)
        }

        // 一時ファイルに保存
        let filename = "plaud_recording_\(recordingId).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)

        return url
    }

    // MARK: - Private Helpers

    private func buildAuthRequest(
        serverURL: String,
        path: String,
        method: String,
        body: [String: Any]
    ) throws -> URLRequest {
        // URL を正規化（末尾のスラッシュ処理）
        var normalizedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedServer.hasSuffix("/") {
            normalizedServer.removeLast()
        }

        var normalizedPath = path
        if !normalizedPath.hasPrefix("/") {
            normalizedPath = "/" + normalizedPath
        }

        let urlString = "\(normalizedServer)\(normalizedPath)"

        guard let url = URL(string: urlString) else {
            throw PlaudError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // JSON ボディを設定
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return request
    }

    private func buildRequest(serverURL: String, token: String, path: String) throws -> URLRequest {
        // URL を正規化（末尾のスラッシュ処理）
        var normalizedServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedServer.hasSuffix("/") {
            normalizedServer.removeLast()
        }

        var normalizedPath = path
        if !normalizedPath.hasPrefix("/") {
            normalizedPath = "/" + normalizedPath
        }

        let urlString = "\(normalizedServer)\(normalizedPath)"

        guard let url = URL(string: urlString) else {
            throw PlaudError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }
}

// MARK: - Response Models

struct PlaudAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String?
    let expiresIn: Int?

    // 計算された有効期限（サーバーレスポンスには含まれない）
    var calculatedExpiresAt: Date?
}

struct PlaudUserInfo: Codable {
    let id: String
    let email: String
    let name: String?
}

private struct PlaudRecordingListResponse: Codable {
    let recordings: [PlaudRecording]
}
