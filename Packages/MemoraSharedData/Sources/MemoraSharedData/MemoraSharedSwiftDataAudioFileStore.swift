import Foundation
import SwiftData
import MemoraSharedSchema

public final class MemoraSharedSwiftDataAudioFileStore: MemoraSharedAudioFileStore, @unchecked Sendable {
  public let sourceDescription = "swiftdata"
  private let repository: AudioFileRepository
  public init(container: ModelContainer) { repository = AudioFileRepository(modelContext: ModelContext(container)) }
  public func fetchPage(offset: Int, limit: Int) throws -> [MemoraSharedAudioFileRecord] { try repository.fetchPage(offset: offset, limit: limit).map(Self.record) }
  public func fetch(id: UUID) throws -> MemoraSharedAudioFileRecord? { try repository.fetch(id: id).map(Self.record) }
  public func save(_ record: MemoraSharedAudioFileRecord) throws {
    let file = try repository.fetch(id: record.id) ?? AudioFile(title: record.title, audioURL: record.audioURL, projectID: record.projectID)
    file.id = record.id; file.title = record.title; file.projectID = record.projectID; file.createdAt = record.createdAt; file.duration = record.duration; file.audioURL = record.audioURL; file.isTranscribed = record.isTranscribed; file.isSummarized = record.isSummarized; file.summary = record.summary
    try repository.save(file)
  }
  public func delete(id: UUID) throws { try repository.delete(id: id) }
  private static func record(_ file: AudioFile) -> MemoraSharedAudioFileRecord { MemoraSharedAudioFileRecord(id: file.id, title: file.title, projectID: file.projectID, createdAt: file.createdAt, duration: file.duration, audioURL: file.audioURL, isTranscribed: file.isTranscribed, isSummarized: file.isSummarized, summary: file.summary) }
}
