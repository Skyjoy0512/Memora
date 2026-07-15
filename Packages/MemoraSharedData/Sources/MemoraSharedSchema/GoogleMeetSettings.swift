import Foundation
import SwiftData

/// Google Meet 連携の OAuth 設定とトークン管理。
@Model
public final class GoogleMeetSettings {
    public var clientID: String = ""
    public var redirectURIScheme: String = ""
    public var accessToken: String = ""
    public var refreshToken: String = ""
    public var tokenExpiresAt: Date?
    public var isEnabled: Bool = false
    public var lastSyncAt: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
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

    // MARK: - OAuth Configuration

    /// 認可エンドポイント
    public static let authorizationURL = "https://accounts.google.com/o/oauth2/v2/auth"

    /// トークンエンドポイント
    public static let tokenURL = "https://oauth2.googleapis.com/token"

    /// 失効エンドポイント
    public static let revokeURL = "https://oauth2.googleapis.com/revoke"

    /// Meet + Drive の必要スコープ
    public static let requiredScopes = [
        "https://www.googleapis.com/auth/meetings.space.readonly",
        "https://www.googleapis.com/auth/drive.readonly"
    ]

    /// スコープ文字列（スペース区切り）
    public static var scopeString: String {
        requiredScopes.joined(separator: " ")
    }

    /// 認可 URL を生成
    public func authorizationURL() -> URL? {
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
