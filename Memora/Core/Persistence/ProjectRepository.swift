import Foundation
import SwiftData

protocol ProjectRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Project]
    func fetch(id: UUID) async throws -> Project?
    func save(_ project: Project) async throws
    func delete(_ project: Project) async throws
}

final class ProjectRepository: ProjectRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [Project] {
            let descriptor = FetchDescriptor<Project>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> Project? {
            let descriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func save(_ project: Project) throws {
            modelContext.insert(project)
            try modelContext.save()
        }

        func delete(_ project: Project) throws {
            modelContext.delete(project)
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [Project] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> Project? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func save(_ project: Project) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(project)
    }

    func delete(_ project: Project) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(project)
    }
}
