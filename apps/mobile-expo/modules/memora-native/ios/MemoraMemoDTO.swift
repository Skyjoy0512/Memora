import Foundation

public struct MemoraPhotoAttachmentDTO {
  public let id: String
  public let uri: String
  public let addedAt: String

  public init(id: String, uri: String, addedAt: String) {
    self.id = id
    self.uri = uri
    self.addedAt = addedAt
  }

  public func asDictionary() -> [String: Any] {
    ["id": id, "uri": uri, "addedAt": addedAt]
  }
}

public protocol MemoraMemoHandling {
  var sourceDescription: String { get }

  func getMemoDraft(audioFileId: String) throws -> String
  func saveMemoDraft(audioFileId: String, text: String) throws -> Void
  func listPhotoAttachments(audioFileId: String) throws -> [MemoraPhotoAttachmentDTO]
  func addPhotoAttachment(audioFileId: String, sourceUri: String) throws -> MemoraPhotoAttachmentDTO
  func deletePhotoAttachment(audioFileId: String, attachmentId: String) throws -> Bool
}

public enum MemoraNativeMemoRegistry {
  public static var memoHandler: MemoraMemoHandling = MemoraNativeFileMemoStore()
}

private struct MemoraMemoRecord: Codable {
  var text: String
  var photos: [MemoraPhotoRecord]
}

private struct MemoraPhotoRecord: Codable {
  let id: String
  let fileName: String
  let addedAt: String
}

public final class MemoraNativeFileMemoStore: MemoraMemoHandling {
  public let sourceDescription = "native-files"

  private let isoFormatter = ISO8601DateFormatter()

  public init() {}

  public func getMemoDraft(audioFileId: String) throws -> String {
    try loadAll()[audioFileId]?.text ?? ""
  }

  public func saveMemoDraft(audioFileId: String, text: String) throws -> Void {
    var records = try loadAll()
    var record = records[audioFileId] ?? MemoraMemoRecord(text: "", photos: [])
    record.text = text
    records[audioFileId] = record
    try save(records)
  }

  public func listPhotoAttachments(audioFileId: String) throws -> [MemoraPhotoAttachmentDTO] {
    let records = try loadAll()
    guard let record = records[audioFileId] else { return [] }
    let directory = try photosDirectory(for: audioFileId)
    return record.photos.map {
      MemoraPhotoAttachmentDTO(
        id: $0.id,
        uri: directory.appendingPathComponent($0.fileName).absoluteString,
        addedAt: $0.addedAt
      )
    }
  }

  public func addPhotoAttachment(audioFileId: String, sourceUri: String) throws -> MemoraPhotoAttachmentDTO {
    guard let sourceURL = URL(string: sourceUri), FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw CocoaError(.fileNoSuchFile)
    }

    let attachmentId = UUID().uuidString
    let fileName = "\(attachmentId).\(sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension)"
    let directory = try photosDirectory(for: audioFileId)
    let destinationURL = directory.appendingPathComponent(fileName)
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

    let addedAt = isoFormatter.string(from: Date())
    var records = try loadAll()
    var record = records[audioFileId] ?? MemoraMemoRecord(text: "", photos: [])
    record.photos.append(MemoraPhotoRecord(id: attachmentId, fileName: fileName, addedAt: addedAt))
    records[audioFileId] = record
    try save(records)

    return MemoraPhotoAttachmentDTO(id: attachmentId, uri: destinationURL.absoluteString, addedAt: addedAt)
  }

  public func deletePhotoAttachment(audioFileId: String, attachmentId: String) throws -> Bool {
    var records = try loadAll()
    guard var record = records[audioFileId],
          let index = record.photos.firstIndex(where: { $0.id == attachmentId }) else {
      return false
    }

    let photo = record.photos.remove(at: index)
    records[audioFileId] = record
    try save(records)

    let fileURL = try photosDirectory(for: audioFileId).appendingPathComponent(photo.fileName)
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    return true
  }

  private func loadAll() throws -> [String: MemoraMemoRecord] {
    let url = try metadataURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
      return [:]
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([String: MemoraMemoRecord].self, from: data)
  }

  private func save(_ records: [String: MemoraMemoRecord]) throws {
    let url = try metadataURL()
    let data = try JSONEncoder().encode(records)
    try data.write(to: url, options: [.atomic])
  }

  private func metadataURL() throws -> URL {
    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }

    let directory = documentsDirectory.appendingPathComponent("MemoraNativeMetadata", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("memo-notes.json")
  }

  private func photosDirectory(for audioFileId: String) throws -> URL {
    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }

    let directory = documentsDirectory
      .appendingPathComponent("MemoraNativeMemoPhotos", isDirectory: true)
      .appendingPathComponent(audioFileId, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
