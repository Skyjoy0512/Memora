import Foundation
import SwiftData

// MARK: - Protocol

protocol MeetingNoteRepositoryProtocol {
    func fetch(audioFileId: UUID) throws -> MeetingNote?
    func save(_ note: MeetingNote) throws
    func delete(_ note: MeetingNote) throws
    func deleteByAudioFile(id: UUID) throws
    func update(_ note: MeetingNote, summary: String?, decisions: [String], actionItems: [String]) throws
}

// MARK: - Implementation

final class MeetingNoteRepository: MeetingNoteRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(audioFileId: UUID) throws -> MeetingNote? {
        let descriptor = FetchDescriptor<MeetingNote>(
            predicate: #Predicate { $0.audioFileID == audioFileId }
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

    func deleteByAudioFile(id: UUID) throws {
        if let note = try fetch(audioFileId: id) {
            try delete(note)
        }
    }

    func update(_ note: MeetingNote, summary: String?, decisions: [String], actionItems: [String]) throws {
        note.summary = summary
        note.decisions = decisions
        note.actionItems = actionItems
        note.updatedAt = Date()
        try modelContext.save()
    }
}
