import Foundation
import SwiftData

// MARK: - Protocol

protocol TranscriptRepositoryProtocol {
    func fetch(audioFileId: UUID) throws -> Transcript?
    func save(_ transcript: Transcript) throws
    func delete(_ transcript: Transcript) throws
    func deleteByAudioFile(id: UUID) throws
}

// MARK: - Implementation

final class TranscriptRepository: TranscriptRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(audioFileId: UUID) throws -> Transcript? {
        let descriptor = FetchDescriptor<Transcript>(
            predicate: #Predicate { $0.audioFileID == audioFileId }
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

    func deleteByAudioFile(id: UUID) throws {
        if let transcript = try fetch(audioFileId: id) {
            try delete(transcript)
        }
    }
}
