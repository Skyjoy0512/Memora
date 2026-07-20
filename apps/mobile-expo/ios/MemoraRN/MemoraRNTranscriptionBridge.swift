import Foundation
import Speech
import SwiftData
import AVFoundation
internal import MemoraNative
import MemoraSharedCore
import MemoraSharedSchema

@MainActor
final class MemoraRNTranscriptionHandler: MemoraTranscriptionHandling {
  let sourceDescription = "swiftdata"

  private let container: ModelContainer
  private let audioDirectory: URL
  private let sttService: STTService
  private var activeTasks: [String: STTTaskHandle] = [:]

  init(container: ModelContainer, audioDirectory: URL) {
    self.container = container
    self.audioDirectory = audioDirectory.standardizedFileURL
    self.sttService = MemoraRNSTTServiceFactory.makeLocalService()
  }

  func startTranscription(
    audioFileId: String,
    emit: @escaping (MemoraTranscriptionEventDTO) -> Void
  ) async throws -> MemoraTranscriptionTaskDTO {
    guard let id = UUID(uuidString: audioFileId) else {
      throw MemoraRNTranscriptionBridgeError.invalidAudioFileID
    }

    let audioURL = try await resolveAudioURL(for: id)
    sttService.updateConfiguration(apiKey: "", provider: .openai, transcriptionMode: .local)
    let (rawHandle, events) = try await sttService.startTranscription(audioURL: audioURL, language: nil)
    guard let handle = rawHandle as? STTTaskHandle else {
      throw MemoraRNTranscriptionBridgeError.invalidTaskHandle
    }

    let taskId = handle.taskId
    activeTasks[taskId] = handle
    emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "started", progress: 0, message: "文字起こしを開始しました"))

    Task { @MainActor [weak self] in
      for await event in events {
        self?.forward(event, taskId: taskId, audioFileId: audioFileId, emit: emit)
      }
    }

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let result = try await handle.result()
        try self.persist(result: result, audioFileID: id)
        emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "completed", progress: 1, message: "文字起こしを保存しました"))
      } catch is CancellationError {
        emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "cancelled", progress: 0, message: "文字起こしをキャンセルしました"))
      } catch {
        emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "failed", progress: 0, message: error.localizedDescription))
      }
      self.activeTasks.removeValue(forKey: taskId)
    }

    return MemoraTranscriptionTaskDTO(id: taskId, audioFileId: audioFileId, status: "running", progress: 0)
  }

  func cancelTranscription(taskId: String) async {
    guard let handle = activeTasks[taskId] else { return }
    await handle.cancel()
  }

  private func resolveAudioURL(for id: UUID) async throws -> URL {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == id })
    guard let file = try context.fetch(descriptor).first else {
      throw MemoraRNTranscriptionBridgeError.audioFileNotFound
    }
    let paths = file.segmentPaths.isEmpty ? [file.audioURL] : file.segmentPaths
    let urls = paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
    let rootPath = audioDirectory.path.hasSuffix("/") ? audioDirectory.path : audioDirectory.path + "/"
    guard urls.allSatisfy({ $0.path.hasPrefix(rootPath) && FileManager.default.fileExists(atPath: $0.path) }) else {
      throw MemoraRNTranscriptionBridgeError.audioURLNotInSharedGroup
    }
    guard urls.count > 1 else {
      guard let url = urls.first else { throw MemoraRNTranscriptionBridgeError.audioURLNotInSharedGroup }
      return url
    }
    return try await concatenate(urls, for: id)
  }

  private func concatenate(_ urls: [URL], for id: UUID) async throws -> URL {
    let composition = AVMutableComposition()
    guard let destination = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      throw MemoraRNTranscriptionBridgeError.segmentConcatenationFailed
    }
    var insertionTime = CMTime.zero
    for url in urls {
      let asset = AVURLAsset(url: url)
      let tracks = try await asset.loadTracks(withMediaType: .audio)
      guard let source = tracks.first else { throw MemoraRNTranscriptionBridgeError.segmentConcatenationFailed }
      let duration = try await asset.load(.duration)
      try destination.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: insertionTime)
      insertionTime = CMTimeAdd(insertionTime, duration)
    }
    let directory = audioDirectory.appendingPathComponent("SegmentCompositions", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let outputURL = directory.appendingPathComponent("\(id.uuidString).m4a")
    try? FileManager.default.removeItem(at: outputURL)
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
      throw MemoraRNTranscriptionBridgeError.segmentConcatenationFailed
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .m4a
    await withCheckedContinuation { continuation in
      exporter.exportAsynchronously { continuation.resume() }
    }
    guard exporter.status == .completed else { throw MemoraRNTranscriptionBridgeError.segmentConcatenationFailed }
    return outputURL
  }

  private func persist(result: TranscriptionResult, audioFileID: UUID) throws {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<AudioFile>(predicate: #Predicate { $0.id == audioFileID })
    guard let audioFile = try context.fetch(descriptor).first else {
      throw MemoraRNTranscriptionBridgeError.audioFileNotFound
    }

    let transcript = audioFile.transcripts.first ?? Transcript(audioFileID: audioFile.id, text: result.fullText)
    if transcript.audioFile == nil {
      transcript.audioFile = audioFile
      context.insert(transcript)
    }
    transcript.text = result.fullText
    transcript.replaceSpeakerSegments(result.segments)
    let cleaned = TranscriptPostProcessor().process(result)
    let vocabulary = try context.fetch(FetchDescriptor<CustomVocabulary>())
    let vocabularyApplier = MemoraCustomVocabularyApplier(vocabulary: vocabulary)
    transcript.cleanedText = vocabularyApplier.apply(to: cleaned.fullText)
    transcript.cleanedSegmentTexts = cleaned.segments.map { vocabularyApplier.apply(to: $0.text) }
    audioFile.isTranscribed = true
    try context.save()
  }

  private func forward(
    _ event: STTEvent,
    taskId: String,
    audioFileId: String,
    emit: (MemoraTranscriptionEventDTO) -> Void
  ) {
    switch event {
    case .transcriptionStarted:
      break
    case .transcriptionProgress(_, let progress):
      emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "progress", progress: progress, message: "文字起こしを処理中です"))
    case .transcriptionPartialResult(_, let text):
      emit(MemoraTranscriptionEventDTO(taskId: taskId, audioFileId: audioFileId, type: "progress", progress: 0, message: text))
    case .audioChunkStarted, .audioChunkProgress, .audioChunkCompleted:
      break
    case .transcriptionCompleted, .transcriptionFailed, .transcriptionCancelled:
      // completed is emitted only after the SwiftData transaction succeeds.
      break
    }
  }
}

private extension Transcript {
  func replaceSpeakerSegments(_ segments: [TranscriptionSegment]) {
    replaceSpeakerSegments(
      speakerLabels: segments.map(\.speakerLabel),
      startTimes: segments.map(\.startSec),
      endTimes: segments.map(\.endSec),
      texts: segments.map(\.text)
    )
  }
}

private enum MemoraRNTranscriptionBridgeError: LocalizedError {
  case invalidAudioFileID
  case audioFileNotFound
  case audioURLNotInSharedGroup
  case segmentConcatenationFailed
  case invalidTaskHandle

  var errorDescription: String? {
    switch self {
    case .invalidAudioFileID: return "Audio file ID is invalid."
    case .audioFileNotFound: return "Audio file was not found in the shared store."
    case .audioURLNotInSharedGroup: return "Audio file is not available in the shared App Group."
    case .segmentConcatenationFailed: return "Audio segments could not be prepared for transcription."
    case .invalidTaskHandle: return "Native transcription task could not be created."
    }
  }
}

enum MemoraRNSTTServiceFactory {
  static func makeLocalService() -> STTService {
    let dependencies = STTReadOnlyHostDependencies(
      logger: MemoraRNNoopLogger(),
      consoleLogger: MemoraRNNoopConsoleLogger(),
      settings: MemoraRNLocalSTTSettings(),
      diagnostics: MemoraRNNoopDiagnostics()
    )
    let executionDependencies = STTServiceExecutionDependencies(
      backend: STTBackendExecutionDependencies(
        remoteTranscriber: MemoraRNUnavailableRemoteTranscriber(),
        localBackendFactory: MemoraRNLocalBackendFactory(),
        speechAnalyzerPreflight: MemoraRNSpeechAnalyzerDisabledPreflight()
      ),
      diarizationService: MemoraRNNoopDiarizationService()
    )
    return STTService(
      readiness: STTReadiness(),
      chunkerFactory: { AudioChunker() },
      dependencies: dependencies,
      capabilities: STTExecutionHostCapabilities(
        backgroundTasks: MemoraRNNoopBackgroundTasks(),
        idleTimer: MemoraRNNoopIdleTimer(),
        memoryWarnings: MemoraRNNoopMemoryWarnings(),
        progress: MemoraRNNoopProgressPresenter()
      ),
      executionDependencies: executionDependencies
    )
  }
}

private struct MemoraRNNoopLogger: STTLogging { func log(_ category: String, _ message: String, level: STTLogLevel) {} }
private struct MemoraRNNoopConsoleLogger: STTConsoleLogging { func logDetailed(_ message: @autoclosure () -> String) {} }
private struct MemoraRNLocalSTTSettings: STTSettingsProviding { let isSpeechAnalyzerEnabled = false; let isSpeakerDiarizationEnabled = false; let contextualVocabulary: [String] = [] }
private struct MemoraRNNoopDiagnostics: STTDiagnosticsRecording { func record(_ entry: STTBackendDiagnosticEntry) {} }
private struct MemoraRNNoopBackgroundTasks: STTBackgroundTaskManaging { @MainActor func beginBackgroundTask(named name: String, expirationHandler: @escaping @Sendable () -> Void) -> STTBackgroundTaskToken? { nil }; @MainActor func endBackgroundTask(_ token: STTBackgroundTaskToken) {} }
private struct MemoraRNNoopIdleTimer: STTIdleTimerManaging { @MainActor func setIdleTimerDisabled(_ isDisabled: Bool) {} }
private struct MemoraRNNoopMemoryWarnings: STTMemoryWarningObserving { func observeMemoryWarnings(_ handler: @escaping @Sendable () -> Void) {} }
private struct MemoraRNNoopProgressPresenter: STTProgressPresenting { @MainActor func start(fileName: String, totalChunks: Int) {}; @MainActor func update(progress: Double, currentChunk: Int, totalChunks: Int) {}; @MainActor func finish(success: Bool, characterCount: Int) {} }
private struct MemoraRNNoopDiarizationService: SpeakerDiarizationProtocol { func detectSpeakers(audioURL: URL, segments: [TranscriptionSegment], numSpeakers: Int?) async -> [TranscriptionSegment] { segments } }
private struct MemoraRNUnavailableRemoteTranscriber: RemoteTranscribing { func transcribe(_ request: RemoteTranscriptionRequest) async throws -> String { throw CoreError.transcriptionError(.transcriptionFailed("API transcription is not configured for MemoraRN.")) } }
private struct MemoraRNUnavailableSpeechAnalyzer: SpeechAnalyzerTranscribing { func transcribe(audioURL: URL) async throws -> String { throw CoreError.transcriptionError(.transcriptionFailed("SpeechAnalyzer is disabled for MemoraRN local transcription.")) } }
private struct MemoraRNLocalBackendFactory: LocalSTTBackendFactory { @available(iOS 26.0, *) func makeSpeechAnalyzerTranscriber(locale: Locale) -> any SpeechAnalyzerTranscribing { MemoraRNUnavailableSpeechAnalyzer() }; func makeSpeechRecognizer(locale: Locale) -> SFSpeechRecognizer? { SFSpeechRecognizer(locale: locale) } }
private struct MemoraRNSpeechAnalyzerDisabledPreflight: SpeechAnalyzerPreflighting {
  func run(locale: Locale) async -> SpeechAnalyzerPreflightResult { .unavailable(reason: .featureFlagOff, diagnostics: diagnosticsValue(locale: locale)) }
  func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics { diagnosticsValue(locale: locale) }
  private func diagnosticsValue(locale: Locale) -> SpeechAnalyzerDiagnostics { SpeechAnalyzerDiagnostics(isTranscriberAvailable: false, featureFlagEnabled: false, requestedLocale: locale.identifier, supportedLocale: nil, assetStatus: "disabled", compatibleFormatsDescription: "", unavailableReason: .featureFlagOff, checkedAt: Date(), checkDurationMs: 0) }
}
