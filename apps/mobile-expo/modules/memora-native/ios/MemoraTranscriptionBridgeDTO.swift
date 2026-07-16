import Foundation

public struct MemoraTranscriptionTaskDTO {
  public let id: String
  public let audioFileId: String
  public let status: String
  public let progress: Double

  public init(id: String, audioFileId: String, status: String, progress: Double) {
    self.id = id
    self.audioFileId = audioFileId
    self.status = status
    self.progress = progress
  }

  public func asDictionary() -> [String: Any] {
    ["id": id, "audioFileId": audioFileId, "status": status, "progress": progress]
  }
}

public struct MemoraTranscriptionEventDTO {
  public let taskId: String
  public let audioFileId: String
  public let type: String
  public let progress: Double
  public let message: String

  public init(taskId: String, audioFileId: String, type: String, progress: Double, message: String) {
    self.taskId = taskId
    self.audioFileId = audioFileId
    self.type = type
    self.progress = progress
    self.message = message
  }

  public func asDictionary() -> [String: Any] {
    ["taskId": taskId, "audioFileId": audioFileId, "type": type, "progress": progress, "message": message]
  }
}

public protocol MemoraTranscriptionHandling: AnyObject {
  var sourceDescription: String { get }
  func startTranscription(
    audioFileId: String,
    emit: @escaping (MemoraTranscriptionEventDTO) -> Void
  ) async throws -> MemoraTranscriptionTaskDTO
  func cancelTranscription(taskId: String) async
}

public enum MemoraNativeTranscriptionRegistry {
  public static var handler: MemoraTranscriptionHandling = MemoraUnavailableTranscriptionHandler()
}

public final class MemoraUnavailableTranscriptionHandler: MemoraTranscriptionHandling {
  public let sourceDescription = "unavailable"

  public init() {}

  public func startTranscription(
    audioFileId: String,
    emit: @escaping (MemoraTranscriptionEventDTO) -> Void
  ) async throws -> MemoraTranscriptionTaskDTO {
    throw MemoraTranscriptionBridgeError.unavailable
  }

  public func cancelTranscription(taskId: String) async {}
}

public enum MemoraTranscriptionBridgeError: LocalizedError {
  case unavailable

  public var errorDescription: String? {
    "Native transcription is unavailable because the shared store is not connected."
  }
}
