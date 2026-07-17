import Foundation
import Security
internal import MemoraNative

/// RN専用Keychainの秘密情報。値はRNホスト内でのみ取り扱う。
struct MemoraRNKeychainSecureCredentials: MemoraRNSummaryKeyReading, MemoraSecureCredentialWriting {
  static let service = "com.anonymous.memora-rn.ai-credentials"

  func apiKey(for provider: MemoraRNSummaryProvider) throws -> String? {
    guard let credentialProvider = MemoraSecureCredentialProvider(bridgeValue: provider.rawValue) else { return nil }
    return try readAPIKey(for: credentialProvider)
  }

  func save(apiKey: String, for provider: MemoraSecureCredentialProvider) throws {
    let data = Data(apiKey.utf8)
    let query = baseQuery(for: provider)
    let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw MemoraSecureCredentialError.unavailable }
      return
    }
    guard status == errSecSuccess else { throw MemoraSecureCredentialError.unavailable }
  }

  func deleteCredential(for provider: MemoraSecureCredentialProvider) throws {
    let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw MemoraSecureCredentialError.unavailable }
  }

  func isCredentialConfigured(for provider: MemoraSecureCredentialProvider) throws -> Bool {
    guard let key = try readAPIKey(for: provider) else { return false }
    return !key.isEmpty
  }

  private func readAPIKey(for provider: MemoraSecureCredentialProvider) throws -> String? {
    var query = baseQuery(for: provider)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else { throw MemoraSecureCredentialError.unavailable }
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func baseQuery(for provider: MemoraSecureCredentialProvider) -> [String: Any] {
    [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service, kSecAttrAccount as String: account(for: provider)]
  }

  private func account(for provider: MemoraSecureCredentialProvider) -> String {
    switch provider {
    case .openAI: return "openai-api-key"
    case .gemini: return "gemini-api-key"
    case .deepSeek: return "deepseek-api-key"
    }
  }
}
