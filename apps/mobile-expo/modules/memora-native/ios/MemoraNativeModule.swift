import Foundation
import ExpoModulesCore

public class MemoraNativeModule: Module {

  public func definition() -> ModuleDefinition {
    Name("MemoraNative")

    Events("onTranscriptionEvent")

    AsyncFunction("listAudioFiles") { () -> [[String: Any]] in
      try self.audioFileReader.listAudioFiles().map { $0.asDictionary() }
    }

    AsyncFunction("getAudioFile") { (id: String) -> [String: Any]? in
      try self.audioFileReader.getAudioFile(id: id)?.asDictionary()
    }

    AsyncFunction("renameAudioFile") { (id: String, title: String) -> [String: Any]? in
      try self.audioFileMutator.renameAudioFile(id: id, title: title)?.asDictionary()
    }

    AsyncFunction("moveAudioFile") { (id: String, projectId: String?) -> [String: Any]? in
      try self.audioFileMutator.moveAudioFile(id: id, projectId: projectId)?.asDictionary()
    }

    AsyncFunction("deleteAudioFile") { (id: String) -> Bool in
      try self.audioFileMutator.deleteAudioFile(id: id)
    }

    AsyncFunction("getBridgeInfo") { () -> [String: Any] in
      [
        "platform": "ios",
        "moduleName": "MemoraNative",
        "moduleVersion": "1.0.0",
        "audioFileSource": self.audioFileReader.sourceDescription,
        "audioFileMutationSource": self.audioFileMutator.sourceDescription,
        "recordingSource": self.recordingImportHandler.sourceDescription,
        "settingsSource": self.settingsStore.sourceDescription,
        "knowledgeQuerySource": self.knowledgeQuery.sourceDescription,
        "summarySource": self.summaryGenerator.sourceDescription,
        "retryQueueSource": self.retryQueue.sourceDescription,
        "persistenceScope": self.persistenceScope,
        "isRealDataConnected": self.isRealDataConnected
      ]
    }

    AsyncFunction("loadSettings") { () -> [String: Any] in
      try self.settingsStore.loadSettings().asDictionary()
    }

    AsyncFunction("saveSettings") { (settings: [String: Any]) -> Void in
      try self.settingsStore.saveSettings(MemoraSettingsDTO(dictionary: settings))
    }

    AsyncFunction("getSecureCredentialStatus") { (providerValue: String) -> Bool in
      guard let provider = MemoraSecureCredentialProvider(bridgeValue: providerValue) else { return false }
      return try MemoraNativeSecureCredentialRegistry.writer.isCredentialConfigured(for: provider)
    }

    AsyncFunction("deleteSecureCredential") { (providerValue: String) -> Bool in
      guard let provider = MemoraSecureCredentialProvider(bridgeValue: providerValue) else { return false }
      try MemoraNativeSecureCredentialRegistry.writer.deleteCredential(for: provider)
      return true
    }

    AsyncFunction("presentSecureCredentialInput") { (providerValue: String) async throws -> Bool in
      guard let provider = MemoraSecureCredentialProvider(bridgeValue: providerValue) else { throw MemoraSecureCredentialError.unavailable }
      let viewController = self.appContext?.utilities?.currentViewController()
      return try await MemoraSecureCredentialInputPresenter().present(provider: provider, from: viewController)
    }

    AsyncFunction("startRecording") { () -> [String: Any] in
      try self.recordingImportHandler.startRecording().asDictionary()
    }

    AsyncFunction("pauseRecording") { (sessionId: String) -> Void in
      try self.recordingImportHandler.pauseRecording(sessionId: sessionId)
    }

    AsyncFunction("resumeRecording") { (sessionId: String) -> Void in
      try self.recordingImportHandler.resumeRecording(sessionId: sessionId)
    }

    AsyncFunction("discardRecording") { (sessionId: String) -> Void in
      try self.recordingImportHandler.discardRecording(sessionId: sessionId)
    }

    AsyncFunction("stopRecording") { (sessionId: String) -> [String: Any] in
      try self.recordingImportHandler.stopRecording(sessionId: sessionId).asDictionary()
    }

    AsyncFunction("importAudio") { (uri: String) -> [String: Any] in
      try self.recordingImportHandler.importAudio(uri: uri).asDictionary()
    }

    AsyncFunction("queryKnowledge") { (request: [String: Any]) async throws -> [String: Any] in
      try await self.knowledgeQuery
        .queryKnowledge(MemoraKnowledgeQueryRequestDTO(dictionary: request))
        .asDictionary()
    }

    AsyncFunction("generateSummary") { (request: [String: Any]) async throws -> [String: Any] in
      try await self.summaryGenerator
        .generateSummary(MemoraSummaryRequestDTO(dictionary: request))
        .asDictionary()
    }

    AsyncFunction("startTranscription") { (audioFileId: String) async throws -> [String: Any] in
      let task = try await self.transcriptionHandler.startTranscription(audioFileId: audioFileId) { [weak self] event in
        self?.sendEvent("onTranscriptionEvent", event.asDictionary())
      }
      return task.asDictionary()
    }

    AsyncFunction("cancelTranscription") { (taskId: String) async -> Void in
      await self.transcriptionHandler.cancelTranscription(taskId: taskId)
    }

    AsyncFunction("loadPlayback") { (audioFileId: String) -> [String: Any] in
      try self.playbackController.load(audioFileId: audioFileId).asDictionary()
    }

    AsyncFunction("playPlayback") { () -> [String: Any] in
      try self.playbackController.play().asDictionary()
    }

    AsyncFunction("pausePlayback") { () -> [String: Any] in
      try self.playbackController.pause().asDictionary()
    }

    AsyncFunction("seekPlayback") { (position: Double) -> [String: Any] in
      try self.playbackController.seek(to: position).asDictionary()
    }

    AsyncFunction("setPlaybackRate") { (rate: Double) -> [String: Any] in
      try self.playbackController.setRate(rate).asDictionary()
    }

    AsyncFunction("getPlaybackStatus") { () -> [String: Any] in
      try self.playbackController.getStatus().asDictionary()
    }

    AsyncFunction("getMemoDraft") { (audioFileId: String) -> String in
      try self.memoHandler.getMemoDraft(audioFileId: audioFileId)
    }

    AsyncFunction("saveMemoDraft") { (audioFileId: String, text: String) -> Void in
      try self.memoHandler.saveMemoDraft(audioFileId: audioFileId, text: text)
    }

    AsyncFunction("listPhotoAttachments") { (audioFileId: String) -> [[String: Any]] in
      try self.memoHandler.listPhotoAttachments(audioFileId: audioFileId).map { $0.asDictionary() }
    }

    AsyncFunction("addPhotoAttachment") { (audioFileId: String, sourceUri: String) -> [String: Any] in
      try self.memoHandler.addPhotoAttachment(audioFileId: audioFileId, sourceUri: sourceUri).asDictionary()
    }

    AsyncFunction("deletePhotoAttachment") { (audioFileId: String, attachmentId: String) -> Bool in
      try self.memoHandler.deletePhotoAttachment(audioFileId: audioFileId, attachmentId: attachmentId)
    }

    AsyncFunction("enqueueProcessingRetry") { (request: [String: Any]) -> [String: Any] in
      try self.retryQueue.enqueue(
        audioFileId: request["audioFileId"] as? String ?? "",
        operation: request["operation"] as? String ?? "",
        lastError: request["lastError"] as? String
      ).asDictionary()
    }

    AsyncFunction("listProcessingRetries") { () -> [[String: Any]] in
      try self.retryQueue.list().map { $0.asDictionary() }
    }

    AsyncFunction("recordProcessingRetryFailure") { (id: String, lastError: String) -> [String: Any]? in
      try self.retryQueue.recordFailedAttempt(id: id, lastError: lastError)?.asDictionary()
    }

    AsyncFunction("completeProcessingRetry") { (id: String) -> Bool in
      try self.retryQueue.complete(id: id)
    }
  }

  private var audioFileReader: MemoraAudioFileReading {
    MemoraNativeAudioFileReaderRegistry.audioFileReader
  }

  private var audioFileMutator: MemoraAudioFileMutating {
    MemoraNativeAudioFileMutationRegistry.audioFileMutator
  }

  private var settingsStore: MemoraSettingsReadingWriting {
    MemoraNativeSettingsRegistry.settingsStore
  }

  private var recordingImportHandler: MemoraRecordingImportHandling {
    MemoraNativeRecordingImportRegistry.handler
  }

  private var knowledgeQuery: MemoraKnowledgeQuerying {
    MemoraNativeKnowledgeQueryRegistry.knowledgeQuery
  }

  private var summaryGenerator: MemoraSummaryGenerating {
    MemoraNativeSummaryRegistry.summaryGenerator
  }

  private var playbackController: MemoraPlaybackControlling {
    MemoraNativePlaybackRegistry.controller
  }

  private var memoHandler: MemoraMemoHandling {
    MemoraNativeMemoRegistry.memoHandler
  }

  private var retryQueue: MemoraProcessingRetryQueueing {
    MemoraNativeProcessingRetryRegistry.queue
  }

  private var transcriptionHandler: MemoraTranscriptionHandling {
    MemoraNativeTranscriptionRegistry.handler
  }

  private var persistenceScope: String {
    if isSharedSwiftDataConnected {
      return "shared-swiftdata"
    }

    if audioFileReader.sourceDescription == "native-files" || audioFileMutator.sourceDescription == "native-files" {
      return "app-sandbox"
    }

    return "mock"
  }

  private var isRealDataConnected: Bool {
    isSharedSwiftDataConnected
  }

  private var isSharedSwiftDataConnected: Bool {
    audioFileReader.sourceDescription == "swiftdata" &&
      audioFileMutator.sourceDescription == "swiftdata" &&
      recordingImportHandler.sourceDescription == "swiftdata"
  }

}
