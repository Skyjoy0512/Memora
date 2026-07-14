import Foundation

public struct MemoraProcessingRetryDTO: Codable, Sendable {
  public let id: String
  public let audioFileId: String
  public let operation: String
  public let attemptCount: Int
  public let lastError: String
  public let createdAt: String
  public let updatedAt: String

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "audioFileId": audioFileId,
      "operation": operation,
      "attemptCount": attemptCount,
      "lastError": lastError,
      "createdAt": createdAt,
      "updatedAt": updatedAt
    ]
  }

  fileprivate func updating(lastError: String, incrementAttempt: Bool) -> Self {
    Self(
      id: id,
      audioFileId: audioFileId,
      operation: operation,
      attemptCount: attemptCount + (incrementAttempt ? 1 : 0),
      lastError: lastError,
      createdAt: createdAt,
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }
}

public protocol MemoraProcessingRetryQueueing {
  var sourceDescription: String { get }

  func enqueue(audioFileId: String, operation: String, lastError: String?) throws -> MemoraProcessingRetryDTO
  func list() throws -> [MemoraProcessingRetryDTO]
  func recordFailedAttempt(id: String, lastError: String) throws -> MemoraProcessingRetryDTO?
  func complete(id: String) throws -> Bool
}

public enum MemoraNativeProcessingRetryRegistry {
  public static var queue: MemoraProcessingRetryQueueing = MemoraFileProcessingRetryQueue()
}

public final class MemoraFileProcessingRetryQueue: MemoraProcessingRetryQueueing {
  public let sourceDescription = "native-file"

  private let storageURL: URL?
  private let lock = NSLock()
  private let formatter = ISO8601DateFormatter()

  public init(storageURL: URL? = nil) {
    self.storageURL = storageURL
  }

  public func enqueue(
    audioFileId: String,
    operation: String,
    lastError: String?
  ) throws -> MemoraProcessingRetryDTO {
    let normalizedAudioFileId = audioFileId.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedAudioFileId.isEmpty else {
      throw MemoraProcessingRetryError.emptyAudioFileID
    }

    let normalizedOperation = operation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard ["transcription", "summary"].contains(normalizedOperation) else {
      throw MemoraProcessingRetryError.invalidOperation(operation)
    }

    return try withLock {
      var items = try loadUnlocked()
      let normalizedError = lastError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      if let index = items.firstIndex(where: {
        $0.audioFileId == normalizedAudioFileId && $0.operation == normalizedOperation
      }) {
        items[index] = items[index].updating(lastError: normalizedError, incrementAttempt: false)
        try saveUnlocked(items)
        return items[index]
      }

      let now = formatter.string(from: Date())
      let item = MemoraProcessingRetryDTO(
        id: UUID().uuidString,
        audioFileId: normalizedAudioFileId,
        operation: normalizedOperation,
        attemptCount: 0,
        lastError: normalizedError,
        createdAt: now,
        updatedAt: now
      )
      items.append(item)
      try saveUnlocked(items)
      return item
    }
  }

  public func list() throws -> [MemoraProcessingRetryDTO] {
    try withLock {
      try loadUnlocked().sorted { $0.createdAt < $1.createdAt }
    }
  }

  public func recordFailedAttempt(id: String, lastError: String) throws -> MemoraProcessingRetryDTO? {
    try withLock {
      var items = try loadUnlocked()
      guard let index = items.firstIndex(where: { $0.id == id }) else {
        return nil
      }

      items[index] = items[index].updating(
        lastError: lastError.trimmingCharacters(in: .whitespacesAndNewlines),
        incrementAttempt: true
      )
      try saveUnlocked(items)
      return items[index]
    }
  }

  public func complete(id: String) throws -> Bool {
    try withLock {
      var items = try loadUnlocked()
      guard let index = items.firstIndex(where: { $0.id == id }) else {
        return false
      }

      items.remove(at: index)
      try saveUnlocked(items)
      return true
    }
  }

  private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try operation()
  }

  private func loadUnlocked() throws -> [MemoraProcessingRetryDTO] {
    let url = try resolvedStorageURL()
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }
    return try JSONDecoder().decode([MemoraProcessingRetryDTO].self, from: Data(contentsOf: url))
  }

  private func saveUnlocked(_ items: [MemoraProcessingRetryDTO]) throws {
    let url = try resolvedStorageURL()
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(items).write(to: url, options: [.atomic])
  }

  private func resolvedStorageURL() throws -> URL {
    if let storageURL {
      return storageURL
    }

    guard let documentsDirectory = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      throw CocoaError(.fileNoSuchFile)
    }
    return documentsDirectory
      .appendingPathComponent("MemoraNativeMetadata", isDirectory: true)
      .appendingPathComponent("processing-retries.json")
  }
}

public enum MemoraProcessingRetryError: LocalizedError {
  case emptyAudioFileID
  case invalidOperation(String)

  public var errorDescription: String? {
    switch self {
    case .emptyAudioFileID:
      return "Audio file ID cannot be empty."
    case .invalidOperation(let operation):
      return "Unsupported retry operation: \(operation)"
    }
  }
}
