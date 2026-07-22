import Foundation

public struct MemoraCustomVocabularyDTO {
  public let id: String
  public let pattern: String
  public let replacement: String
  public let reading: String?
  public let enabled: Bool
  public let createdAt: String

  public init(dictionary: [String: Any]) {
    id = dictionary["id"] as? String ?? UUID().uuidString
    pattern = dictionary["pattern"] as? String ?? ""
    replacement = dictionary["replacement"] as? String ?? ""
    reading = dictionary["reading"] as? String
    enabled = dictionary["enabled"] as? Bool ?? true
    createdAt = dictionary["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
  }
  public func asDictionary() -> [String: Any] { ["id": id, "pattern": pattern, "replacement": replacement, "reading": reading ?? NSNull(), "enabled": enabled, "createdAt": createdAt] }
}

public protocol MemoraCustomVocabularyManaging {
  var sourceDescription: String { get }
  func list() throws -> [MemoraCustomVocabularyDTO]
  func save(_ value: MemoraCustomVocabularyDTO) throws -> MemoraCustomVocabularyDTO
  func delete(id: String) throws -> Bool
  func setEnabled(id: String, enabled: Bool) throws -> MemoraCustomVocabularyDTO?
}

public enum MemoraNativeCustomVocabularyRegistry {
  public static var manager: MemoraCustomVocabularyManaging = MemoraSampleCustomVocabularyManager()
}

public final class MemoraSampleCustomVocabularyManager: MemoraCustomVocabularyManaging {
  public let sourceDescription = "memory"
  private var values: [MemoraCustomVocabularyDTO] = []
  public init() {}
  public func list() throws -> [MemoraCustomVocabularyDTO] { values }
  public func save(_ value: MemoraCustomVocabularyDTO) throws -> MemoraCustomVocabularyDTO { values.removeAll { $0.id == value.id }; values.append(value); return value }
  public func delete(id: String) throws -> Bool { let count = values.count; values.removeAll { $0.id == id }; return values.count != count }
  public func setEnabled(id: String, enabled: Bool) throws -> MemoraCustomVocabularyDTO? {
    guard let index = values.firstIndex(where: { $0.id == id }) else { return nil }
    let current = values[index]
    let updated = MemoraCustomVocabularyDTO(dictionary: ["id": current.id, "pattern": current.pattern, "replacement": current.replacement, "reading": current.reading ?? NSNull(), "enabled": enabled, "createdAt": current.createdAt])
    values[index] = updated
    return updated
  }
}
