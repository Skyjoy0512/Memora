import Foundation
import SwiftData

protocol TodoRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [TodoItem]
    func fetch(id: UUID) async throws -> TodoItem?
    func fetchByProject(_ projectId: UUID) async throws -> [TodoItem]
    func fetchBySourceFile(_ sourceFileId: UUID) async throws -> [TodoItem]
    func save(_ todo: TodoItem) async throws
    func delete(_ todo: TodoItem) async throws
    func toggleCompleted(id: UUID, completed: Bool) async throws
}

final class TodoRepository: TodoRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
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

        func fetchByProject(_ projectId: UUID) throws -> [TodoItem] {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.projectId == projectId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetchBySourceFile(_ sourceFileId: UUID) throws -> [TodoItem] {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.sourceFileId == sourceFileId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func save(_ todo: TodoItem) throws {
            modelContext.insert(todo)
            try modelContext.save()
        }

        func delete(_ todo: TodoItem) throws {
            modelContext.delete(todo)
            try modelContext.save()
        }

        func toggleCompleted(id: UUID, completed: Bool) throws {
            let descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate { $0.id == id }
            )
            guard let todo = try modelContext.fetch(descriptor).first else { return }
            todo.isCompleted = completed
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [TodoItem] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> TodoItem? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func fetchByProject(_ projectId: UUID) async throws -> [TodoItem] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByProject(projectId)
    }

    func fetchBySourceFile(_ sourceFileId: UUID) async throws -> [TodoItem] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchBySourceFile(sourceFileId)
    }

    func save(_ todo: TodoItem) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(todo)
    }

    func delete(_ todo: TodoItem) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(todo)
    }

    func toggleCompleted(id: UUID, completed: Bool) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.toggleCompleted(id: id, completed: completed)
    }
}
