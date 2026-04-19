import Foundation
import Security
import SwiftData

/// Keychain を使った機密情報の保存・読み取り。
/// UserDefaults（@AppStorage）はバックアップに含まれるため、
/// API 鍵などの機密情報は Keychain に保存する。
enum KeychainService {
    enum Key: String {
        case apiKeyOpenAI = "apiKey_openai"
        case apiKeyGemini = "apiKey_gemini"
        case apiKeyDeepSeek = "apiKey_deepseek"

        // Plaud credentials
        case plaudPassword = "plaud_password"
        case plaudAccessToken = "plaud_accessToken"
        case plaudRefreshToken = "plaud_refreshToken"
        case plaudTokenExpiresAt = "plaud_tokenExpiresAt"

        // Google Meet OAuth tokens
        case googleMeetAccessToken = "googleMeet_accessToken"
        case googleMeetRefreshToken = "googleMeet_refreshToken"
        case googleMeetTokenExpiresAt = "googleMeet_tokenExpiresAt"
    }

    static func save(key: Key, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 既存の値があれば削除
        let query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty else { return }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.memora.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(key: Key) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.memora.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func delete(key: Key) {
        let query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)
    }

    /// 初回起動時に UserDefaults の既存値を Keychain に移行する
    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        for key in [Key.apiKeyOpenAI, .apiKeyGemini, .apiKeyDeepSeek] {
            let oldValue = defaults.string(forKey: key.rawValue) ?? ""
            if !oldValue.isEmpty {
                // Keychain に保存
                save(key: key, value: oldValue)
                // UserDefaults から削除
                defaults.removeObject(forKey: key.rawValue)
            }
        }
    }

    // MARK: - Date Helpers

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func saveDate(key: Key, value: Date?) {
        guard let value else {
            delete(key: key)
            return
        }
        save(key: key, value: isoFormatter.string(from: value))
    }

    static func loadDate(key: Key) -> Date? {
        let string = load(key: key)
        guard !string.isEmpty else { return nil }
        return isoFormatter.date(from: string)
    }

    // MARK: - SwiftData Credential Migration

    /// SwiftData に平文保存されている Plaud/GoogleMeet 認証情報を Keychain に移行する
    static func migrateCredentialsFromSwiftData(context: ModelContext) {
        let flag = "didMigrateSwiftDataCredentialsToKeychain"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        // PlaudSettings
        if let plaud = try? context.fetch(FetchDescriptor<PlaudSettings>()).first {
            if !plaud.password.isEmpty {
                save(key: .plaudPassword, value: plaud.password)
                plaud.password = ""
            }
            if !plaud.accessToken.isEmpty {
                save(key: .plaudAccessToken, value: plaud.accessToken)
                plaud.accessToken = ""
            }
            if !plaud.refreshToken.isEmpty {
                save(key: .plaudRefreshToken, value: plaud.refreshToken)
                plaud.refreshToken = ""
            }
            if let expiresAt = plaud.tokenExpiresAt {
                saveDate(key: .plaudTokenExpiresAt, value: expiresAt)
                plaud.tokenExpiresAt = nil
            }
            plaud.updatedAt = Date()
        }

        // GoogleMeetSettings
        if let google = try? context.fetch(FetchDescriptor<GoogleMeetSettings>()).first {
            if !google.accessToken.isEmpty {
                save(key: .googleMeetAccessToken, value: google.accessToken)
                google.accessToken = ""
            }
            if !google.refreshToken.isEmpty {
                save(key: .googleMeetRefreshToken, value: google.refreshToken)
                google.refreshToken = ""
            }
            if let expiresAt = google.tokenExpiresAt {
                saveDate(key: .googleMeetTokenExpiresAt, value: expiresAt)
                google.tokenExpiresAt = nil
            }
            google.updatedAt = Date()
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: flag)
    }

    private static func baseQuery(key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.memora.app"
        ]
    }
}
