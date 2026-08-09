import Foundation
import SwiftData
import Testing
@testable import MemoraSharedSchema

@Suite("TodoItem repository")
struct TodoItemRepositoryTests {
  private func makeRepository() throws -> (TodoItemRepository, ModelContainer) {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: configuration
    )
    return (TodoItemRepository(modelContext: ModelContext(container)), container)
  }

  @Test("in-memory TodoItem repository supports create, read, update, and delete")
  func todoItemRepositoryCRUD() throws {
    let (repository, _) = try makeRepository()
    let item = TodoItem(title: "議事録を送る", notes: "会議後に対応", dueDate: Date())

    try repository.save(item)
    #expect(try repository.fetchAll().map(\.id) == [item.id])
    #expect(try repository.fetch(id: item.id)?.title == "議事録を送る")

    item.isCompleted = true
    item.completedAt = Date()
    try repository.save(item)
    let updated = try #require(try repository.fetch(id: item.id))
    #expect(updated.isCompleted)
    #expect(updated.completedAt != nil)

    try repository.delete(id: item.id)
    #expect(try repository.fetch(id: item.id) == nil)
  }

  @Test("saving an existing ID updates the persisted row instead of duplicating it")
  func todoItemSaveUpsertsById() throws {
    let (repository, _) = try makeRepository()
    let item = TodoItem(title: "最初のタイトル")

    try repository.save(item)
    item.title = "更新後のタイトル"
    try repository.save(item)

    #expect(try repository.fetchAll().count == 1)
    #expect(try repository.fetch(id: item.id)?.title == "更新後のタイトル")
  }

  @Test("setCompleted toggles isCompleted and completedAt")
  func todoItemSetCompleted() throws {
    let (repository, _) = try makeRepository()
    let item = TodoItem(title: "完了トグル対象")

    try repository.save(item)
    let completed = try #require(try repository.setCompleted(id: item.id, isCompleted: true))
    #expect(completed.isCompleted)
    #expect(completed.completedAt != nil)

    let reopened = try #require(try repository.setCompleted(id: item.id, isCompleted: false))
    #expect(!reopened.isCompleted)
    #expect(reopened.completedAt == nil)

    #expect(try repository.setCompleted(id: UUID(), isCompleted: true) == nil)
  }
}
