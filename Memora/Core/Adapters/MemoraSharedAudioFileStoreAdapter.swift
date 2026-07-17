import Foundation
import MemoraSharedData

/// Bridges the existing app repository to the shared package contract.
/// The RN host can reuse this shape after the shared model target is available.
final class MemoraSharedAudioFileStoreAdapter: MemoraSharedAudioFileStore, @unchecked Sendable {
    let sourceDescription = "swiftdata"

    private let repository: AudioFileRepositoryProtocol

    init(repository: AudioFileRepositoryProtocol) {
        self.repository = repository
    }

    func fetchPage(offset: Int, limit: Int) throws -> [MemoraSharedAudioFileRecord] {
        try repository.fetchPage(offset: offset, limit: limit).map(Self.makeRecord)
    }

    func fetch(id: UUID) throws -> MemoraSharedAudioFileRecord? {
        try repository.fetch(id: id).map(Self.makeRecord)
    }

    func save(_ record: MemoraSharedAudioFileRecord) throws {
        let file: AudioFile
        if let existing = try repository.fetch(id: record.id) {
            file = existing
        } else {
            file = AudioFile(title: record.title, audioURL: record.audioURL, projectID: record.projectID)
            file.id = record.id
        }

        file.title = record.title
        file.projectID = record.projectID
        file.createdAt = record.createdAt
        file.duration = record.duration
        file.audioURL = record.audioURL
        file.segmentPaths = record.segmentPaths
        file.isTranscribed = record.isTranscribed
        file.isSummarized = record.isSummarized
        file.summary = record.summary

        try repository.save(file)
    }

    func delete(id: UUID) throws {
        try repository.delete(id: id)
    }

    private static func makeRecord(from file: AudioFile) -> MemoraSharedAudioFileRecord {
        MemoraSharedAudioFileRecord(
            id: file.id,
            title: file.title,
            projectID: file.projectID,
            createdAt: file.createdAt,
            duration: file.duration,
            audioURL: file.audioURL,
            segmentPaths: file.segmentPaths,
            isTranscribed: file.isTranscribed,
            isSummarized: file.isSummarized,
            summary: file.summary
        )
    }
}
