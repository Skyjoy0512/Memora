import Foundation
import SwiftData
internal import MemoraNative
import MemoraSharedCore
import MemoraSharedSchema
import MemoraSharedSummary

/// RNホストだけが読むAI認証情報。値はこのファイル外へ返さない。
protocol MemoraRNSummaryKeyReading {
  func apiKey(for provider: MemoraRNSummaryProvider) throws -> String?
}

enum MemoraRNSummaryProvider: String {
  case openAI = "OpenAI"
  case gemini = "Gemini"
  case deepSeek = "DeepSeek"
  case local = "Local"

  init?(bridgeValue: String) {
    self.init(rawValue: bridgeValue)
  }

}

enum MemoraRNSummaryError: LocalizedError {
  case invalidAudioFileID
  case audioFileNotFound
  case transcriptUnavailable
  case providerUnsupported
  case apiKeyMissing
  case apiKeyUnavailable
  case generationFailed
  case saveFailed

  var errorDescription: String? {
    switch self {
    case .invalidAudioFileID: return "要約対象のファイルを識別できません。"
    case .audioFileNotFound: return "要約対象のファイルが見つかりません。"
    case .transcriptUnavailable: return "文字起こしがないため要約を生成できません。"
    case .providerUnsupported: return "選択した要約プロバイダーは利用できません。"
    case .apiKeyMissing: return "選択したプロバイダーのAPIキーが設定されていません。"
    case .apiKeyUnavailable: return "APIキーを読み取れません。設定を確認してください。"
    case .generationFailed: return "要約の生成に失敗しました。時間をおいてもう一度お試しください。"
    case .saveFailed: return "要約結果を保存できませんでした。"
    }
  }
}

@MainActor
final class MemoraSharedStoreSummaryGenerator: MemoraSummaryGenerating {
  let sourceDescription = "swiftdata"

  private let container: ModelContainer
  private let keyReader: any MemoraRNSummaryKeyReading
  private let providerFactory: (MemoraRNSummaryProvider, String) throws -> any LLMProvider

  init(
    container: ModelContainer,
    keyReader: any MemoraRNSummaryKeyReading = MemoraRNKeychainSecureCredentials(),
    providerFactory: @escaping (MemoraRNSummaryProvider, String) throws -> any LLMProvider = MemoraRNRemoteLLMProvider.make
  ) {
    self.container = container
    self.keyReader = keyReader
    self.providerFactory = providerFactory
  }

  func generateSummary(_ request: MemoraSummaryRequestDTO) async throws -> MemoraSummaryDTO {
    guard let audioFileID = UUID(uuidString: request.audioFileId) else {
      throw MemoraRNSummaryError.invalidAudioFileID
    }
    guard let provider = MemoraRNSummaryProvider(bridgeValue: request.options.provider), provider != .local else {
      throw MemoraRNSummaryError.providerUnsupported
    }

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == audioFileID })
    guard let audioFile = try? context.fetch(descriptor).first else {
      throw MemoraRNSummaryError.audioFileNotFound
    }
    guard let transcript = audioFile.transcripts.first?.text.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty else {
      throw MemoraRNSummaryError.transcriptUnavailable
    }

    let apiKey: String
    do {
      guard let storedKey = try keyReader.apiKey(for: provider), !storedKey.isEmpty else {
        throw MemoraRNSummaryError.apiKeyMissing
      }
      apiKey = storedKey
    } catch let error as MemoraRNSummaryError {
      throw error
    } catch {
      throw MemoraRNSummaryError.apiKeyUnavailable
    }

    let llmProvider: any LLMProvider
    do {
      llmProvider = try providerFactory(provider, apiKey)
    } catch {
      throw MemoraRNSummaryError.providerUnsupported
    }

    let engine = SummarizationEngine()
    engine.configure(provider: llmProvider)
    let result: SummaryResult
    do {
      result = try await engine.summarize(transcript: transcript)
    } catch {
      throw MemoraRNSummaryError.generationFailed
    }

    audioFile.summary = result.summary
    audioFile.keyPoints = result.keyPointsText
    audioFile.actionItems = result.actionItemsText
    audioFile.isSummarized = true
    do {
      try context.save()
    } catch {
      throw MemoraRNSummaryError.saveFailed
    }

    return MemoraSummaryDTO(
      audioFileId: audioFile.id.uuidString,
      text: result.summary,
      generatedAt: Date(),
      provider: provider.rawValue
    )
  }
}

private struct MemoraRNRemoteLLMProvider: LLMProvider {
  let displayName: String
  private let provider: MemoraRNSummaryProvider
  private let apiKey: String
  private let session: URLSession

  static func make(provider: MemoraRNSummaryProvider, apiKey: String) throws -> any LLMProvider {
    switch provider {
    case .openAI, .gemini, .deepSeek:
      return Self(provider: provider, apiKey: apiKey)
    case .local:
      throw MemoraRNSummaryError.providerUnsupported
    }
  }

  private init(provider: MemoraRNSummaryProvider, apiKey: String) {
    self.provider = provider
    self.apiKey = apiKey
    self.displayName = provider.rawValue
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 120
    self.session = URLSession(configuration: configuration)
  }

  func generate(_ prompt: String) async throws -> String {
    try await requestContent(prompt: prompt, includeSummaryInstruction: false)
  }

  func summarize(transcript: String) async throws -> LLMProviderSummary {
    let content = try await requestContent(prompt: Self.summaryPrompt(transcript: transcript), includeSummaryInstruction: true)
    guard let data = content.data(using: .utf8),
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let summary = json["summary"] as? String,
          let keyPoints = json["keyPoints"] as? [String],
          let actionItems = json["actionItems"] as? [String] else {
      throw LLMProviderError.decodingError
    }
    return LLMProviderSummary(
      title: json["title"] as? String,
      summary: summary,
      keyPoints: keyPoints,
      actionItems: actionItems
    )
  }

  private func requestContent(prompt: String, includeSummaryInstruction: Bool) async throws -> String {
    var request: URLRequest
    switch provider {
    case .openAI, .deepSeek:
      let baseURL = provider == .openAI ? "https://api.openai.com/v1" : "https://api.deepseek.com/v1"
      let model = provider == .openAI ? "gpt-4o-mini" : "deepseek-chat"
      request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
      var messages: [[String: String]] = []
      if includeSummaryInstruction {
        messages.append(["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。"])
      }
      messages.append(["role": "user", "content": prompt])
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "model": model,
        "messages": messages,
        "temperature": 0.3,
        "max_tokens": 2048
      ])
    case .gemini:
      var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
      components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
      request = URLRequest(url: components.url!)
      let text = includeSummaryInstruction
        ? "あなたは会議の文字起こしから要約を作成するアシスタントです。\n\n\(prompt)"
        : prompt
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "contents": [["parts": [["text": text]]]],
        "generationConfig": ["temperature": 0.3, "topK": 1, "topP": 1]
      ])
    case .local:
      throw MemoraRNSummaryError.providerUnsupported
    }

    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw LLMProviderError.invalidResponse
    }

    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    if provider == .gemini {
      guard let candidates = object?["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String else {
        throw LLMProviderError.decodingError
      }
      return text
    }
    guard let choices = object?["choices"] as? [[String: Any]],
          let message = choices.first?["message"] as? [String: Any],
          let content = message["content"] as? String else {
      throw LLMProviderError.decodingError
    }
    return content
  }

  private static func summaryPrompt(transcript: String) -> String {
    """
    以下の会議 transcript から、タイトル、要約、重要ポイント、アクションアイテムを抽出してください。
    出力は以下のJSON形式で返してください：

    {
      "title": "会議内容を表す簡潔なタイトル（20字以内）",
      "summary": "会議の要約",
      "keyPoints": ["重要ポイント1", "重要ポイント2"],
      "actionItems": ["アクションアイテム1", "アクションアイテム2"]
    }

    Transcript:
    \(transcript)
    """
  }
}
