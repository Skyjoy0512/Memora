import Foundation

/// Plaud デバイス連携サービス（Plaud Toolkit 互換 API）
final class PlaudService {

    private static let plaudISO8601Formatter = Foundation.ISO8601DateFormatter()

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

    private let networkClient: NetworkClient
    private let decoder: JSONDecoder

    init(networkClient: NetworkClient = .init()) {
        self.networkClient = networkClient

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // ISO8601 形式を試す
            if let date = Self.plaudISO8601Formatter.date(from: dateString) {
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
        let url = try buildURL(serverURL: apiServer, path: "/api/auth/login")

        struct LoginRequest: Codable {
            let email: String
            let password: String
        }

        let loginRequest = LoginRequest(email: email, password: password)

        do {
            let authResponse: PlaudAuthResponse = try await networkClient.postJSON(
                url: url,
                headers: ["Content-Type": "application/json"],
                body: loginRequest,
                responseType: PlaudAuthResponse.self
            )

            // トークン有効期限を設定（デフォルト 300 日）
            if let expiresIn = authResponse.expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                var response = authResponse
                response.calculatedExpiresAt = expirationDate
                return response
            }

            return authResponse
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    private func mapNetworkError(_ error: NetworkError) -> PlaudError {
        switch error {
        case .httpError(let code, _):
            switch code {
            case 401, 403:
                return .invalidCredentials
            case 404:
                return .noAudioFile
            case 400...499:
                return .authenticationFailed
            default:
                return .serverError(code, nil)
            }
        case .invalidURL:
            return .invalidURL
        case .noConnection, .timedOut:
            return .networkError(error)
        default:
            return .networkError(error)
        }
    }

    /// トークンリフレッシュ
    func refreshToken(apiServer: String, refreshToken: String) async throws -> PlaudAuthResponse {
        let url = try buildURL(serverURL: apiServer, path: "/api/auth/refresh")

        struct RefreshRequest: Codable {
            let refreshToken: String
        }

        let refreshRequest = RefreshRequest(refreshToken: refreshToken)

        do {
            let authResponse: PlaudAuthResponse = try await networkClient.postJSON(
                url: url,
                headers: ["Content-Type": "application/json"],
                body: refreshRequest,
                responseType: PlaudAuthResponse.self
            )

            // トークン有効期限を設定
            if let expiresIn = authResponse.expiresIn {
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                var response = authResponse
                response.calculatedExpiresAt = expirationDate
                return response
            }

            return authResponse
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    /// ユーザー情報を取得
    func getUserInfo(apiServer: String, token: String) async throws -> PlaudUserInfo {
        let url = try buildURL(serverURL: apiServer, path: "/api/user/info")

        do {
            return try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(token)"],
                responseType: PlaudUserInfo.self
            )
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        } catch {
            throw PlaudError.decodingError(error)
        }
    }

    // MARK: - Recording Operations

    /// 接続テスト
    func testConnection(apiServer: String, token: String) async throws -> Bool {
        let url = try buildURL(serverURL: apiServer, path: "/api/recordings")

        do {
            let _: PlaudRecordingListResponse = try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(token)"],
                responseType: PlaudRecordingListResponse.self
            )
            return true
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }
    }

    /// 録音データを同期
    func syncRecordings(apiServer: String, token: String) async throws -> [PlaudRecording] {
        let url = try buildURL(serverURL: apiServer, path: "/api/recordings")

        do {
            let result: PlaudRecordingListResponse = try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(token)"],
                responseType: PlaudRecordingListResponse.self
            )
            return result.recordings
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
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
        let url = try buildURL(serverURL: apiServer, path: "/api/recordings/\(recordingId)/audio")

        let data: Data
        do {
            data = try await networkClient.get(
                url: url,
                headers: ["Authorization": "Bearer \(token)"]
            )
        } catch let networkError as NetworkError {
            throw mapNetworkError(networkError)
        }

        // 一時ファイルに保存
        let filename = "plaud_recording_\(recordingId).m4a"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL
    }

    // MARK: - Private Helpers

    private func buildURL(serverURL: String, path: String) throws -> URL {
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

        return url
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
