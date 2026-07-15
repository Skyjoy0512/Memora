import Foundation
internal import MemoraNative
import MemoraSharedData
import MemoraSharedSchema

enum MemoraNativeBridgeBootstrap {
  static func makeSharedStoreContractProbe() -> any MemoraSharedAudioFileStore {
    MemoraInMemoryAudioFileStore()
  }

  static func configureDefaults() {
    let nativeFileStore = MemoraNativeFileAudioFileStore()
    configure(
      audioFileReader: nativeFileStore,
      audioFileMutator: nativeFileStore,
      recordingImportHandler: MemoraNativeFileRecordingImportHandler(),
      settingsStore: MemoraUserDefaultsSettingsStore(),
      knowledgeQuery: MemoraSampleKnowledgeQuery(),
      summaryGenerator: MemoraSampleSummaryGenerator()
    )
    MemoraNativePlaybackRegistry.controller = MemoraAVAudioPlaybackController()
    MemoraNativeMemoRegistry.memoHandler = MemoraNativeFileMemoStore()
  }

  static func configureSharedAudioStoreOrDefaults() {
    do {
      guard let appGroupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: MemoraSharedStoreLocation.primaryAppGroupIdentifier
      ) else {
        throw MemoraSharedStoreLocation.Error.applicationGroupUnavailable(
          MemoraSharedStoreLocation.primaryAppGroupIdentifier
        )
      }
      let storeURL = try MemoraSharedStoreLocation.applicationGroupStoreURL(
        groupIdentifier: MemoraSharedStoreLocation.primaryAppGroupIdentifier
      )
      let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
      configureDefaults()
      configureSharedAudioStore(
        MemoraSharedSwiftDataAudioFileStore(container: container),
        recordingImportHandler: MemoraNativeFileRecordingImportHandler(
          storageDirectory: MemoraSharedStoreLocation.audioFilesDirectory(in: appGroupURL),
          sourceDescription: "swiftdata"
        )
      )
    } catch {
      configureDefaults()
    }
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
  }

  static func configureSharedAudioStore(
    _ store: any MemoraSharedAudioFileStore,
    recordingImportHandler: MemoraRecordingImportHandling? = nil
  ) {
    let adapter = MemoraSharedStoreBridgeAdapter(store: store)
    MemoraNativeAudioFileReaderRegistry.audioFileReader = adapter
    MemoraNativeAudioFileMutationRegistry.audioFileMutator = adapter
    if let recordingImportHandler {
      MemoraNativeRecordingImportRegistry.handler = recordingImportHandler
    }
  }
}
