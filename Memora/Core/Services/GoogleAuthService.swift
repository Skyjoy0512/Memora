import Foundation
import AuthenticationServices

/// Google OAuth2 フローを管理するサービス。
/// ASWebAuthenticationSession を使用して外部 SDK なしで OAuth 認可を行う。
@MainActor
final class GoogleAuthService {

    // MARK: - Error

    enum GoogleAuthError: LocalizedError {
        case missingConfiguration
        case invalidURL
        case userCancelled
        case noAuthorizationCode
        case tokenExchangeFailed(String)
        case tokenRefreshFailed(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Google OAuth 設定が不完全です。Client ID と Redirect URI を設定してください。"
            case .invalidURL:
                return "認可 URL の生成に失敗しました。"
            case .userCancelled:
                return "認可がキャンセルされました。"
            case .noAuthorizationCode:
                return "認可コードの取得に失敗しました。"
            case .tokenExchangeFailed(let message):
                return "トークン交換に失敗しました: \(message)"
            case .tokenRefreshFailed(let message):
                return "トークンの更新に失敗しました: \(message)"
            case .networkError(let error):
                return "通信エラー: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Response

    struct TokenResponse: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?
        let tokenType: String?
        let scope: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
            case scope
        }

        var calculatedExpiresAt: Date? {
            guard let expiresIn else { return nil }
            return Date().addingTimeInterval(TimeInterval(expiresIn))
        }
    }

    // MARK: - Properties

    private var session: ASWebAuthenticationSession?
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Authorize

    /// Google OAuth 認可フローを開始する。
    func authorize(
        clientID: String,
        redirectURIScheme: String,
        contextProvider: ASWebAuthenticationPresentationContextProviding
    ) async throws -> TokenResponse {
        guard !clientID.isEmpty, !redirectURIScheme.isEmpty else {
            throw GoogleAuthError.missingConfiguration
        }

        let redirectURL = URL(string: redirectURIScheme + ":/oauthredirect")!
        let authURL = try buildAuthorizationURL(
            clientID: clientID,
            redirectURL: redirectURL
        )

        // ASWebAuthenticationSession で認可コードを取得
        let callbackURL: URL
        do {
            callbackURL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: redirectURIScheme,
                    completionHandler: { url, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: GoogleAuthError.noAuthorizationCode)
                        }
                    }
                )
                session.presentationContextProvider = contextProvider
                session.prefersEphemeralWebBrowserSession = false
                self.session = session

                guard session.start() else {
                    continuation.resume(throwing: GoogleAuthError.invalidURL)
                    return
                }
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw GoogleAuthError.userCancelled
        }

        // コールバック URL から認可コードを抽出
        guard let code = extractAuthorizationCode(from: callbackURL) else {
            throw GoogleAuthError.noAuthorizationCode
        }

        // 認可コード → トークン交換
        return try await exchangeCode(
            code: code,
            clientID: clientID,
            redirectURL: redirectURL
        )
    }

    // MARK: - Refresh

    /// リフレッシュトークンでアクセストークンを更新する。
    func refreshToken(
        clientID: String,
        refreshToken: String
    ) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleAuthError.tokenRefreshFailed(message)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GoogleAuthError.tokenRefreshFailed(error.localizedDescription)
        }
    }

    // MARK: - Revoke

    /// トークンを失効させる。
    func revokeToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "token=\(token)".data(using: .utf8)

        _ = try await urlSession.data(for: request)
    }

    // MARK: - Private

    private func buildAuthorizationURL(clientID: String, redirectURL: URL) throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleMeetSettings.scopeString),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components?.url else {
            throw GoogleAuthError.invalidURL
        }
        return url
    }

    private func extractAuthorizationCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        return queryItems.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCode(
        code: String,
        clientID: String,
        redirectURL: URL
    ) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURL.absoluteString,
            "grant_type": "authorization_code"
        ]
        request.httpBody = body.map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleAuthError.tokenExchangeFailed(message)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GoogleAuthError.tokenExchangeFailed(error.localizedDescription)
        }
    }
}
