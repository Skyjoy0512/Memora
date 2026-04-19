import Foundation
import SwiftData

/// Google Meet 連携の OAuth 設定とトークン管理。
@Model
final class GoogleMeetSettings {
    var clientID: String = ""
    var redirectURIScheme: String = ""
    var accessToken: String = ""
    var refreshToken: String = ""
    var tokenExpiresAt: Date?
    var isEnabled: Bool = false
    var lastSyncAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        clientID: String = "",
        redirectURIScheme: String = "",
        accessToken: String = "",
        refreshToken: String = "",
        tokenExpiresAt: Date? = nil,
        isEnabled: Bool = false
    ) {
        self.clientID = clientID
        self.redirectURIScheme = redirectURIScheme
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.isEnabled = isEnabled
    }

    // MARK: - Token State

    var isTokenValid: Bool {
        let accessToken = KeychainService.load(key: .googleMeetAccessToken)
        guard !accessToken.isEmpty,
              let expiresAt = KeychainService.loadDate(key: .googleMeetTokenExpiresAt) else {
            return false
        }
        return expiresAt > Date()
    }

    var shouldRefreshToken: Bool {
        let refreshToken = KeychainService.load(key: .googleMeetRefreshToken)
        guard !refreshToken.isEmpty else { return false }
        guard let expiresAt = KeychainService.loadDate(key: .googleMeetTokenExpiresAt) else { return true }
        // 5 分前にリフレッシュ
        return expiresAt.addingTimeInterval(-300) <= Date()
    }

    // MARK: - OAuth Configuration

    /// 認可エンドポイント
    static let authorizationURL = "https://accounts.google.com/o/oauth2/v2/auth"

    /// トークンエンドポイント
    static let tokenURL = "https://oauth2.googleapis.com/token"

    /// 失効エンドポイント
    static let revokeURL = "https://oauth2.googleapis.com/revoke"

    /// Meet + Drive の必要スコープ
    static let requiredScopes = [
        "https://www.googleapis.com/auth/meetings.space.readonly",
        "https://www.googleapis.com/auth/drive.readonly"
    ]

    /// スコープ文字列（スペース区切り）
    static var scopeString: String {
        requiredScopes.joined(separator: " ")
    }

    /// 認可 URL を生成
    func authorizationURL() -> URL? {
        guard !clientID.isEmpty, !redirectURIScheme.isEmpty else { return nil }

        var components = URLComponents(string: Self.authorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURIScheme + ":/oauthredirect"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopeString),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components?.url
    }
}
