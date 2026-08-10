import Foundation
import UIKit
internal import MemoraNative

enum MemoraRNExportError: LocalizedError {
  case tokenUnavailable
  case parentPageUnavailable
  case invalidParentPage
  case network
  case invalidResponse
  case notionAPI(message: String)
  case contentTooLong

  var errorDescription: String? {
    switch self {
    case .tokenUnavailable:
      return "Notionの接続トークンが設定されていません。設定画面から入力してください。"
    case .parentPageUnavailable:
      return "Notionの書き出し先（親ページ）が設定されていません。設定画面から指定してください。"
    case .invalidParentPage:
      return "Notionの親ページを識別できません。ページURLまたはページIDを確認してください。"
    case .network:
      return "Notionへの接続に失敗しました。通信環境を確認して、もう一度お試しください。"
    case .invalidResponse:
      return "Notionの応答を解析できませんでした。"
    case .notionAPI(let message):
      return message
    case .contentTooLong:
      return "内容が長すぎてNotionの上限（100ブロック）に収まりません。"
    }
  }
}

/// Notion / ChatGPT の書き出しを実行する RN ホスト実装。
/// Integration token は Keychain（RNホスト内）からのみ読み、JS 境界には返さない。
@MainActor
final class MemoraRNExportHandler: MemoraExporting {
  let sourceDescription = "native"

  private static let notionEndpoint = URL(string: "https://api.notion.com/v1/pages")!
  private static let notionVersion = "2022-06-28"
  private static let maxChildrenCount = 100
  private static let maxParagraphChars = 1800

  private let keychain: any MemoraRNNotionTokenReading
  private let settingsStore: any MemoraSettingsReadingWriting
  private let session: URLSession
  private let topViewControllerProvider: @MainActor () -> UIViewController?

  init(
    keychain: any MemoraRNNotionTokenReading,
    settingsStore: any MemoraSettingsReadingWriting,
    session: URLSession = URLSession.shared,
    topViewControllerProvider: (@MainActor () -> UIViewController?)? = nil
  ) {
    self.keychain = keychain
    self.settingsStore = settingsStore
    self.session = session
    self.topViewControllerProvider = topViewControllerProvider ?? { MemoraRNExportHandler.topViewController() }
  }

  func export(_ payload: MemoraExportPayloadDTO) async throws -> MemoraExportResultDTO {
    switch payload.destination {
    case .notion:
      return try await exportToNotion(payload)
    case .chatgpt:
      return try await exportToChatGPT(payload)
    case .file:
      throw MemoraExportBridgeError.unsupportedDestination
    }
  }

  // MARK: - Notion

  private func exportToNotion(_ payload: MemoraExportPayloadDTO) async throws -> MemoraExportResultDTO {
    guard let token = try keychain.notionToken(), !token.isEmpty else {
      throw MemoraRNExportError.tokenUnavailable
    }

    let settings = try settingsStore.loadSettings()
    let parentPage = settings.notionParentPage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !parentPage.isEmpty else {
      throw MemoraRNExportError.parentPageUnavailable
    }
    guard let parentPageID = Self.extractPageID(from: parentPage) else {
      throw MemoraRNExportError.invalidParentPage
    }

    let blocks = Self.makeBlocks(text: payload.text)
    guard blocks.count <= Self.maxChildrenCount else {
      throw MemoraRNExportError.contentTooLong
    }

    var request = URLRequest(url: Self.notionEndpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(Self.notionVersion, forHTTPHeaderField: "Notion-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "parent": ["type": "page_id", "page_id": parentPageID],
      "properties": [
        "title": ["title": [["type": "text", "text": ["content": payload.title]]]]
      ],
      "children": blocks
    ])

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw MemoraRNExportError.network
    }

    guard let http = response as? HTTPURLResponse else {
      throw MemoraRNExportError.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
      throw MemoraRNExportError.notionAPI(
        message: Self.apiErrorMessage(data: data, statusCode: http.statusCode)
      )
    }

    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let pageID = object?["id"] as? String else {
      throw MemoraRNExportError.invalidResponse
    }
    return MemoraExportResultDTO(ok: true, destination: .notion, refId: pageID)
  }

  // MARK: - ChatGPT

  private func exportToChatGPT(_ payload: MemoraExportPayloadDTO) async throws -> MemoraExportResultDTO {
    UIPasteboard.general.string = payload.text
    if let presenter = topViewControllerProvider() {
      let activityViewController = UIActivityViewController(activityItems: [payload.text], applicationActivities: nil)
      activityViewController.popoverPresentationController?.sourceView = presenter.view
      presenter.present(activityViewController, animated: true)
    }
    return MemoraExportResultDTO(ok: true, destination: .chatgpt)
  }

  // MARK: - Pure helpers (testable)

  /// 親ページURL / ページIDから32文字hexのページIDを抽出する。
  nonisolated static func extractPageID(from input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = #"[0-9a-f]{32}"#
    guard let range = trimmed.range(
      of: pattern,
      options: [.regularExpression, .caseInsensitive],
      range: nil,
      locale: nil
    ) else {
      return nil
    }
    return String(trimmed[range]).lowercased()
  }

  /// `## 要約` / `## 文字起こし` の見出し区切りから Notion block 配列を組み立てる。
  nonisolated static func makeBlocks(text: String) -> [[String: Any]] {
    var sections: [(heading: String, content: String)] = []
    var currentHeading: String?
    var currentLines: [String] = []
    let headingMarkers = Set(["## 要約", "## 文字起こし"])

    for line in text.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if headingMarkers.contains(trimmed) {
        if let heading = currentHeading {
          sections.append((heading, currentLines.joined(separator: "\n")))
        }
        currentHeading = trimmed.replacingOccurrences(of: "## ", with: "")
        currentLines = []
      } else {
        currentLines.append(line)
      }
    }
    if let heading = currentHeading {
      sections.append((heading, currentLines.joined(separator: "\n")))
    }

    var blocks: [[String: Any]] = []
    for section in sections {
      let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
      if content.isEmpty { continue }
      blocks.append(block(type: "heading_2", text: section.heading))
      for paragraph in chunkText(content, maxChars: maxParagraphChars) {
        blocks.append(block(type: "paragraph", text: paragraph))
      }
    }
    return blocks
  }

  /// 行単位で maxChars を超えない段落に分割する（超過する単一行は強制分割）。
  nonisolated static func chunkText(_ text: String, maxChars: Int) -> [String] {
    var chunks: [String] = []
    for line in text.components(separatedBy: "\n") {
      var remaining = line
      while remaining.count > maxChars {
        let index = remaining.index(remaining.startIndex, offsetBy: maxChars)
        chunks.append(String(remaining[..<index]))
        remaining = String(remaining[index...])
      }
      if remaining.isEmpty { continue }
      if let last = chunks.last, last.count + remaining.count + 1 <= maxChars {
        chunks[chunks.count - 1] = last + "\n" + remaining
      } else {
        chunks.append(remaining)
      }
    }
    return chunks
  }

  nonisolated private static func block(type: String, text: String) -> [String: Any] {
    [
      "object": "block",
      "type": type,
      type: ["rich_text": [["type": "text", "text": ["content": text]]]]
    ]
  }

  private static func apiErrorMessage(data: Data, statusCode: Int) -> String {
    if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let message = object["message"] as? String, !message.isEmpty {
      return "NotionのAPIエラー（\(statusCode)）: \(message)"
    }
    return "Notionへの書き出しに失敗しました（HTTP \(statusCode)）。"
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
    let root = scene?.keyWindow?.rootViewController
      ?? scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    return presentedViewController(of: root)
  }

  private static func presentedViewController(of base: UIViewController?) -> UIViewController? {
    if let navigationController = base as? UINavigationController {
      return presentedViewController(of: navigationController.visibleViewController)
    }
    if let tabBarController = base as? UITabBarController {
      return presentedViewController(of: tabBarController.selectedViewController)
    }
    if let presented = base?.presentedViewController {
      return presentedViewController(of: presented)
    }
    return base
  }
}
