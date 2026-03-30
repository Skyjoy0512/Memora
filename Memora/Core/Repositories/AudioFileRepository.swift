import Foundation
import SwiftData

// MARK: - Protocol

protocol AudioFileRepositoryProtocol {
    func fetchAll() throws -> [AudioFile]
    func fetch(id: UUID) throws -> AudioFile?
    func save(_ file: AudioFile) throws
    func delete(_ file: AudioFile) throws
    func delete(id: UUID) throws
    func fetchByProject(_ projectId: UUID) throws -> [AudioFile]
    func fetchTranscribed() throws -> [AudioFile]
    func search(query: String) throws -> [AudioFile]
}

// MARK: - Implementation

final class AudioFileRepository: AudioFileRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
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

    func delete(id: UUID) throws {
        guard let file = try fetch(id: id) else { return }
        try delete(file)
    }

    func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.projectID == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTranscribed() throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.isTranscribed },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func search(query: String) throws -> [AudioFile] {
        let allFiles = try fetchAll()
        let lowered = query.lowercased()
        return allFiles.filter { $0.title.lowercased().contains(lowered) }
    }
}
