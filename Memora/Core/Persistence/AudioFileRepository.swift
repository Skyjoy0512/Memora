import Foundation
import SwiftData

protocol AudioFileRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [AudioFile]
    func fetch(id: UUID) async throws -> AudioFile?
    func save(_ file: AudioFile) async throws
    func delete(_ file: AudioFile) async throws
    func fetchByProject(_ projectId: UUID) async throws -> [AudioFile]
}

final class AudioFileRepository: AudioFileRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [AudioFile] {
            let descriptor = FetchDescriptor<AudioFile>(
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> AudioFile? {
            let descriptor = FetchDescriptor<AudioFile>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func save(_ file: AudioFile) throws {
            modelContext.insert(file)
            try modelContext.save()
        }

        func delete(_ file: AudioFile) throws {
            modelContext.delete(file)
            try modelContext.save()
        }

        func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
            let descriptor = FetchDescriptor<AudioFile>(
                predicate: #Predicate { $0.project?.id == projectId },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }
    }

    func fetchAll() async throws -> [AudioFile] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> AudioFile? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func save(_ file: AudioFile) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(file)
    }

    func delete(_ file: AudioFile) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(file)
    }

    func fetchByProject(_ projectId: UUID) async throws -> [AudioFile] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByProject(projectId)
    }
}
