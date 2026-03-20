import Foundation
import SwiftData

protocol AttachmentRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Attachment]
    func fetch(id: UUID) async throws -> Attachment?
    func fetchByAudioFile(_ audioFileId: UUID) async throws -> [Attachment]
    func save(_ attachment: Attachment) async throws
    func delete(_ attachment: Attachment) async throws
}

final class AttachmentRepository: AttachmentRepositoryProtocol {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer = SwiftDataStack.shared.modelContainer) {
        self.modelContainer = modelContainer
    }

    @ModelActor
    actor Worker {
        func fetchAll() throws -> [Attachment] {
            let descriptor = FetchDescriptor<Attachment>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func fetch(id: UUID) throws -> Attachment? {
            let descriptor = FetchDescriptor<Attachment>(
                predicate: #Predicate { $0.id == id }
            )
            return try modelContext.fetch(descriptor).first
        }

        func fetchByAudioFile(_ audioFileId: UUID) throws -> [Attachment] {
            let descriptor = FetchDescriptor<Attachment>(
                predicate: #Predicate { $0.audioFile?.id == audioFileId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        }

        func save(_ attachment: Attachment) throws {
            modelContext.insert(attachment)
            try modelContext.save()
        }

        func delete(_ attachment: Attachment) throws {
            modelContext.delete(attachment)
            try modelContext.save()
        }
    }

    func fetchAll() async throws -> [Attachment] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchAll()
    }

    func fetch(id: UUID) async throws -> Attachment? {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetch(id: id)
    }

    func fetchByAudioFile(_ audioFileId: UUID) async throws -> [Attachment] {
        let worker = Worker(modelContainer: modelContainer)
        return try await worker.fetchByAudioFile(audioFileId)
    }

    func save(_ attachment: Attachment) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.save(attachment)
    }

    func delete(_ attachment: Attachment) async throws {
        let worker = Worker(modelContainer: modelContainer)
        try await worker.delete(attachment)
    }
}
