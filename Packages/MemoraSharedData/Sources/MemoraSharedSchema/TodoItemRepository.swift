import Foundation
import SwiftData

// MARK: - Protocol

public protocol TodoItemRepositoryProtocol {
    func fetchAll() throws -> [TodoItem]
    func fetch(id: UUID) throws -> TodoItem?
    func save(_ item: TodoItem) throws
    func delete(_ item: TodoItem) throws
    func delete(id: UUID) throws
    func setCompleted(id: UUID, isCompleted: Bool) throws -> TodoItem?
}

// MARK: - Implementation

public final class TodoItemRepository: TodoItemRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetch(id: UUID) throws -> TodoItem? {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func save(_ item: TodoItem) throws {
        if let existing = try fetch(id: item.id) {
            existing.title = item.title
            existing.notes = item.notes
            existing.assignee = item.assignee
            existing.speaker = item.speaker
            existing.priority = item.priority
            existing.dueDate = item.dueDate
            existing.relativeDueDate = item.relativeDueDate
            existing.projectID = item.projectID
            existing.parentID = item.parentID
            existing.sourceAudioFileID = item.sourceAudioFileID
            existing.isCompleted = item.isCompleted
            existing.completedAt = item.completedAt
        } else {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    public func delete(_ item: TodoItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let item = try fetch(id: id) else { return }
        try delete(item)
    }

    public func setCompleted(id: UUID, isCompleted: Bool) throws -> TodoItem? {
        guard let item = try fetch(id: id) else { return nil }
        item.isCompleted = isCompleted
        item.completedAt = isCompleted ? Date() : nil
        try modelContext.save()
        return item
    }
}
