import Foundation
import SwiftData

protocol JobRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [ProcessingJob]
    func fetch(id: UUID) async throws -> ProcessingJob?
    func fetchByAudioFile(_ audioFileId: UUID) async throws -> [ProcessingJob]
    func save(_ job: ProcessingJob) async throws
    func saveChunk(_ chunk: ProcessingChunk) async throws
    func delete(_ job: ProcessingJob) async throws
}

final class JobRepository: JobRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [ProcessingJob] {
            let descriptor = FetchDescriptor<ProcessingJob>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> ProcessingJob? {
            let descriptor = FetchDescriptor<ProcessingJob>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func fetchByAudioFile(_ audioFileId: UUID) throws -> [ProcessingJob] {
            let descriptor = FetchDescriptor<ProcessingJob>(
                predicate: #Predicate { $0.audioFile?.id == audioFileId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func save(_ job: ProcessingJob) throws {
            modelContext.insert(job)
            try modelContext.save()
        }

        func saveChunk(_ chunk: ProcessingChunk) throws {
            modelContext.insert(chunk)
            try modelContext.save()
        }

        func delete(_ job: ProcessingJob) throws {
            modelContext.delete(job)
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [ProcessingJob] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> ProcessingJob? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func fetchByAudioFile(_ audioFileId: UUID) async throws -> [ProcessingJob] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByAudioFile(audioFileId)
    }

    func save(_ job: ProcessingJob) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(job)
    }

    func saveChunk(_ chunk: ProcessingChunk) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.saveChunk(chunk)
    }

    func delete(_ job: ProcessingJob) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(job)
    }
}
