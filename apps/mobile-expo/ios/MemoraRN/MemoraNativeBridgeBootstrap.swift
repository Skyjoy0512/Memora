import Foundation
import SwiftData
internal import MemoraNative
import MemoraSharedData
import MemoraSharedSchema
import MemoraSharedSummary
import MemoraSharedAskAI

@MainActor
enum MemoraNativeBridgeBootstrap {
  static var lastSharedStoreError: String? {
    get { MemoraNativeBridgeDiagnostics.sharedStoreError }
    set { MemoraNativeBridgeDiagnostics.sharedStoreError = newValue }
  }

  static func makeSharedStoreContractProbe() -> any MemoraSharedAudioFileStore {
    MemoraInMemoryAudioFileStore()
  }

  static func configureDefaults() {
    MemoraNativeBridgeDiagnostics.storeMode = nil
    let nativeFileStore = MemoraNativeFileAudioFileStore()
    configure(
      audioFileReader: nativeFileStore,
      audioFileMutator: nativeFileStore,
      recordingImportHandler: MemoraNativeFileRecordingImportHandler(),
      settingsStore: MemoraUserDefaultsSettingsStore(),
      knowledgeQuery: MemoraSampleKnowledgeQuery(),
      summaryGenerator: MemoraUnavailableSummaryGenerator()
    )
    MemoraNativePlaybackRegistry.controller = MemoraAVAudioPlaybackController()
    MemoraNativeMemoRegistry.memoHandler = MemoraNativeFileMemoStore()
    MemoraNativeSecureCredentialRegistry.writer = MemoraRNKeychainSecureCredentials()
  }

  static func configureSharedAudioStoreOrDefaults() {
    do {
      guard let appGroupContainer = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: MemoraSharedStoreLocation.primaryAppGroupIdentifier
      ) else {
        throw MemoraSharedStoreLocation.Error.applicationGroupUnavailable(
          MemoraSharedStoreLocation.primaryAppGroupIdentifier
        )
      }
      try configureSwiftDataStore(in: appGroupContainer, storeMode: "app-group")
      lastSharedStoreError = nil
      return
    } catch {
      lastSharedStoreError = String(describing: error)
    }

    do {
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first!
      let sandboxContainer = applicationSupport.appendingPathComponent(
        "MemoraShared",
        isDirectory: true
      )
      try FileManager.default.createDirectory(
        at: sandboxContainer,
        withIntermediateDirectories: true
      )
      try configureSwiftDataStore(in: sandboxContainer, storeMode: "app-sandbox")
    } catch {
      configureDefaults()
    }
  }

  private static func configureSwiftDataStore(
    in containerURL: URL,
    storeMode: String
  ) throws {
    let storeURL = MemoraSharedStoreLocation.storeURL(in: containerURL)
    let audioDirectory = MemoraSharedStoreLocation.audioFilesDirectory(in: containerURL)
    let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
    configureDefaults()
    configureSharedAudioStore(
      MemoraSharedSwiftDataAudioFileStore(container: container),
      container: container,
      transcriptionHandler: MemoraRNTranscriptionHandler(
        container: container,
        audioDirectory: audioDirectory
      ),
      recordingImportHandler: MemoraNativeFileRecordingImportHandler(
        storageDirectory: audioDirectory,
        sourceDescription: "swiftdata"
      )
    )
    MemoraNativeBridgeDiagnostics.storeMode = storeMode
  }

  static func configure(
    audioFileReader: MemoraAudioFileReading,
    audioFileMutator: MemoraAudioFileMutating,
    recordingImportHandler: MemoraRecordingImportHandling,
    settingsStore: MemoraSettingsReadingWriting,
    knowledgeQuery: MemoraKnowledgeQuerying,
    summaryGenerator: MemoraSummaryGenerating
  ) {
    MemoraNativeAudioFileReaderRegistry.audioFileReader = audioFileReader
    MemoraNativeAudioFileMutationRegistry.audioFileMutator = audioFileMutator
    MemoraNativeRecordingImportRegistry.handler = recordingImportHandler
    MemoraNativeSettingsRegistry.settingsStore = settingsStore
    MemoraNativeKnowledgeQueryRegistry.knowledgeQuery = knowledgeQuery
    MemoraNativeSummaryRegistry.summaryGenerator = summaryGenerator
    MemoraNativeTranscriptionRegistry.handler = MemoraUnavailableTranscriptionHandler()
  }

  static func configureSharedAudioStore(
    _ store: any MemoraSharedAudioFileStore,
    container: ModelContainer,
    transcriptionHandler: MemoraTranscriptionHandling,
    recordingImportHandler: MemoraRecordingImportHandling? = nil
  ) {
    let adapter = MemoraSharedStoreBridgeAdapter(store: store, container: container)
    MemoraNativeCustomVocabularyRegistry.manager = MemoraSharedStoreCustomVocabularyManager(container: container)
    MemoraNativeAudioFileReaderRegistry.audioFileReader = adapter
    MemoraNativeAudioFileMutationRegistry.audioFileMutator = adapter
    MemoraNativeTranscriptionRegistry.handler = transcriptionHandler
    MemoraNativeSummaryRegistry.summaryGenerator = MemoraSharedStoreSummaryGenerator(container: container)
    MemoraNativeKnowledgeQueryRegistry.knowledgeQuery = MemoraSharedStoreKnowledgeQuery(container: container)
    if let recordingImportHandler {
      MemoraNativeRecordingImportRegistry.handler = recordingImportHandler
    }
  }
}
