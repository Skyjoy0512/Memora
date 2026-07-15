import Foundation
import SwiftData

// MARK: - Protocol

public protocol AudioFileRepositoryProtocol {
    func fetchAll() throws -> [AudioFile]
    func fetchPage(offset: Int, limit: Int) throws -> [AudioFile]
    func fetch(id: UUID) throws -> AudioFile?
    func save(_ file: AudioFile) throws
    func delete(_ file: AudioFile) throws
    func delete(id: UUID) throws
    func fetchByProject(_ projectId: UUID) throws -> [AudioFile]
    func fetchTranscribed() throws -> [AudioFile]
    func search(query: String) throws -> [AudioFile]
}

public extension AudioFileRepositoryProtocol {
    func fetchPage(offset: Int, limit: Int) throws -> [AudioFile] {
        Array(try fetchAll().dropFirst(max(0, offset)).prefix(max(0, limit)))
    }
}

// MARK: - Implementation

public final class AudioFileRepository: AudioFileRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchPage(offset: Int, limit: Int) throws -> [AudioFile] {
        var descriptor = FetchDescriptor<AudioFile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = max(0, offset)
        descriptor.fetchLimit = max(0, limit)
        return try modelContext.fetch(descriptor)
    }

    public func fetch(id: UUID) throws -> AudioFile? {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    public func save(_ file: AudioFile) throws {
        modelContext.insert(file)
        try modelContext.save()
    }

    public func delete(_ file: AudioFile) throws {
        modelContext.delete(file)
        try modelContext.save()
    }

    public func delete(id: UUID) throws {
        guard let file = try fetch(id: id) else { return }
        try delete(file)
    }

    public func fetchByProject(_ projectId: UUID) throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.projectID == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchTranscribed() throws -> [AudioFile] {
        let descriptor = FetchDescriptor<AudioFile>(
            predicate: #Predicate { $0.isTranscribed },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func search(query: String) throws -> [AudioFile] {
        let allFiles = try fetchAll()
        let lowered = query.lowercased()
        return allFiles.filter { $0.title.lowercased().contains(lowered) }
    }
}
