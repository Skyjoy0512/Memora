import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class PlaudMCPOAuthService: NSObject {
    private static let authorizationEndpoint = URL(string: "https://mcp.plaud.ai/authorize")!
    private static let tokenEndpoint = URL(string: "https://mcp.plaud.ai/token")!
    private static let registrationEndpoint = URL(string: "https://mcp.plaud.ai/register")!
    private static let callbackScheme = "memora-plaud"
    private var webSession: ASWebAuthenticationSession?

    struct Account: Sendable {
        let isConnected: Bool
        let expiresAt: Date?
    }

    func account() -> Account {
        let token = KeychainService.load(key: .plaudMCPAccessToken)
        return Account(
            isConnected: !token.isEmpty,
            expiresAt: KeychainService.loadDate(key: .plaudMCPTokenExpiresAt)
        )
    }

    func connect() async throws {
        let clientID = try await registeredClientID()
        let verifier = Self.randomURLSafeString(length: 64)
        let state = Self.randomURLSafeString(length: 32)
        let redirectURI = "\(Self.callbackScheme):/oauth"
        var components = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authorizationURL = components.url else {
            throw PlaudMCPToolError(message: "PLAUD認可URLを作成できません")
        }

        let callbackURL = try await authorize(url: authorizationURL)
        let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        guard callbackComponents?.queryItems?.first(where: { $0.name == "state" })?.value == state,
              let code = callbackComponents?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw PlaudMCPToolError(message: "PLAUD認可の検証に失敗しました")
        }
        let token = try await exchangeCode(code, verifier: verifier, clientID: clientID, redirectURI: redirectURI)
        save(token: token)
    }

    func refreshIfNeeded() async throws {
        guard let expiry = KeychainService.loadDate(key: .plaudMCPTokenExpiresAt),
              expiry <= Date().addingTimeInterval(60) else { return }
        let refreshToken = KeychainService.load(key: .plaudMCPRefreshToken)
        let clientID = KeychainService.load(key: .plaudMCPClientID)
        guard !refreshToken.isEmpty, !clientID.isEmpty else {
            throw PlaudMCPToolError(message: "PLAUDへの再接続が必要です")
        }
        let token = try await requestToken([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ])
        save(token: token, fallbackRefreshToken: refreshToken)
    }

    func disconnect() {
        KeychainService.delete(key: .plaudMCPAccessToken)
        KeychainService.delete(key: .plaudMCPRefreshToken)
        KeychainService.saveDate(key: .plaudMCPTokenExpiresAt, value: nil)
    }

    private func registeredClientID() async throws -> String {
        let existing = KeychainService.load(key: .plaudMCPClientID)
        if !existing.isEmpty { return existing }
        let request = ClientRegistrationRequest(
            clientName: "Memora",
            redirectURIs: ["\(Self.callbackScheme):/oauth"],
            grantTypes: ["authorization_code", "refresh_token"],
            responseTypes: ["code"],
            tokenEndpointAuthMethod: "none"
        )
        var urlRequest = URLRequest(url: Self.registrationEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.plaudOAuth.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PlaudMCPToolError(message: "PLAUDクライアント登録に失敗しました")
        }
        let registration = try JSONDecoder().decode(ClientRegistrationResponse.self, from: data)
        KeychainService.save(key: .plaudMCPClientID, value: registration.clientID)
        return registration.clientID
    }

    private func authorize(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: PlaudMCPToolError(message: "PLAUD認可をキャンセルしました"))
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: PlaudMCPToolError(message: "PLAUD認可の結果を取得できません"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            guard session.start() else {
                continuation.resume(throwing: PlaudMCPToolError(message: "PLAUD認可を開始できません"))
                return
            }
        }
    }

    private func exchangeCode(_ code: String, verifier: String, clientID: String, redirectURI: String) async throws -> OAuthTokenResponse {
        try await requestToken([
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "client_id": clientID,
            "redirect_uri": redirectURI
        ])
    }

    private func requestToken(_ fields: [String: String]) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.plaudOAuth.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PlaudMCPToolError(message: "PLAUDトークンの取得に失敗しました")
        }
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    private func save(token: OAuthTokenResponse, fallbackRefreshToken: String? = nil) {
        KeychainService.save(key: .plaudMCPAccessToken, value: token.accessToken)
        KeychainService.save(key: .plaudMCPRefreshToken, value: token.refreshToken ?? fallbackRefreshToken ?? "")
        KeychainService.saveDate(
            key: .plaudMCPTokenExpiresAt,
            value: token.expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        )
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}

extension PlaudMCPOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

private struct ClientRegistrationRequest: Encodable {
    let clientName: String
    let redirectURIs: [String]
    let grantTypes: [String]
    let responseTypes: [String]
    let tokenEndpointAuthMethod: String

    enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case redirectURIs = "redirect_uris"
        case grantTypes = "grant_types"
        case responseTypes = "response_types"
        case tokenEndpointAuthMethod = "token_endpoint_auth_method"
    }
}

private struct ClientRegistrationResponse: Decodable {
    let clientID: String
    enum CodingKeys: String, CodingKey { case clientID = "client_id" }
}

private struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private extension URLSession {
    static let plaudOAuth: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
