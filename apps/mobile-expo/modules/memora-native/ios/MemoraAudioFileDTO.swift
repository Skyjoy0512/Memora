import Foundation

public struct MemoraAudioFileDTO {
  public let id: String
  public let title: String
  public let project: String
  public let source: String
  public let recordedAt: String
  public let duration: String
  public let status: String
  public let summary: String
  public let transcript: [[String: Any]]
  public let memo: [String]

  public init(
    id: String,
    title: String,
    project: String,
    source: String,
    recordedAt: String,
    duration: String,
    status: String,
    summary: String,
    transcript: [[String: Any]],
    memo: [String]
  ) {
    self.id = id
    self.title = title
    self.project = project
    self.source = source
    self.recordedAt = recordedAt
    self.duration = duration
    self.status = status
    self.summary = summary
    self.transcript = transcript
    self.memo = memo
  }

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "title": title,
      "project": project,
      "source": source,
      "recordedAt": recordedAt,
      "duration": duration,
      "status": status,
      "summary": summary,
      "transcript": transcript,
      "memo": memo
    ]
  }
}

public protocol MemoraAudioFileReading {
  var sourceDescription: String { get }

  func listAudioFiles() throws -> [MemoraAudioFileDTO]
  func getAudioFile(id: String) throws -> MemoraAudioFileDTO?
  /// Resolves the audio files owned by this reader for native playback.
  /// A segmented recording returns its segments in chronological order.
  func playbackFilePaths(forId id: String) throws -> [String]
}

public protocol MemoraAudioFileMutating {
  var sourceDescription: String { get }

  func upsertAudioFile(_ dto: MemoraAudioFileDTO, fileURL: URL) throws
  func renameAudioFile(id: String, title: String) throws -> MemoraAudioFileDTO?
  func moveAudioFile(id: String, projectId: String?) throws -> MemoraAudioFileDTO?
  func deleteAudioFile(id: String) throws -> Bool
}

public enum MemoraNativeAudioFileReaderRegistry {
  public static var audioFileReader: MemoraAudioFileReading = MemoraNativeFileAudioFileStore()
}

public enum MemoraNativeAudioFileMutationRegistry {
  public static var audioFileMutator: MemoraAudioFileMutating = MemoraNativeFileAudioFileStore()
}

public typealias MemoraNativeFileAudioFileReader = MemoraNativeFileAudioFileStore

public struct MemoraNativeFileAudioFileStore: MemoraAudioFileReading, MemoraAudioFileMutating {
  public let sourceDescription = "native-files"
  private let fallbackReader = MemoraSampleAudioFileReader()

  public init() {}

  public func listAudioFiles() throws -> [MemoraAudioFileDTO] {
    let files = try MemoraNativeAudioFileMetadataStore.loadAll()
    guard !files.isEmpty else {
      return try fallbackReader.listAudioFiles()
    }

    return files.map { $0.asDTO() }
  }

  public func getAudioFile(id: String) throws -> MemoraAudioFileDTO? {
    if let file = try MemoraNativeAudioFileMetadataStore.loadAll().first(where: { $0.id == id }) {
      return file.asDTO()
    }

    return try fallbackReader.getAudioFile(id: id)
  }

  public func playbackFilePaths(forId id: String) throws -> [String] {
    guard let filePath = try MemoraNativeAudioFileMetadataStore.filePath(forId: id) else {
      return []
    }
    return [filePath]
  }

  public func upsertAudioFile(_ dto: MemoraAudioFileDTO, fileURL: URL) throws {
    try MemoraNativeAudioFileMetadataStore.upsert(dto: dto, fileURL: fileURL)
  }

  public func renameAudioFile(id: String, title: String) throws -> MemoraAudioFileDTO? {
    try MemoraNativeAudioFileMetadataStore.rename(id: id, title: title)
  }

  public func moveAudioFile(id: String, projectId: String?) throws -> MemoraAudioFileDTO? {
    try MemoraNativeAudioFileMetadataStore.move(id: id, projectId: projectId)
  }

  public func deleteAudioFile(id: String) throws -> Bool {
    try MemoraNativeAudioFileMetadataStore.delete(id: id)
  }
}

struct MemoraNativeAudioFileMetadata: Codable {
  let id: String
  let title: String
  let project: String
  let source: String
  let recordedAt: String
  let duration: String
  let status: String
  let summary: String
  let memo: [String]
  let filePath: String

  init(dto: MemoraAudioFileDTO, fileURL: URL) {
    self.id = dto.id
    self.title = dto.title
    self.project = dto.project
    self.source = dto.source
    self.recordedAt = dto.recordedAt
    self.duration = dto.duration
    self.status = dto.status
    self.summary = dto.summary
    self.memo = dto.memo
    self.filePath = fileURL.path
  }

  private init(
    id: String,
    title: String,
    project: String,
    source: String,
    recordedAt: String,
    duration: String,
    status: String,
    summary: String,
    memo: [String],
    filePath: String
  ) {
    self.id = id
    self.title = title
    self.project = project
    self.source = source
    self.recordedAt = recordedAt
    self.duration = duration
    self.status = status
    self.summary = summary
    self.memo = memo
    self.filePath = filePath
  }

  func asDTO() -> MemoraAudioFileDTO {
    MemoraAudioFileDTO(
      id: id,
      title: title,
      project: project,
      source: source,
      recordedAt: recordedAt,
      duration: duration,
      status: status,
      summary: summary,
      transcript: [],
      memo: memo + ["Stored path: \(URL(fileURLWithPath: filePath).lastPathComponent)"]
    )
  }

  func renamed(to title: String) -> MemoraNativeAudioFileMetadata {
    MemoraNativeAudioFileMetadata(
      id: id,
      title: title,
      project: project,
      source: source,
      recordedAt: recordedAt,
      duration: duration,
      status: status,
      summary: summary,
      memo: memo,
      filePath: filePath
    )
  }

  func moved(to project: String) -> MemoraNativeAudioFileMetadata {
    MemoraNativeAudioFileMetadata(
      id: id,
      title: title,
      project: project,
      source: source,
      recordedAt: recordedAt,
      duration: duration,
      status: status,
      summary: summary,
      memo: memo,
      filePath: filePath
    )
  }
}

enum MemoraNativeAudioFileMetadataStore {
  static func upsert(dto: MemoraAudioFileDTO, fileURL: URL) throws {
    var files = try loadAll()
    let metadata = MemoraNativeAudioFileMetadata(dto: dto, fileURL: fileURL)

    if let index = files.firstIndex(where: { $0.id == metadata.id }) {
      files[index] = metadata
    } else {
      files.append(metadata)
    }

    try save(files)
  }

  static func loadAll() throws -> [MemoraNativeAudioFileMetadata] {
    let url = try metadataURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }

    let data = try Data(contentsOf: url)
    let decoded = try JSONDecoder().decode([MemoraNativeAudioFileMetadata].self, from: data)
    return decoded.sorted { $0.recordedAt > $1.recordedAt }
  }

  static func rename(id: String, title: String) throws -> MemoraAudioFileDTO? {
    var files = try loadAll()
    guard let index = files.firstIndex(where: { $0.id == id }) else {
      return nil
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      throw CocoaError(.fileWriteInvalidFileName)
    }

    files[index] = files[index].renamed(to: trimmedTitle)
    try save(files)
    return files[index].asDTO()
  }

  static func filePath(forId id: String) throws -> String? {
    try loadAll().first(where: { $0.id == id })?.filePath
  }

  static func move(id: String, projectId: String?) throws -> MemoraAudioFileDTO? {
    var files = try loadAll()
    guard let index = files.firstIndex(where: { $0.id == id }) else {
      return nil
    }

    let targetProject = projectId?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty ?? "Inbox"
    files[index] = files[index].moved(to: targetProject)
    try save(files)
    return files[index].asDTO()
  }

  static func delete(id: String) throws -> Bool {
    var files = try loadAll()
    guard let index = files.firstIndex(where: { $0.id == id }) else {
      return false
    }

    let removedFile = files.remove(at: index)
    try save(files)

    let fileURL = URL(fileURLWithPath: removedFile.filePath)
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    return true
  }

  private static func save(_ files: [MemoraNativeAudioFileMetadata]) throws {
    let url = try metadataURL()
    let data = try JSONEncoder().encode(files)
    try data.write(to: url, options: [.atomic])
  }

  private static func metadataURL() throws -> URL {
    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }

    let directory = documentsDirectory.appendingPathComponent("MemoraNativeMetadata", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("audio-files.json")
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

public struct MemoraSampleAudioFileReader: MemoraAudioFileReading {
  public let sourceDescription = "sample"

  public init() {}

  public func listAudioFiles() throws -> [MemoraAudioFileDTO] {
    [makeSampleAudioFile()]
  }

  public func getAudioFile(id: String) throws -> MemoraAudioFileDTO? {
    guard id == "native-sample" else { return nil }
    return makeSampleAudioFile()
  }

  public func playbackFilePaths(forId id: String) throws -> [String] {
    []
  }

  private func makeSampleAudioFile() -> MemoraAudioFileDTO {
    MemoraAudioFileDTO(
      id: "native-sample",
      title: "Native bridge sample",
      project: "Native Bridge",
      source: "iPhone",
      recordedAt: "native",
      duration: "00:12",
      status: "ready",
      summary: "This sample comes from the iOS MemoraNative Expo Module shell.",
      transcript: [],
      memo: ["Replace this sample with Swift service DTO adapters."]
    )
  }
}
