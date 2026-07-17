import Foundation
import UIKit

public enum MemoraSecureCredentialProvider: String {
  case openAI = "OpenAI"
  case gemini = "Gemini"
  case deepSeek = "DeepSeek"

  public init?(bridgeValue: String) { self.init(rawValue: bridgeValue) }
}

/// 秘密値の保存先はRNホストに限定する。Expo/JS境界には値を返さない。
public protocol MemoraSecureCredentialWriting {
  func save(apiKey: String, for provider: MemoraSecureCredentialProvider) throws
  func deleteCredential(for provider: MemoraSecureCredentialProvider) throws
  func isCredentialConfigured(for provider: MemoraSecureCredentialProvider) throws -> Bool
}

public enum MemoraSecureCredentialError: LocalizedError {
  case unavailable
  case invalidInput
  case presentationUnavailable

  public var errorDescription: String? {
    switch self {
    case .unavailable: return "APIキーを安全に保存できませんでした。"
    case .invalidInput: return "APIキーを入力してください。"
    case .presentationUnavailable: return "APIキー入力画面を表示できませんでした。"
    }
  }
}

public enum MemoraNativeSecureCredentialRegistry {
  public static var writer: any MemoraSecureCredentialWriting = MemoraUnavailableSecureCredentialWriter()
}

public struct MemoraUnavailableSecureCredentialWriter: MemoraSecureCredentialWriting {
  public init() {}
  public func save(apiKey: String, for provider: MemoraSecureCredentialProvider) throws { throw MemoraSecureCredentialError.unavailable }
  public func deleteCredential(for provider: MemoraSecureCredentialProvider) throws { throw MemoraSecureCredentialError.unavailable }
  public func isCredentialConfigured(for provider: MemoraSecureCredentialProvider) throws -> Bool { false }
}

@MainActor
public final class MemoraSecureCredentialInputPresenter {
  public init() {}

  public func present(provider: MemoraSecureCredentialProvider, from viewController: UIViewController?) async throws -> Bool {
    guard let viewController else { throw MemoraSecureCredentialError.presentationUnavailable }
    return try await withCheckedThrowingContinuation { continuation in
      let alert = UIAlertController(
        title: "\(provider.rawValue) のAPIキー",
        message: "この端末のキーチェーンにのみ安全に保存されます。",
        preferredStyle: .alert
      )
      alert.addTextField { textField in
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.isSecureTextEntry = true
        textField.placeholder = "APIキー"
      }
      alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
        continuation.resume(returning: false)
      })
      alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
        let apiKey = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !apiKey.isEmpty else {
          continuation.resume(throwing: MemoraSecureCredentialError.invalidInput)
          return
        }
        do {
          try MemoraNativeSecureCredentialRegistry.writer.save(apiKey: apiKey, for: provider)
          continuation.resume(returning: true)
        } catch {
          continuation.resume(throwing: MemoraSecureCredentialError.unavailable)
        }
      })
      viewController.present(alert, animated: true)
    }
  }
}
