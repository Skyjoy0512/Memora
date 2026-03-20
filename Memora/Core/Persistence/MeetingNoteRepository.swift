import Foundation
import SwiftData

protocol MeetingNoteRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [MeetingNote]
    func fetch(id: UUID) async throws -> MeetingNote?
    func fetchByAudioFile(_ audioFileId: UUID) async throws -> MeetingNote?
    func save(_ note: MeetingNote) async throws
    func delete(_ note: MeetingNote) async throws
}

final class MeetingNoteRepository: MeetingNoteRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [MeetingNote] {
            let descriptor = FetchDescriptor<MeetingNote>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> MeetingNote? {
            let descriptor = FetchDescriptor<MeetingNote>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func fetchByAudioFile(_ audioFileId: UUID) throws -> MeetingNote? {
            let descriptor = FetchDescriptor<MeetingNote>(
                predicate: #Predicate { $0.audioFile?.id == audioFileId }
            )
            return try modelContext.fetch(descriptor).first
        }

        func save(_ note: MeetingNote) throws {
            modelContext.insert(note)
            try modelContext.save()
        }

        func delete(_ note: MeetingNote) throws {
            modelContext.delete(note)
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [MeetingNote] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> MeetingNote? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func fetchByAudioFile(_ audioFileId: UUID) async throws -> MeetingNote? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByAudioFile(audioFileId)
    }

    func save(_ note: MeetingNote) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(note)
    }

    func delete(_ note: MeetingNote) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(note)
    }
}
