import Foundation

public enum MemoraSharedStoreLocation {
  /// Dedicated to the app and React Native host. Do not reuse the broadcast extension group.
  public static let primaryAppGroupIdentifier = "group.com.memora.shared"

  public enum Error: Swift.Error, Equatable {
    case applicationGroupUnavailable(String)
  }

  public static func storeURL(in containerURL: URL) -> URL {
    containerURL
      .appendingPathComponent("Memora", isDirectory: true)
      .appendingPathComponent("Memora.store")
  }

  /// Audio payloads referenced by the shared SwiftData store.
  /// Both hosts receive this URL from the same App Group container.
  public static func audioFilesDirectory(in containerURL: URL) -> URL {
    containerURL
      .appendingPathComponent("Memora", isDirectory: true)
      .appendingPathComponent("AudioFiles", isDirectory: true)
  }

  public static func applicationGroupStoreURL(
    groupIdentifier: String,
    fileManager: FileManager = .default
  ) throws -> URL {
    guard let containerURL = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: groupIdentifier
    ) else {
      throw Error.applicationGroupUnavailable(groupIdentifier)
    }

    return storeURL(in: containerURL)
  }
}

public enum MemoraStoreMigration {
  public enum Error: Swift.Error, Equatable {
    case destinationAlreadyExists(URL)
    case destinationDirectoryAlreadyExists(URL)
    case sourceStoreMissing(URL)
    case verificationFailed(URL)
  }

  public static let sidecarSuffixes = ["", "-shm", "-wal"]

  /// Copies a closed SQLite store into a staging directory and then moves that
  /// directory into place as one unit. The source store is retained as a backup.
  @discardableResult
  public static func migrateStoreAtomically(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager = .default,
    stagingDirectoryName: String = ".memora-store-migration-\(UUID().uuidString)"
  ) throws -> [URL] {
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw Error.sourceStoreMissing(sourceURL)
    }

    let destinationDirectory = destinationURL.deletingLastPathComponent()
    guard !fileManager.fileExists(atPath: destinationDirectory.path) else {
      throw Error.destinationDirectoryAlreadyExists(destinationDirectory)
    }

    let destinationRoot = destinationDirectory.deletingLastPathComponent()
    try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

    let stagingDirectory = destinationRoot.appendingPathComponent(
      stagingDirectoryName,
      isDirectory: true
    )
    guard !fileManager.fileExists(atPath: stagingDirectory.path) else {
      throw Error.destinationDirectoryAlreadyExists(stagingDirectory)
    }

    try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
    var copiedSuffixes: [String] = []
    defer {
      if fileManager.fileExists(atPath: stagingDirectory.path) {
        try? fileManager.removeItem(at: stagingDirectory)
      }
    }

    for suffix in sidecarSuffixes {
      let source = URL(fileURLWithPath: sourceURL.path + suffix)
      guard fileManager.fileExists(atPath: source.path) else { continue }

      let staged = stagingDirectory.appendingPathComponent(destinationURL.lastPathComponent + suffix)
      try fileManager.copyItem(at: source, to: staged)
      guard fileManager.contentsEqual(atPath: source.path, andPath: staged.path) else {
        throw Error.verificationFailed(staged)
      }
      copiedSuffixes.append(suffix)
    }

    try fileManager.moveItem(at: stagingDirectory, to: destinationDirectory)
    return copiedSuffixes.map { suffix in
      URL(fileURLWithPath: destinationURL.path + suffix)
    }
  }

  @discardableResult
  public static func copyStore(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager = .default
  ) throws -> [URL] {
    guard fileManager.fileExists(atPath: sourceURL.path) else {
      throw Error.sourceStoreMissing(sourceURL)
    }

    for suffix in sidecarSuffixes {
      let destination = URL(fileURLWithPath: destinationURL.path + suffix)
      if fileManager.fileExists(atPath: destination.path) {
        throw Error.destinationAlreadyExists(destination)
      }
    }

    let destinationDirectory = destinationURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: destinationDirectory,
      withIntermediateDirectories: true
    )

    var copiedURLs: [URL] = []
    for suffix in sidecarSuffixes {
      let source = URL(fileURLWithPath: sourceURL.path + suffix)
      guard fileManager.fileExists(atPath: source.path) else { continue }

      let destination = URL(fileURLWithPath: destinationURL.path + suffix)
      try fileManager.copyItem(at: source, to: destination)
      copiedURLs.append(destination)
    }

    return copiedURLs
  }
}

public struct MemoraSharedAudioFileRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public var title: String
  public var projectID: UUID?
  public var createdAt: Date
  public var duration: TimeInterval
  public var audioURL: String
  public var isTranscribed: Bool
  public var isSummarized: Bool
  public var summary: String?

  public init(
    id: UUID,
    title: String,
    projectID: UUID? = nil,
    createdAt: Date,
    duration: TimeInterval,
    audioURL: String,
    isTranscribed: Bool = false,
    isSummarized: Bool = false,
    summary: String? = nil
  ) {
    self.id = id
    self.title = title
    self.projectID = projectID
    self.createdAt = createdAt
    self.duration = duration
    self.audioURL = audioURL
    self.isTranscribed = isTranscribed
    self.isSummarized = isSummarized
    self.summary = summary
  }
}

public protocol MemoraSharedAudioFileStore: Sendable {
  var sourceDescription: String { get }

  func fetchPage(offset: Int, limit: Int) throws -> [MemoraSharedAudioFileRecord]
  func fetch(id: UUID) throws -> MemoraSharedAudioFileRecord?
  func save(_ record: MemoraSharedAudioFileRecord) throws
  func delete(id: UUID) throws
}

public final class MemoraInMemoryAudioFileStore: MemoraSharedAudioFileStore, @unchecked Sendable {
  public let sourceDescription = "mock"

  private let lock = NSLock()
  private var records: [UUID: MemoraSharedAudioFileRecord] = [:]

  public init(records: [MemoraSharedAudioFileRecord] = []) {
    self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
  }

  public func fetchPage(offset: Int, limit: Int) throws -> [MemoraSharedAudioFileRecord] {
    lock.lock()
    defer { lock.unlock() }

    let sorted = records.values.sorted { $0.createdAt > $1.createdAt }
    return Array(sorted.dropFirst(max(0, offset)).prefix(max(0, limit)))
  }

  public func fetch(id: UUID) throws -> MemoraSharedAudioFileRecord? {
    lock.lock()
    defer { lock.unlock() }
    return records[id]
  }

  public func save(_ record: MemoraSharedAudioFileRecord) throws {
    lock.lock()
    defer { lock.unlock() }
    records[record.id] = record
  }

  public func delete(id: UUID) throws {
    lock.lock()
    defer { lock.unlock() }
    records.removeValue(forKey: id)
  }
}
