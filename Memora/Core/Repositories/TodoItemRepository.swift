import Foundation
import SwiftData

// MARK: - Protocol

protocol TodoItemRepositoryProtocol {
    func fetchAll() throws -> [TodoItem]
    func fetch(id: UUID) throws -> TodoItem?
    func fetchIncomplete() throws -> [TodoItem]
    func fetchCompleted() throws -> [TodoItem]
    func fetchByProject(_ projectId: UUID) throws -> [TodoItem]
    func save(_ item: TodoItem) throws
    func delete(_ item: TodoItem) throws
    func toggleCompleted(_ item: TodoItem) throws
}

// MARK: - Implementation

final class TodoItemRepository: TodoItemRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> TodoItem? {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchIncomplete() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchCompleted() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByProject(_ projectId: UUID) throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.projectID == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ item: TodoItem) throws {
        modelContext.insert(item)
        try modelContext.save()
    }

    func delete(_ item: TodoItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func toggleCompleted(_ item: TodoItem) throws {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        try modelContext.save()
    }
}
