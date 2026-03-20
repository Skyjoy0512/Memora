import Foundation
import SwiftData

protocol TranscriptRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Transcript]
    func fetch(id: UUID) async throws -> Transcript?
    func fetchByAudioFile(_ audioFileId: UUID) async throws -> Transcript?
    func save(_ transcript: Transcript) async throws
    func delete(_ transcript: Transcript) async throws
}

final class TranscriptRepository: TranscriptRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [Transcript] {
            let descriptor = FetchDescriptor<Transcript>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> Transcript? {
            let descriptor = FetchDescriptor<Transcript>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func fetchByAudioFile(_ audioFileId: UUID) throws -> Transcript? {
            let descriptor = FetchDescriptor<Transcript>(
                predicate: #Predicate { $0.audioFile?.id == audioFileId }
            )
            return try modelContext.fetch(descriptor).first
        }

        func save(_ transcript: Transcript) throws {
            modelContext.insert(transcript)
            try modelContext.save()
        }

        func delete(_ transcript: Transcript) throws {
            modelContext.delete(transcript)
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [Transcript] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> Transcript? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func fetchByAudioFile(_ audioFileId: UUID) async throws -> Transcript? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByAudioFile(audioFileId)
    }

    func save(_ transcript: Transcript) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(transcript)
    }

    func delete(_ transcript: Transcript) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(transcript)
    }
}
