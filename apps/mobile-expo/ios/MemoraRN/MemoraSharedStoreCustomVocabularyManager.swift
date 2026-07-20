import Foundation
import SwiftData
import MemoraSharedSchema
internal import MemoraNative

final class MemoraSharedStoreCustomVocabularyManager: MemoraCustomVocabularyManaging {
  let sourceDescription = "swiftdata"
  private let container: ModelContainer
  private let formatter = ISO8601DateFormatter()
  init(container: ModelContainer) { self.container = container }
  func list() throws -> [MemoraCustomVocabularyDTO] {
    try ModelContext(container).fetch(FetchDescriptor<CustomVocabulary>()).map(dto)
  }
  func save(_ value: MemoraCustomVocabularyDTO) throws -> MemoraCustomVocabularyDTO {
    let context = ModelContext(container)
    let id = UUID(uuidString: value.id) ?? UUID()
    let descriptor = FetchDescriptor<CustomVocabulary>(predicate: #Predicate { $0.id == id })
    let existing = try context.fetch(descriptor).first
    let model = existing ?? CustomVocabulary(id: id, pattern: value.pattern, replacement: value.replacement, reading: value.reading, enabled: value.enabled)
    model.pattern = value.pattern; model.replacement = value.replacement; model.reading = value.reading; model.enabled = value.enabled
    if existing == nil { context.insert(model) }; try context.save(); return dto(model)
  }
  func delete(id: String) throws -> Bool { guard let uuid = UUID(uuidString: id) else { return false }; let context = ModelContext(container); let d = FetchDescriptor<CustomVocabulary>(predicate: #Predicate { $0.id == uuid }); guard let value = try context.fetch(d).first else { return false }; context.delete(value); try context.save(); return true }
  func setEnabled(id: String, enabled: Bool) throws -> MemoraCustomVocabularyDTO? {
    guard let uuid = UUID(uuidString: id) else { return nil }
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<CustomVocabulary>(predicate: #Predicate { $0.id == uuid })
    guard let value = try context.fetch(descriptor).first else { return nil }
    value.enabled = enabled
    try context.save()
    return dto(value)
  }
  private func dto(_ value: CustomVocabulary) -> MemoraCustomVocabularyDTO { MemoraCustomVocabularyDTO(dictionary: ["id": value.id.uuidString, "pattern": value.pattern, "replacement": value.replacement, "reading": value.reading ?? NSNull(), "enabled": value.enabled, "createdAt": formatter.string(from: value.createdAt)]) }
}
