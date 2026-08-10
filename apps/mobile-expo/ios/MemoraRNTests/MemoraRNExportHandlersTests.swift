import Foundation
import Testing
@testable import MemoraRN
internal import MemoraNative

private struct FixedNotionTokenReader: MemoraRNNotionTokenReading {
  let token: String?

  func notionToken() throws -> String? { token }
}

private struct ExportSettingsStoreStub: MemoraSettingsReadingWriting {
  let sourceDescription = "memory"
  let parentPage: String

  func loadSettings() throws -> MemoraSettingsDTO {
    MemoraSettingsDTO(
      transcriptionMode: "local",
      summaryProvider: "Gemini",
      speechAnalyzerEnabled: false,
      notionParentPage: parentPage
    )
  }

  func saveSettings(_ settings: MemoraSettingsDTO) throws {}
}

@Suite("RN export handlers")
struct MemoraRNExportHandlersTests {
  @Test("親ページURLから32文字hexのページIDを抽出する")
  func extractsPageIDFromURL() throws {
    #expect(
      MemoraRNExportHandler.extractPageID(
        from: "https://www.notion.so/My-Page-0123456789abcdef0123456789abcdef?pvs=4"
      ) == "0123456789abcdef0123456789abcdef"
    )
  }

  @Test("ページIDのみの入力もそのまま扱う")
  func extractsPageIDFromBareID() throws {
    #expect(MemoraRNExportHandler.extractPageID(from: "0123456789abcdef0123456789abcdef") == "0123456789abcdef0123456789abcdef")
  }

  @Test("ページIDを識別できない入力は nil を返す")
  func rejectsInvalidParentPage() throws {
    #expect(MemoraRNExportHandler.extractPageID(from: "https://www.notion.so/My-Page") == nil)
    #expect(MemoraRNExportHandler.extractPageID(from: "") == nil)
    #expect(MemoraRNExportHandler.extractPageID(from: "short-id") == nil)
  }

  @Test("見出し区切りから見出し＋本文ブロックを組み立てる")
  func buildsNotionBlocks() throws {
    let blocks = MemoraRNExportHandler.makeBlocks(text: """
    ## 要約

    まとめ本文

    ## 文字起こし

    00:00 こんにちは
    00:02 よろしくお願いします
    """)

    #expect(blocks.count == 4)
    #expect(blocks[0]["type"] as? String == "heading_2")
    #expect((blocks[0]["heading_2"] as? [String: Any])?["rich_text"] != nil)
    #expect(blocks[1]["type"] as? String == "paragraph")
    #expect(blocks[2]["type"] as? String == "heading_2")
    #expect(blocks[3]["type"] as? String == "paragraph")
  }

  @Test("本文が長い場合は children 上限内に収まるよう分割する")
  func splitsLongTranscriptIntoParagraphs() throws {
    let longLine = String(repeating: "あ", count: 1900)
    let blocks = MemoraRNExportHandler.makeBlocks(text: """
    ## 要約

    要点

    ## 文字起こし

    \(longLine)
    \(longLine)
    """)

    #expect(blocks.count <= 100)
    let paragraphs = blocks.filter { $0["type"] as? String == "paragraph" }
    #expect(paragraphs.count >= 3)
    for block in paragraphs {
      let body = (block["paragraph"] as? [String: Any])?["rich_text"] as? [[String: Any]]
      let content = body?.first?["text"] as? [String: Any]
      let text = content?["content"] as? String ?? ""
      #expect(text.count <= 1800)
    }
  }

  @Test("要約や文字起こしが空の見出しはブロック化しない")
  func skipsEmptySections() throws {
    let blocks = MemoraRNExportHandler.makeBlocks(text: """
    ## 要約


    ## 文字起こし

    00:00 本文のみ
    """)
    #expect(blocks.count == 2)
    #expect(blocks[0]["type"] as? String == "heading_2")
    #expect(blocks[1]["type"] as? String == "paragraph")
  }

  @Test("トークン未設定は明示エラーを返す")
  @MainActor
  func missingTokenReturnsClearError() async throws {
    let handler = MemoraRNExportHandler(
      keychain: FixedNotionTokenReader(token: nil),
      settingsStore: ExportSettingsStoreStub(parentPage: "https://www.notion.so/My-Page-0123456789abcdef0123456789abcdef")
    )
    let payload = MemoraExportPayloadDTO(dictionary: [
      "title": "タイトル",
      "text": "## 要約\n\n本文",
      "sourceFileId": "file-1",
      "destination": "notion"
    ])

    do {
      _ = try await handler.export(payload)
      Issue.record("トークン未設定はエラーである必要があります")
    } catch {
      #expect(error.localizedDescription == MemoraRNExportError.tokenUnavailable.localizedDescription)
    }
  }

  @Test("親ページ未設定は明示エラーを返す")
  @MainActor
  func missingParentPageReturnsClearError() async throws {
    let handler = MemoraRNExportHandler(
      keychain: FixedNotionTokenReader(token: "ntn_test_token"),
      settingsStore: ExportSettingsStoreStub(parentPage: "")
    )
    let payload = MemoraExportPayloadDTO(dictionary: [
      "title": "タイトル",
      "text": "## 要約\n\n本文",
      "sourceFileId": "file-1",
      "destination": "notion"
    ])

    do {
      _ = try await handler.export(payload)
      Issue.record("親ページ未設定はエラーである必要があります")
    } catch {
      #expect(error.localizedDescription == MemoraRNExportError.parentPageUnavailable.localizedDescription)
    }
  }

  @Test("親ページIDが不正なら明示エラーを返す")
  @MainActor
  func invalidParentPageReturnsClearError() async throws {
    let handler = MemoraRNExportHandler(
      keychain: FixedNotionTokenReader(token: "ntn_test_token"),
      settingsStore: ExportSettingsStoreStub(parentPage: "https://www.notion.so/Not-A-Page")
    )
    let payload = MemoraExportPayloadDTO(dictionary: [
      "title": "タイトル",
      "text": "## 要約\n\n本文",
      "sourceFileId": "file-1",
      "destination": "notion"
    ])

    do {
      _ = try await handler.export(payload)
      Issue.record("親ページID不正はエラーである必要があります")
    } catch {
      #expect(error.localizedDescription == MemoraRNExportError.invalidParentPage.localizedDescription)
    }
  }

  @Test("ExportPayloadDTO は辞書から目的地を正しく解決する")
  func payloadDTOReadsDictionary() throws {
    let payload = MemoraExportPayloadDTO(dictionary: [
      "title": "タイトル",
      "text": "本文",
      "createdAt": "2026-08-10T00:00:00Z",
      "sourceFileId": "file-1",
      "destination": "chatgpt"
    ])
    #expect(payload.title == "タイトル")
    #expect(payload.sourceFileId == "file-1")
    #expect(payload.destination == .chatgpt)
    #expect(payload.createdAt == "2026-08-10T00:00:00Z")
  }

  @Test("export の失敗理由にトークン文字列は含まれない")
  @MainActor
  func errorMessageNeverLeaksToken() async throws {
    let secret = "ntn_secret_not_for_logs"
    let handler = MemoraRNExportHandler(
      keychain: FixedNotionTokenReader(token: secret),
      settingsStore: ExportSettingsStoreStub(parentPage: "")
    )
    let payload = MemoraExportPayloadDTO(dictionary: [
      "title": "タイトル",
      "text": "本文",
      "sourceFileId": "file-1",
      "destination": "notion"
    ])

    do {
      _ = try await handler.export(payload)
      Issue.record("親ページ未設定はエラーである必要があります")
    } catch {
      #expect(error.localizedDescription.contains(secret) == false)
    }
  }
}
