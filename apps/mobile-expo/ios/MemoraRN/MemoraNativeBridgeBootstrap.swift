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
    MemoraNativeExportRegistry.exporter = MemoraRNExportHandler(
      keychain: MemoraRNKeychainSecureCredentials(),
      settingsStore: MemoraUserDefaultsSettingsStore()
    )
  }

  static func configureSharedAudioStoreOrDefaults() {
    let fileManager = FileManager.default
    let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let legacyStoreURL = MemoraSharedStoreLocation.storeURL(in: applicationSupport)
    let appGroupContainer = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: MemoraSharedStoreLocation.primaryAppGroupIdentifier
    )
    if appGroupContainer == nil {
      lastSharedStoreError = String(describing: MemoraSharedStoreLocation.Error.applicationGroupUnavailable(
        MemoraSharedStoreLocation.primaryAppGroupIdentifier
      ))
    }

    do {
      let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
        legacyStoreURL: legacyStoreURL,
        appGroupContainerURL: appGroupContainer,
        fileManager: fileManager
      )
      let storeMode = resolution.usesSharedStore ? "app-group" : "app-sandbox"
      try configureSwiftDataStore(at: resolution.storeURL, storeMode: storeMode)
      if appGroupContainer != nil {
        lastSharedStoreError = nil
      }
    } catch {
      lastSharedStoreError = String(describing: error)
      configureDefaults()
    }
  }

  private static func configureSwiftDataStore(
    at storeURL: URL,
    storeMode: String
  ) throws {
    let containerURL = storeURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
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
    let taskAdapter = MemoraSharedStoreTaskBridgeAdapter(container: container)
    MemoraNativeTaskReaderRegistry.taskReader = taskAdapter
    MemoraNativeTaskMutationRegistry.taskMutator = taskAdapter
    if let recordingImportHandler {
      MemoraNativeRecordingImportRegistry.handler = recordingImportHandler
    }
  }
}
