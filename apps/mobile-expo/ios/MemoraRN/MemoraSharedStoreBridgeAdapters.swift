import Foundation
import SwiftData
import MemoraSharedData
import MemoraSharedCore
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

  init(
    store: any MemoraSharedAudioFileStore,
    container: ModelContainer? = nil,
    ownedAudioDirectories: [URL] = MemoraSharedStoreBridgeAdapter.defaultOwnedAudioDirectories()
  ) {
    self.store = store
    self.isoFormatter = ISO8601DateFormatter()
    self.modelContainer = container
    self.ownedAudioDirectories = ownedAudioDirectories
  }

  func listAudioFiles() throws -> [MemoraAudioFileDTO] {
    // R10: 一覧・検索は全件を返す。fetchPage は新しい順ソートのままページングで
    // 末尾（最古の録音）まで取得する（旧実装は limit: 50 固定のため 51件目以降が
    // 一覧・検索から見つからなかった）。
    let pageSize = 100
    var offset = 0
    var allRecords: [MemoraSharedAudioFileRecord] = []
    while true {
      let page = try store.fetchPage(offset: offset, limit: pageSize)
      allRecords.append(contentsOf: page)
      // 総件数が pageSize の倍数でも、次の空ページ取得で確実に終了する。
      guard page.count == pageSize else { break }
      offset += page.count
    }
    return allRecords.map(makeDTO)
  }

  func getAudioFile(id: String) throws -> MemoraAudioFileDTO? {
    guard let uuid = UUID(uuidString: id) else { return nil }
    return try store.fetch(id: uuid).map(makeDTO)
  }

  func playbackFilePaths(forId id: String) throws -> [String] {
    guard let uuid = UUID(uuidString: id), let record = try store.fetch(id: uuid) else {
      return []
    }

    let paths = record.segmentPaths.isEmpty ? [record.audioURL] : record.segmentPaths
    return paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
    guard let uuid = UUID(uuidString: id), let record = try store.fetch(id: uuid) else {
      return false
    }

    // R09: DB レコード削除に先立ち、アプリ所有の音声実体（単一ファイル録音の
    // audioURL と分割録音の segmentPaths）を削除する。所有ルート外のパス
    // （例: importAudio の原本）は対象外。実体削除に失敗した場合はエラーを返し、
    // レコードを残すことで再試行できる状態を保つ。レコード削除は最後に行う。
    try removeOwnedAudioPayloads(of: record)

    try store.delete(id: uuid)
    return true
  }

  private func removeOwnedAudioPayloads(of record: MemoraSharedAudioFileRecord) throws {
    var candidatePaths = record.segmentPaths
    if !record.audioURL.isEmpty {
      candidatePaths.append(record.audioURL)
    }

    for rawPath in candidatePaths {
      let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      let payloadURL = URL(fileURLWithPath: trimmed).standardizedFileURL
      guard Self.isAppOwnedPayload(payloadURL, within: ownedAudioDirectories) else {
        continue
      }

      // 存在しない実体（再試行・既に削除済み）は黙ってスキップする。
      guard FileManager.default.fileExists(atPath: payloadURL.path) else { continue }
      try FileManager.default.removeItem(at: payloadURL)
    }
  }

  /// 所有ルートの「配下」（ルート自身を含まない）だけを削除対象とみなす。
  /// 誤削除防止: 所有ルート配下でないパスは何も削除しない。
  private static func isAppOwnedPayload(_ url: URL, within roots: [URL]) -> Bool {
    let path = url.standardizedFileURL.path
    for root in roots {
      let rootPath = root.standardizedFileURL.path
      if path.hasPrefix(rootPath + "/") {
        return true
      }
    }
    return false
  }

  /// 音声実体を書き込む側（MemoraNativeFileRecordingImportHandler 等）が使う
  /// 格納ルートを環境（App Group / サンドボックスの Application Support /
  /// Documents フォールバック）から再現する。ここで返るルート配下のみが
  /// 「アプリ所有」の削除対象となる。
  static func defaultOwnedAudioDirectories() -> [URL] {
    let fileManager = FileManager.default
    var roots: [URL] = []

    if let groupContainer = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: MemoraSharedStoreLocation.primaryAppGroupIdentifier
    ) {
      roots.append(MemoraSharedStoreLocation.audioFilesDirectory(in: groupContainer))
    }
    if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      roots.append(MemoraSharedStoreLocation.audioFilesDirectory(in: applicationSupport))
    }
    if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
      roots.append(documents.appendingPathComponent("MemoraNativeAudioFiles", isDirectory: true))
    }

    return roots
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
      // R11: memo はユーザーメモ専用のため内部の格納パス（Stored path）を載せない。
      // 要約由来の actionItems は明示フィールドで運び、共有レコードには無いため
      // SwiftData エンティティを直接読み取る（transcriptDTOs と同じ読み出し経路）。
      memo: [],
      actionItems: try actionItemLines(for: record.id)
    )
  }

  /// SwiftData の要約メタデータ（actionItems、改行区切りで保存）を行単位で返す。
  /// 共有ストア未接続（modelContainer なし）・未保存の場合は空配列。
  private func actionItemLines(for audioFileID: UUID) throws -> [String] {
    guard let modelContainer else { return [] }
    let modelContext = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == audioFileID })
    guard let audioFile = try modelContext.fetch(descriptor).first,
          let rawActionItems = audioFile.actionItems,
          !rawActionItems.isEmpty else {
      return []
    }
    return rawActionItems
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private func transcriptDTOs(for audioFileID: UUID) throws -> [[String: Any]] {
    guard let modelContainer else { return [] }
    let modelContext = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == audioFileID })
    guard let transcript = try modelContext.fetch(descriptor).first?.transcripts.first else { return [] }
    let cleaned = transcript.cleanedSegmentTexts
    let postProcessor = TranscriptPostProcessor()
    // ユーザー辞書の適用は保存時（MemoraRNTranscriptionBridge.persist）の
    // 1回だけ。cleanedSegmentTexts は適用済みの最終文字列のため、DTO読込時に
    // 再適用すると二重適用になる（例: CRM→CRMシステム が CRMシステムシステム になる）。
    return transcript.segmentTexts.enumerated().map { index, text in
      let cleanedText = index < cleaned.count ? cleaned[index] : postProcessor.clean(text)
      return [
        "id": "segment-\(index)",
        "speaker": index < transcript.speakerLabels.count ? transcript.speakerLabels[index] : "",
        "time": formattedDuration(index < transcript.segmentStartTimes.count ? transcript.segmentStartTimes[index] : 0),
        "text": text,
        "cleanedText": cleanedText,
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
      // RN uploads and imports remain single-file records. Segmented native
      // recordings are preserved by the SwiftData store adapter above.
      segmentPaths: [],
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

/// Adapts the host-owned SwiftData TodoItem repository to the Expo module's task
/// JSON DTO boundary. Falls back to the module's in-memory store until a SwiftData
/// container is configured during bootstrap.
final class MemoraSharedStoreTaskBridgeAdapter: MemoraTaskReading, MemoraTaskMutating {
  private let repository: TodoItemRepository
  private let isoFormatter: ISO8601DateFormatter

  var sourceDescription: String {
    "swiftdata"
  }

  init(container: ModelContainer) {
    self.repository = TodoItemRepository(modelContext: ModelContext(container))
    self.isoFormatter = ISO8601DateFormatter()
  }

  func listTasks() throws -> [MemoraTaskDTO] {
    try repository.fetchAll().map(makeDTO)
  }

  func createTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO {
    let item = TodoItem(title: dto.title)
    item.id = UUID(uuidString: dto.id) ?? UUID()
    apply(dto, to: item)
    try repository.save(item)
    return makeDTO(from: item)
  }

  func updateTask(_ dto: MemoraTaskDTO) throws -> MemoraTaskDTO? {
    guard let id = UUID(uuidString: dto.id), let item = try repository.fetch(id: id) else {
      return nil
    }
    apply(dto, to: item)
    try repository.save(item)
    return makeDTO(from: item)
  }

  func toggleTask(id: String, completed: Bool) throws -> MemoraTaskDTO? {
    guard let uuid = UUID(uuidString: id) else { return nil }
    let item = try repository.setCompleted(id: uuid, isCompleted: completed)
    return try item.map(makeDTO)
  }

  func deleteTask(id: String) throws -> Bool {
    guard let uuid = UUID(uuidString: id), try repository.fetch(id: uuid) != nil else {
      return false
    }
    try repository.delete(id: uuid)
    return true
  }

  private func apply(_ dto: MemoraTaskDTO, to item: TodoItem) {
    item.title = dto.title
    item.notes = dto.notes
    item.assignee = dto.assignee
    item.speaker = dto.speaker
    item.priority = dto.priority
    item.dueDate = parseDate(dto.dueDate)
    item.relativeDueDate = dto.relativeDueDate
    item.projectID = dto.projectID.flatMap(UUID.init(uuidString:))
    item.parentID = dto.parentID.flatMap(UUID.init(uuidString:))
    item.sourceAudioFileID = dto.sourceAudioFileID.flatMap(UUID.init(uuidString:))
    item.isCompleted = dto.isCompleted
    item.completedAt = parseDate(dto.completedAt)
  }

  private func makeDTO(from item: TodoItem) -> MemoraTaskDTO {
    MemoraTaskDTO(
      id: item.id.uuidString,
      title: item.title,
      notes: item.notes,
      assignee: item.assignee,
      speaker: item.speaker,
      priority: item.priority,
      dueDate: item.dueDate.map(isoFormatter.string),
      relativeDueDate: item.relativeDueDate,
      projectID: item.projectID?.uuidString,
      parentID: item.parentID?.uuidString,
      sourceAudioFileID: item.sourceAudioFileID?.uuidString,
      isCompleted: item.isCompleted,
      createdAt: isoFormatter.string(from: item.createdAt),
      completedAt: item.completedAt.map(isoFormatter.string)
    )
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    return Self.fractionalSecondsFormatter.date(from: value) ?? isoFormatter.date(from: value)
  }

  private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}

/// Adapts the host-owned SwiftData Project entities to the Expo module's project
/// JSON DTO boundary. Projects are returned in title order.
final class MemoraSharedStoreProjectBridgeAdapter: MemoraProjectReading {
  let sourceDescription = "swiftdata"

  let container: ModelContainer

  init(container: ModelContainer) {
    self.container = container
  }

  func listProjects() throws -> [MemoraProjectDTO] {
    let modelContext = ModelContext(container)
    let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.title)])
    return try modelContext.fetch(descriptor).map { project in
      MemoraProjectDTO(id: project.id.uuidString, title: project.title)
    }
  }
}
