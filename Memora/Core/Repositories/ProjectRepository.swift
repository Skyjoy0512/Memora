import Foundation
import SwiftData

// MARK: - Protocol

protocol ProjectRepositoryProtocol {
    func fetchAll() throws -> [Project]
    func fetch(id: UUID) throws -> Project?
    func save(_ project: Project) throws
    func delete(_ project: Project) throws
    func fileCount(for projectId: UUID) throws -> Int
}

// MARK: - Implementation

final class ProjectRepository: ProjectRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

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

    func fileCount(for projectId: UUID) throws -> Int {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.projectID == projectId }
        )
        return try modelContext.fetchCount(descriptor)
    }
}
