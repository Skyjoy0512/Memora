import Foundation
import AVFoundation

public struct MemoraRecordingSessionDTO {
  public let id: String
  public let startedAt: String
  public let source: String

  public init(id: String, startedAt: String, source: String) {
    self.id = id
    self.startedAt = startedAt
    self.source = source
  }

  public func asDictionary() -> [String: Any] {
    [
      "id": id,
      "startedAt": startedAt,
      "source": source
    ]
  }
}

public protocol MemoraRecordingImportHandling {
  var sourceDescription: String { get }

  func startRecording() throws -> MemoraRecordingSessionDTO
  func pauseRecording(sessionId: String) throws
  func resumeRecording(sessionId: String) throws
  func discardRecording(sessionId: String) throws
  func stopRecording(sessionId: String) throws -> MemoraAudioFileDTO
  func importAudio(uri: String) throws -> MemoraAudioFileDTO
}

public enum MemoraNativeRecordingImportRegistry {
  public static var handler: MemoraRecordingImportHandling = MemoraNativeFileRecordingImportHandler()
}

public final class MemoraNativeFileRecordingImportHandler: NSObject, MemoraRecordingImportHandling {
  public let sourceDescription: String

  private var activeRecorders: [String: AVAudioRecorder] = [:]
  private let isoFormatter = ISO8601DateFormatter()
  private let storageDirectory: URL?

  /// `storageDirectory` is supplied by a host that owns a shared App Group.
  /// Leaving it nil preserves the native-files fallback in the app Documents directory.
  public init(storageDirectory: URL? = nil, sourceDescription: String = "native-file") {
    self.storageDirectory = storageDirectory
    self.sourceDescription = sourceDescription
    super.init()
  }

  public func startRecording() throws -> MemoraRecordingSessionDTO {
    try configureAudioSession()
    try ensureRecordPermission()

    let sessionId = "native-recording-\(UUID().uuidString)"
    let fileURL = try recordingDirectory()
      .appendingPathComponent(sessionId)
      .appendingPathExtension("m4a")
    let recorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings())
    recorder.prepareToRecord()

    guard recorder.record() else {
      throw MemoraRecordingImportError.recordingStartFailed
    }

    activeRecorders[sessionId] = recorder

    return MemoraRecordingSessionDTO(
      id: sessionId,
      startedAt: isoFormatter.string(from: Date()),
      source: "iPhone"
    )
  }

  public func stopRecording(sessionId: String) throws -> MemoraAudioFileDTO {
    guard let recorder = activeRecorders.removeValue(forKey: sessionId) else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }

    recorder.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    return try makeAudioFileDTO(
      id: UUID().uuidString,
      fileURL: recorder.url,
      summary: "Recorded with MemoraRN."
    )
  }

  public func pauseRecording(sessionId: String) throws {
    guard let recorder = activeRecorders[sessionId] else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }
    recorder.pause()
  }

  public func resumeRecording(sessionId: String) throws {
    guard let recorder = activeRecorders[sessionId] else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }
    guard recorder.record() else {
      throw MemoraRecordingImportError.recordingStartFailed
    }
  }

  public func discardRecording(sessionId: String) throws {
    guard let recorder = activeRecorders.removeValue(forKey: sessionId) else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }
    recorder.deleteRecording()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  public func importAudio(uri: String) throws -> MemoraAudioFileDTO {
    let sourceURL = makeURL(from: uri)
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw MemoraRecordingImportError.importFileNotFound
    }

    let destinationURL = try uniqueDestinationURL(for: sourceURL)
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

    return try makeAudioFileDTO(
      id: UUID().uuidString,
      fileURL: destinationURL,
      summary: "Imported with MemoraRN."
    )
  }

  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
    try session.setActive(true)
  }

  private func ensureRecordPermission() throws {
    let session = AVAudioSession.sharedInstance()

    switch session.recordPermission {
    case .granted:
      return
    case .denied:
      throw MemoraRecordingImportError.microphonePermissionDenied
    case .undetermined:
      let semaphore = DispatchSemaphore(value: 0)
      var isGranted = false
      session.requestRecordPermission { granted in
        isGranted = granted
        semaphore.signal()
      }
      semaphore.wait()

      if !isGranted {
        throw MemoraRecordingImportError.microphonePermissionDenied
      }
    @unknown default:
      throw MemoraRecordingImportError.microphonePermissionDenied
    }
  }

  private func recordingSettings() -> [String: Any] {
    [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
  }

  private func recordingDirectory() throws -> URL {
    let directory = try audioFilesRootDirectory()
      .appendingPathComponent("Recordings", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func importDirectory() throws -> URL {
    let directory = try audioFilesRootDirectory()
      .appendingPathComponent("Imports", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func documentsDirectory() throws -> URL {
    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw MemoraRecordingImportError.documentsDirectoryUnavailable
    }

    return directory
  }

  private func audioFilesRootDirectory() throws -> URL {
    if let storageDirectory {
      return storageDirectory
    }

    return try documentsDirectory()
      .appendingPathComponent("MemoraNativeAudioFiles", isDirectory: true)
  }

  private func uniqueDestinationURL(for sourceURL: URL) throws -> URL {
    let sanitizedName = sourceURL.lastPathComponent.isEmpty ? "imported-audio.m4a" : sourceURL.lastPathComponent
    let destination = try importDirectory()
      .appendingPathComponent("\(UUID().uuidString)-\(sanitizedName)")
    return destination
  }

  private func makeURL(from uri: String) -> URL {
    if let url = URL(string: uri), url.scheme != nil {
      return url
    }

    return URL(fileURLWithPath: uri)
  }

  private func makeAudioFileDTO(id: String, fileURL: URL, summary: String) throws -> MemoraAudioFileDTO {
    let dto = MemoraAudioFileDTO(
      id: id,
      title: fileURL.lastPathComponent,
      project: "Inbox",
      source: "iPhone",
      recordedAt: isoFormatter.string(from: Date()),
      duration: formattedDuration(for: fileURL),
      // STT is intentionally not started by this bridge. The file is queued
      // in the shared store for the following STT bridge phase.
      status: "queued",
      summary: summary,
      transcript: [],
      memo: ["Native file path: \(fileURL.lastPathComponent)"]
    )
    try MemoraNativeAudioFileMutationRegistry.audioFileMutator.upsertAudioFile(dto, fileURL: fileURL)
    return dto
  }

  private func formattedDuration(for fileURL: URL) -> String {
    let seconds = AVURLAsset(url: fileURL).duration.seconds
    guard seconds.isFinite && seconds > 0 else {
      return "00:00"
    }

    let totalSeconds = Int(seconds.rounded())
    return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
  }
}

private enum MemoraRecordingImportError: LocalizedError {
  case documentsDirectoryUnavailable
  case microphonePermissionDenied
  case recordingStartFailed
  case recordingSessionNotFound
  case importFileNotFound

  var errorDescription: String? {
    switch self {
    case .documentsDirectoryUnavailable:
      return "Documents directory is unavailable."
    case .microphonePermissionDenied:
      return "Microphone permission was denied."
    case .recordingStartFailed:
      return "Native recording could not be started."
    case .recordingSessionNotFound:
      return "Recording session was not found."
    case .importFileNotFound:
      return "Import source file was not found."
    }
  }
}

public struct MemoraSampleRecordingImportHandler: MemoraRecordingImportHandling {
  public let sourceDescription = "sample"

  public init() {}

  public func startRecording() throws -> MemoraRecordingSessionDTO {
    MemoraRecordingSessionDTO(
      id: "native-recording-\(Date().timeIntervalSince1970)",
      startedAt: ISO8601DateFormatter().string(from: Date()),
      source: "iPhone"
    )
  }

  public func stopRecording(sessionId: String) throws -> MemoraAudioFileDTO {
    makeGeneratedAudioFile(
      id: "native-recording-file-\(sessionId)",
      title: "\(sessionId).m4a",
      summary: "Native recording bridge shell generated this DTO without starting AVFoundation yet."
    )
  }

  public func pauseRecording(sessionId: String) throws {}

  public func resumeRecording(sessionId: String) throws {}

  public func discardRecording(sessionId: String) throws {}

  public func importAudio(uri: String) throws -> MemoraAudioFileDTO {
    makeGeneratedAudioFile(
      id: "native-import-\(Date().timeIntervalSince1970)",
      title: URL(fileURLWithPath: uri).lastPathComponent,
      summary: "Native import bridge shell received the URI and returned a DTO placeholder."
    )
  }

  private func makeGeneratedAudioFile(
    id: String,
    title: String,
    summary: String
  ) -> MemoraAudioFileDTO {
    MemoraAudioFileDTO(
      id: id,
      title: title.isEmpty ? "Imported audio" : title,
      project: "Inbox",
      source: "iPhone",
      recordedAt: "native",
      duration: "00:00",
      status: "ready",
      summary: summary,
      transcript: [],
      memo: []
    )
  }
}
