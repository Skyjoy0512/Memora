import Foundation

public struct MemoraKnowledgeQueryRequestDTO {
  public let scope: String
  public let question: String
  public let audioFileId: String?
  public let projectId: String?
  public let sessionId: String?

  public init(dictionary: [String: Any]) {
    self.scope = dictionary["scope"] as? String ?? "global"
    self.question = dictionary["question"] as? String ?? ""
    self.audioFileId = dictionary["audioFileId"] as? String
    self.projectId = dictionary["projectId"] as? String
    self.sessionId = dictionary["sessionId"] as? String
  }
}

public struct MemoraKnowledgeQueryResponseDTO {
  public let id: String
  public let answer: String
  public let sources: [String]
  public let scope: String
  public let answeredAt: Date
  public let sessionId: String

  public init(id: String, answer: String, sources: [String], scope: String, answeredAt: Date, sessionId: String = UUID().uuidString) {
    self.id = id
    self.answer = answer
    self.sources = sources
    self.scope = scope
    self.answeredAt = answeredAt
    self.sessionId = sessionId
  }

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "answer": answer,
      "sources": sources,
      "scope": scope,
      "answeredAt": ISO8601DateFormatter().string(from: answeredAt)
      , "sessionId": sessionId
    ]
  }
}

public protocol MemoraKnowledgeQuerying {
  var sourceDescription: String { get }

  func queryKnowledge(_ request: MemoraKnowledgeQueryRequestDTO) async throws -> MemoraKnowledgeQueryResponseDTO
}

public enum MemoraNativeKnowledgeQueryRegistry {
  public static var knowledgeQuery: MemoraKnowledgeQuerying = MemoraSampleKnowledgeQuery()
}

public struct MemoraSampleKnowledgeQuery: MemoraKnowledgeQuerying {
  public let sourceDescription = "sample"

  public init() {}

  public func queryKnowledge(_ request: MemoraKnowledgeQueryRequestDTO) async throws -> MemoraKnowledgeQueryResponseDTO {
    let scopedReply = reply(for: request.scope)
    return MemoraKnowledgeQueryResponseDTO(
      id: "native-query-\(UUID().uuidString)",
      answer: scopedReply.answer,
      sources: scopedReply.sources,
      scope: normalizedScope(request.scope),
      answeredAt: Date()
    )
  }

  private func reply(for scope: String) -> (answer: String, sources: [String]) {
    switch normalizedScope(scope) {
    case "file":
      return (
        "このファイルでは、Expo mock UI を先に固めてから native bridge を薄く足す方針が安全です。",
        ["Growth 定例", "File Detail memo"]
      )
    case "project":
      return (
        "プロジェクト全体では、画面レビューとbridge境界の検証を分けて進めるのが次の優先です。",
        ["React Native / Expo Migration Plan", "Bridge Contract"]
      )
    default:
      return (
        "全体横断では、STT保護境界、既存バックエンド維持、Dev Client確認が重要です。",
        ["Migration handoff", "Settings bridge diagnostics"]
      )
    }
  }

  private func normalizedScope(_ scope: String) -> String {
    switch scope {
    case "file", "project", "global":
      return scope
    default:
      return "global"
    }
  }
}
