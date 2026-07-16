import Foundation
import SwiftData
import Testing
@testable import MemoraRN
internal import MemoraNative
import MemoraSharedCore
import MemoraSharedSchema

private struct SecretFailingKeyReader: MemoraRNSummaryKeyReading {
  let secret: String

  func apiKey(for provider: MemoraRNSummaryProvider) throws -> String? {
    throw SyntheticKeychainError.message(secret)
  }
}

private enum SyntheticKeychainError: Error {
  case message(String)
}

private struct FixedKeyReader: MemoraRNSummaryKeyReading {
  func apiKey(for provider: MemoraRNSummaryProvider) throws -> String? { "native-only-test-key" }
}

private struct SummaryProviderStub: LLMProvider {
  let displayName = "Test"

  func generate(_ prompt: String) async throws -> String { "" }

  func summarize(transcript: String) async throws -> LLMProviderSummary {
    LLMProviderSummary(
      title: "テスト要約",
      summary: "共有要約コアの結果",
      keyPoints: ["要点"],
      actionItems: ["対応"]
    )
  }
}

@Suite("RN summary bridge security")
struct MemoraSummaryBridgeSecurityTests {
  @Test("Keychain失敗とDTOは秘密文字列をJS境界へ出さない")
  @MainActor
  func doesNotExposeAPIKey() async throws {
    let secret = "rn-summary-test-secret-not-for-js"
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-rn-summary-security-\(UUID().uuidString).store")
    defer { try? FileManager.default.removeItem(at: storeURL) }

    let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
    let context = ModelContext(container)
    let audioFile = AudioFile(title: "Security test", audioURL: "/tmp/security.m4a")
    let transcript = Transcript(audioFileID: audioFile.id, text: "文字起こし")
    transcript.audioFile = audioFile
    context.insert(audioFile)
    context.insert(transcript)
    try context.save()

    let generator = MemoraSharedStoreSummaryGenerator(
      container: container,
      keyReader: SecretFailingKeyReader(secret: secret)
    )
    let request = MemoraSummaryRequestDTO(dictionary: [
      "audioFileId": audioFile.id.uuidString,
      "options": ["provider": "Gemini"]
    ])

    do {
      _ = try await generator.generateSummary(request)
      Issue.record("Keychain読み取り失敗は明示エラーである必要があります")
    } catch {
      #expect(error.localizedDescription.contains(secret) == false)
      #expect(error.localizedDescription == MemoraRNSummaryError.apiKeyUnavailable.localizedDescription)
    }

    let dto = MemoraSummaryDTO(
      audioFileId: audioFile.id.uuidString,
      text: "要約本文",
      generatedAt: Date(timeIntervalSince1970: 0),
      provider: "Gemini"
    ).asDictionary()
    #expect(dto.values.contains { "\($0)".contains(secret) } == false)
  }

  @Test("共有要約結果をSwiftDataへ保存する")
  @MainActor
  func savesGeneratedSummary() async throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-rn-summary-save-\(UUID().uuidString).store")
    defer { try? FileManager.default.removeItem(at: storeURL) }

    let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
    let context = ModelContext(container)
    let audioFile = AudioFile(title: "Save test", audioURL: "/tmp/save.m4a")
    let transcript = Transcript(audioFileID: audioFile.id, text: "保存対象の文字起こし")
    transcript.audioFile = audioFile
    context.insert(audioFile)
    context.insert(transcript)
    try context.save()

    let generator = MemoraSharedStoreSummaryGenerator(
      container: container,
      keyReader: FixedKeyReader(),
      providerFactory: { _, _ in SummaryProviderStub() }
    )
    let result = try await generator.generateSummary(MemoraSummaryRequestDTO(dictionary: [
      "audioFileId": audioFile.id.uuidString,
      "options": ["provider": "Gemini"]
    ]))

    #expect(result.text == "共有要約コアの結果")
    #expect(audioFile.summary == "共有要約コアの結果")
    #expect(audioFile.keyPoints == "要点")
    #expect(audioFile.actionItems == "対応")
    #expect(audioFile.isSummarized)
  }
}
