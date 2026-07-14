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

  func generateSummary(_ request: MemoraSummaryRequestDTO) throws -> MemoraSummaryDTO
}

public enum MemoraNativeSummaryRegistry {
  public static var summaryGenerator: MemoraSummaryGenerating = MemoraSampleSummaryGenerator()
}

public struct MemoraSampleSummaryGenerator: MemoraSummaryGenerating {
  public let sourceDescription = "sample"

  public init() {}

  public func generateSummary(_ request: MemoraSummaryRequestDTO) throws -> MemoraSummaryDTO {
    MemoraSummaryDTO(
      audioFileId: request.audioFileId,
      text: "Native bridge sample summary is ready for the host-app summarizer.",
      generatedAt: Date(),
      provider: request.options.provider
    )
  }
}
