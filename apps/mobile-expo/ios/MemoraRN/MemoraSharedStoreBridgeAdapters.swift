import Foundation
import SwiftData
import MemoraSharedData
import MemoraSharedSchema
internal import MemoraNative

/// Adapts a host-owned shared store to the Expo module's JSON DTO boundary.
/// The concrete store can later be backed by the host's SwiftData repository.
final class MemoraSharedStoreBridgeAdapter: MemoraAudioFileReading, MemoraAudioFileMutating {
  private let store: any MemoraSharedAudioFileStore
  private let isoFormatter: ISO8601DateFormatter
  private let modelContainer: ModelContainer?

  var sourceDescription: String {
    store.sourceDescription
  }

  init(store: any MemoraSharedAudioFileStore, container: ModelContainer? = nil) {
    self.store = store
    self.isoFormatter = ISO8601DateFormatter()
    self.modelContainer = container
  }

  func listAudioFiles() throws -> [MemoraAudioFileDTO] {
    try store.fetchPage(offset: 0, limit: 50).map(makeDTO)
  }

  func getAudioFile(id: String) throws -> MemoraAudioFileDTO? {
    guard let uuid = UUID(uuidString: id) else { return nil }
    return try store.fetch(id: uuid).map(makeDTO)
  }

  func upsertAudioFile(_ dto: MemoraAudioFileDTO, fileURL: URL) throws {
    guard UUID(uuidString: dto.id) != nil else {
      throw MemoraSharedStoreBridgeError.invalidAudioFileID(dto.id)
    }
    try store.save(makeRecord(from: dto, fallbackURL: fileURL))
  }

  func renameAudioFile(id: String, title: String) throws -> MemoraAudioFileDTO? {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      throw MemoraSharedStoreBridgeError.emptyTitle
    }

    guard let uuid = UUID(uuidString: id), let record = try store.fetch(id: uuid) else {
      return nil
    }

    var renamed = record
    renamed.title = trimmedTitle
    try store.save(renamed)
    return try makeDTO(from: renamed)
  }

  func moveAudioFile(id: String, projectId: String?) throws -> MemoraAudioFileDTO? {
    let trimmedProjectId = projectId?.trimmingCharacters(in: .whitespacesAndNewlines)
    let targetProjectId: UUID?
    if trimmedProjectId == nil || trimmedProjectId?.isEmpty == true || trimmedProjectId == "Inbox" {
      targetProjectId = nil
    } else if let trimmedProjectId, let uuid = UUID(uuidString: trimmedProjectId) {
      targetProjectId = uuid
    } else {
      throw MemoraSharedStoreBridgeError.invalidProjectID(projectId ?? "")
    }

    guard let uuid = UUID(uuidString: id), let record = try store.fetch(id: uuid) else {
      return nil
    }

    var moved = record
    moved.projectID = targetProjectId
    try store.save(moved)
    return try makeDTO(from: moved)
  }

  func deleteAudioFile(id: String) throws -> Bool {
    guard let uuid = UUID(uuidString: id), try store.fetch(id: uuid) != nil else {
      return false
    }

    try store.delete(id: uuid)
    return true
  }

  private func makeDTO(from record: MemoraSharedAudioFileRecord) throws -> MemoraAudioFileDTO {
    MemoraAudioFileDTO(
      id: record.id.uuidString,
      title: record.title,
      project: record.projectID?.uuidString ?? "Inbox",
      source: "iPhone",
      recordedAt: isoFormatter.string(from: record.createdAt),
      duration: formattedDuration(record.duration),
      status: record.isTranscribed ? "ready" : "queued",
      summary: record.summary ?? "",
      transcript: try transcriptDTOs(for: record.id),
      memo: record.audioURL.isEmpty ? [] : ["Stored path: \(URL(fileURLWithPath: record.audioURL).lastPathComponent)"]
    )
  }

  private func transcriptDTOs(for audioFileID: UUID) throws -> [[String: Any]] {
    guard let modelContainer else { return [] }
    let modelContext = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == audioFileID })
    guard let transcript = try modelContext.fetch(descriptor).first?.transcripts.first else { return [] }
    return zip(zip(transcript.speakerLabels, transcript.segmentStartTimes), zip(transcript.segmentEndTimes, transcript.segmentTexts)).enumerated().map { index, value in
      [
        "id": "segment-\(index)",
        "speaker": value.0.0,
        "time": formattedDuration(value.0.1),
        "text": value.1.1,
        "confidence": 1.0
      ]
    }
  }

  private func makeRecord(
    from dto: MemoraAudioFileDTO,
    fallbackURL: URL
  ) -> MemoraSharedAudioFileRecord {
    let createdAt = isoFormatter.date(from: dto.recordedAt) ?? Date()
    return MemoraSharedAudioFileRecord(
      id: UUID(uuidString: dto.id) ?? UUID(),
      title: dto.title,
      projectID: UUID(uuidString: dto.project),
      createdAt: createdAt,
      duration: parseDuration(dto.duration),
      audioURL: fallbackURL.path,
      isTranscribed: dto.status == "ready" || dto.status == "summarized",
      isSummarized: dto.status == "summarized" || !dto.summary.isEmpty,
      summary: dto.summary.isEmpty ? nil : dto.summary
    )
  }

  private func formattedDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded()))
    return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
  }

  private func parseDuration(_ value: String) -> TimeInterval {
    let parts = value.split(separator: ":").compactMap { Int($0) }
    guard !parts.isEmpty else { return 0 }
    if parts.count == 2 {
      return TimeInterval(parts[0] * 60 + parts[1])
    }
    if parts.count == 3 {
      return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
    }
    return TimeInterval(parts[0])
  }
}

enum MemoraSharedStoreBridgeError: LocalizedError {
  case emptyTitle
  case invalidAudioFileID(String)
  case invalidProjectID(String)

  var errorDescription: String? {
    switch self {
    case .emptyTitle:
      return "Audio file title cannot be empty."
    case .invalidAudioFileID(let id):
      return "Audio file ID is not a valid UUID: \(id)"
    case .invalidProjectID(let id):
      return "Project ID is not a valid UUID: \(id)"
    }
  }
}
