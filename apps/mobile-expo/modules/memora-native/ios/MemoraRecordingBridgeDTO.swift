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

/// 録音セッションの状態。ユーザー操作による pause と OS 割込みによる停止を区別し、
/// 割込み復帰（.ended + .shouldResume）時の自動再開対象を決める（R18）。
private enum MemoraRecordingSessionState {
  case recording
  /// ユーザー操作（pauseRecording）による一時停止。割込み復帰時も自動再開しない。
  case pausedByUser
  /// 進行中の OS 割込み（interruption .began）による自動停止。
  /// .ended + shouldResume で自動再開の対象になる。
  case interruptedBySystem
  /// 割込み終了後も停止中（shouldResume なし、または自動再開失敗）。
  /// 明示的な resumeRecording のみで再開する。
  case pausedAfterInterruption
}

/// 開始〜停止中の録音セッション（旧 activeRecorders + activeRecorderStartDates 相当）。
private struct MemoraActiveRecording {
  let recorder: AVAudioRecorder
  let startDate: Date
  var state: MemoraRecordingSessionState
}

/// stopRecording 後、DB（upsert）保存が完了するまで保持する復旧情報（R20）。
/// 録音は停止済みだが保存に失敗した場合も、同じ sessionId による再試行で
/// 同じ DTO（id・recordedAt 固定）を保存し直せるようにする。成功時のみ除去する。
private struct MemoraPendingRecordingSave {
  let recorder: AVAudioRecorder
  let dto: MemoraAudioFileDTO

  var fileURL: URL {
    recorder.url
  }
}

public final class MemoraNativeFileRecordingImportHandler: NSObject, MemoraRecordingImportHandling {
  public let sourceDescription: String

  private var activeRecordings: [String: MemoraActiveRecording] = [:]
  /// R20: 停止済みだが DB upsert 未完了のセッション（sessionId キー）。
  private var pendingRecordingSaves: [String: MemoraPendingRecordingSave] = [:]
  private let recorderLock = NSLock()
  private let isoFormatter = ISO8601DateFormatter()
  private let storageDirectory: URL?
  private var interruptionObserver: NSObjectProtocol?

  /// `storageDirectory` is supplied by a host that owns a shared App Group.
  /// Leaving it nil preserves the native-files fallback in the app Documents directory.
  public init(storageDirectory: URL? = nil, sourceDescription: String = "native-file") {
    self.storageDirectory = storageDirectory
    self.sourceDescription = sourceDescription
    super.init()
    observeInterruptions()
  }

  deinit {
    if let interruptionObserver {
      NotificationCenter.default.removeObserver(interruptionObserver)
    }
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

    let startDate = Date()
    recorderLock.lock()
    activeRecordings[sessionId] = MemoraActiveRecording(
      recorder: recorder,
      startDate: startDate,
      state: .recording
    )
    recorderLock.unlock()

    return MemoraRecordingSessionDTO(
      id: sessionId,
      startedAt: isoFormatter.string(from: startDate),
      source: "iPhone"
    )
  }

  public func stopRecording(sessionId: String) throws -> MemoraAudioFileDTO {
    recorderLock.lock()
    let existingPendingSave = pendingRecordingSaves[sessionId]
    recorderLock.unlock()

    // R20: 前回の停止で DB 保存に失敗した場合の再試行。録音は停止済みのため、
    // 保存のみを同じ DTO で再実行する。
    if let existingPendingSave {
      let pendingSave = existingPendingSave
      return try finalizePendingSave(sessionId: sessionId, pendingSave: pendingSave)
    }

    recorderLock.lock()
    let recording = activeRecordings.removeValue(forKey: sessionId)
    recorderLock.unlock()
    guard let recording else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }

    recording.recorder.stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    // R20: 保存成功まで復旧情報（recorder/DTO）を保持する。成功時のみ pending から除去し、
    // 失敗時は同じ sessionId で stopRecording を再試行できる状態を保つ。
    let pendingSave = MemoraPendingRecordingSave(
      recorder: recording.recorder,
      dto: makeAudioFileDTO(
        id: UUID().uuidString,
        fileURL: recording.recorder.url,
        title: recordingTitle(for: recording.startDate),
        summary: ""
      )
    )
    recorderLock.lock()
    pendingRecordingSaves[sessionId] = pendingSave
    recorderLock.unlock()

    return try finalizePendingSave(sessionId: sessionId, pendingSave: pendingSave)
  }

  private func finalizePendingSave(
    sessionId: String,
    pendingSave: MemoraPendingRecordingSave
  ) throws -> MemoraAudioFileDTO {
    do {
      try MemoraNativeAudioFileMutationRegistry.audioFileMutator
        .upsertAudioFile(pendingSave.dto, fileURL: pendingSave.fileURL)
    } catch {
      // R20: 保存失敗時は pending を残したままエラーを返す（同じ sessionId で再試行可能）。
      throw error
    }

    recorderLock.lock()
    // 再試行中に discard 等で pending が差し替わっていた場合は誤って除去しない。
    if pendingRecordingSaves[sessionId]?.fileURL == pendingSave.fileURL {
      pendingRecordingSaves.removeValue(forKey: sessionId)
    }
    recorderLock.unlock()
    return pendingSave.dto
  }

  public func pauseRecording(sessionId: String) throws {
    recorderLock.lock()
    guard let recorder = activeRecordings[sessionId]?.recorder else {
      recorderLock.unlock()
      throw MemoraRecordingImportError.recordingSessionNotFound
    }
    recorderLock.unlock()
    recorder.pause()

    recorderLock.lock()
    // R18: ユーザーによる明示 pause は自動再開対象から外す。
    activeRecordings[sessionId]?.state = .pausedByUser
    recorderLock.unlock()
  }

  public func resumeRecording(sessionId: String) throws {
    recorderLock.lock()
    guard let recorder = activeRecordings[sessionId]?.recorder else {
      recorderLock.unlock()
      throw MemoraRecordingImportError.recordingSessionNotFound
    }
    recorderLock.unlock()
    guard recorder.record() else {
      throw MemoraRecordingImportError.recordingStartFailed
    }

    recorderLock.lock()
    activeRecordings[sessionId]?.state = .recording
    recorderLock.unlock()
  }

  public func discardRecording(sessionId: String) throws {
    recorderLock.lock()
    let recording = activeRecordings.removeValue(forKey: sessionId)
    let pendingSave = pendingRecordingSaves.removeValue(forKey: sessionId)
    recorderLock.unlock()

    guard recording != nil || pendingSave != nil else {
      throw MemoraRecordingImportError.recordingSessionNotFound
    }

    // R20: 保存に失敗した pending の破棄も、録音実体を削除して同じように扱う。
    if let recorder = recording?.recorder ?? pendingSave?.recorder {
      recorder.deleteRecording()
    }
    if recording != nil {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  public func importAudio(uri: String) throws -> MemoraAudioFileDTO {
    let sourceURL = makeURL(from: uri)
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw MemoraRecordingImportError.importFileNotFound
    }

    let destinationURL = try uniqueDestinationURL(for: sourceURL)
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

    let dto = makeAudioFileDTO(
      id: UUID().uuidString,
      fileURL: destinationURL,
      title: destinationURL.lastPathComponent,
      summary: ""
    )
    try MemoraNativeAudioFileMutationRegistry.audioFileMutator.upsertAudioFile(dto, fileURL: destinationURL)
    return dto
  }

  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
    try session.setActive(true)
  }

  private func observeInterruptions() {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
  }

  private func handleInterruption(_ notification: Notification) {
    recorderLock.lock()
    let hasActiveRecordings = !activeRecordings.isEmpty
    recorderLock.unlock()
    guard hasActiveRecordings else { return }
    guard
      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else {
      return
    }

    switch type {
    case .began:
      // The system pauses AVAudioRecorder automatically when the interruption begins.
      // R18: 録音中（ユーザー一時停止でない）セッションだけを「割込み停止」として記録する。
      recorderLock.lock()
      for sessionId in Array(activeRecordings.keys) {
        guard activeRecordings[sessionId]?.state == .recording else { continue }
        activeRecordings[sessionId]?.state = .interruptedBySystem
      }
      recorderLock.unlock()
    case .ended:
      let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      guard AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) else {
        // R18: 自動再開が許可されない割込みでは、割込み停止分を明示再開待ちへ戻す。
        markInterruptedBySystemAsPaused()
        return
      }
      resumeInterruptedBySystemRecordings()
    @unknown default:
      break
    }
  }

  private func markInterruptedBySystemAsPaused() {
    recorderLock.lock()
    for sessionId in Array(activeRecordings.keys)
    where activeRecordings[sessionId]?.state == .interruptedBySystem {
      activeRecordings[sessionId]?.state = .pausedAfterInterruption
    }
    recorderLock.unlock()
  }

  /// R18: 割込み終了（.ended + shouldResume）時に自動再開するのは、
  /// その割込みで停止された（interruptedBySystem の）録音だけ。ユーザーが明示的に
  /// pause した録音（pausedByUser）や、割込み終了済みの録音は再開しない。
  private func resumeInterruptedBySystemRecordings() {
    recorderLock.lock()
    let hasActiveRecordings = !activeRecordings.isEmpty
    let interruptedRecordings = activeRecordings.compactMap { sessionId, recording -> (String, AVAudioRecorder)? in
      guard recording.state == .interruptedBySystem else { return nil }
      return (sessionId, recording.recorder)
    }
    recorderLock.unlock()

    // 旧実装と同じく、割込み復帰時はアクティブ録音があればセッションを再有効化する。
    // これにより、自動再開対象が無い場合（全て pausedByUser 等）でも、
    // その後の明示的な resumeRecording が record() できる状態を維持する。
    guard hasActiveRecordings else { return }

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      markInterruptedBySystemAsPaused()
      return
    }

    for (sessionId, recorder) in interruptedRecordings {
      let resumed = recorder.record()
      recorderLock.lock()
      // 再開成功/失敗にかかわらず、この割込みサイクルの自動再開対象から外す。
      if activeRecordings[sessionId]?.state == .interruptedBySystem {
        activeRecordings[sessionId]?.state = resumed ? .recording : .pausedAfterInterruption
      }
      recorderLock.unlock()
    }
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

  /// DTO を組み立てるだけのヘルパー。DB 書き込み（upsert）は行わず、
  /// 呼び出し側（stopRecording の pending 保存 / importAudio）で明示的に行う。
  private func makeAudioFileDTO(id: String, fileURL: URL, title: String, summary: String) -> MemoraAudioFileDTO {
    MemoraAudioFileDTO(
      id: id,
      title: title,
      project: "Inbox",
      source: "iPhone",
      recordedAt: isoFormatter.string(from: Date()),
      duration: formattedDuration(for: fileURL),
      // STT is intentionally not started by this bridge. The file is queued
      // in the shared store for the following STT bridge phase.
      status: "queued",
      summary: summary,
      transcript: [],
      memo: []
    )
  }

  /// Generates a human-readable default title from the recording start time.
  /// Uses a numeric-only format with an explicit ja_JP locale so the title is
  /// stable regardless of the device locale.
  private func recordingTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "M/d H:mm"
    return "録音 " + formatter.string(from: date)
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
