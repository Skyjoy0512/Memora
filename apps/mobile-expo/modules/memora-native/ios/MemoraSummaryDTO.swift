import Foundation

public struct MemoraSummaryOptionsDTO {
  public let provider: String
  public let templateId: String?

  public init(dictionary: [String: Any]) {
    self.provider = dictionary["provider"] as? String ?? "Local"
    self.templateId = dictionary["templateId"] as? String
  }
}

public struct MemoraSummaryRequestDTO {
  public let audioFileId: String
  public let options: MemoraSummaryOptionsDTO

  public init(dictionary: [String: Any]) {
    self.audioFileId = dictionary["audioFileId"] as? String ?? ""
    self.options = MemoraSummaryOptionsDTO(
      dictionary: dictionary["options"] as? [String: Any] ?? [:]
    )
  }
}

public struct MemoraSummaryDTO {
  public let audioFileId: String
  public let text: String
  public let generatedAt: Date
  public let provider: String

  public init(audioFileId: String, text: String, generatedAt: Date, provider: String) {
    self.audioFileId = audioFileId
    self.text = text
    self.generatedAt = generatedAt
    self.provider = provider
  }

  public func asDictionary() -> [String: Any] {
    [
      "audioFileId": audioFileId,
      "text": text,
      "generatedAt": ISO8601DateFormatter().string(from: generatedAt),
      "provider": provider
    ]
  }
}

public protocol MemoraSummaryGenerating {
  var sourceDescription: String { get }

  func generateSummary(_ request: MemoraSummaryRequestDTO) async throws -> MemoraSummaryDTO
}

public enum MemoraNativeSummaryRegistry {
  public static var summaryGenerator: MemoraSummaryGenerating = MemoraUnavailableSummaryGenerator()
}

public struct MemoraUnavailableSummaryGenerator: MemoraSummaryGenerating {
  public let sourceDescription = "native"

  public init() {}

  public func generateSummary(_ request: MemoraSummaryRequestDTO) async throws -> MemoraSummaryDTO {
    throw MemoraSummaryBridgeError.sharedStoreUnavailable
  }
}

public enum MemoraSummaryBridgeError: LocalizedError {
  case sharedStoreUnavailable

  public var errorDescription: String? {
    switch self {
    case .sharedStoreUnavailable:
      return "要約を利用できません。データストアに接続してからもう一度お試しください。"
    }
  }
}
