import Foundation
import Security

/// Keychain を使った機密情報の保存・読み取り。
/// UserDefaults（@AppStorage）はバックアップに含まれるため、
/// API 鍵などの機密情報は Keychain に保存する。
enum KeychainService {
    enum Key: String {
        case apiKeyOpenAI = "apiKey_openai"
        case apiKeyGemini = "apiKey_gemini"
        case apiKeyDeepSeek = "apiKey_deepseek"
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

    private static func baseQuery(key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "com.memora.app"
        ]
    }
}
