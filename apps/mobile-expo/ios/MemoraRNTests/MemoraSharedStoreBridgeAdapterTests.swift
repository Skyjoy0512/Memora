import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import MemoraRN
import MemoraSharedCore
import MemoraSharedData
import MemoraSharedSchema
@testable import MemoraNative

@Suite("RN SpeechAnalyzer bridge")
struct MemoraRNSpeechAnalyzerBridgeTests {
  @Test("unsupported runtime returns a safe unavailable result")
  func unsupportedRuntimeFallsBackWithoutTrap() async {
    let locale = Locale(identifier: "ja_JP")
    let preflight = MemoraRNSpeechAnalyzerPreflight(
      featureEnabled: true,
      isSpeechAnalyzerRuntimeAvailable: { false }
    )

    let result = await preflight.run(locale: locale)
    guard case let .unavailable(reason, diagnostics) = result else {
      Issue.record("Unsupported runtime unexpectedly returned ready")
      return
    }
    guard case .notAvailable = reason else {
      Issue.record("Unsupported runtime returned an unexpected reason: \(reason)")
      return
    }

    #expect(diagnostics.isTranscriberAvailable == false)
    #expect(diagnostics.featureFlagEnabled == true)
    #expect(diagnostics.requestedLocale == locale.identifier)
    #expect(diagnostics.assetStatus == "unsupported-os")
    #expect(diagnostics.compatibleFormatsDescription == "not checked")
    #expect(diagnostics.unavailableReason?.description == reason.description)

    let diagnosticsOnly = await preflight.diagnostics(for: locale)
    #expect(diagnosticsOnly.unavailableReason?.description == reason.description)
  }

  @Test("diagnostic public payload excludes sensitive fields")
  func diagnosticPublicPayloadExcludesSensitiveFields() {
    let privateTaskID = "private-task-id"
    let privateLocale = "private-locale"
    let privateModelState = "private-model-state"
    let privateAudioFormat = "private-audio-format"
    let privateFallbackReason = "asset installation failed with a private raw error"
    let privateProcessingTime = 123.456
    let entry = STTBackendDiagnosticEntry(
      taskId: privateTaskID,
      backend: .speechAnalyzer,
      locale: privateLocale,
      assetState: privateModelState,
      audioFormat: privateAudioFormat,
      fallbackReason: privateFallbackReason,
      processingTimeMs: privateProcessingTime,
      recordedAt: Date(timeIntervalSince1970: 0)
    )

    let payload = MemoraRNSTTDiagnosticPayload(entry: entry)

    #expect(payload.publicSummary == "backend=SpeechAnalyzer fallback=assetNotInstalled")
    #expect(payload.publicSummary.contains(privateTaskID) == false)
    #expect(payload.publicSummary.contains(privateLocale) == false)
    #expect(payload.publicSummary.contains(privateModelState) == false)
    #expect(payload.publicSummary.contains(privateAudioFormat) == false)
    #expect(payload.publicSummary.contains(privateFallbackReason) == false)
    #expect(payload.publicSummary.contains(String(privateProcessingTime)) == false)
  }
}

@Suite("RN shared store bridge adapter")
struct MemoraSharedStoreBridgeAdapterTests {
  @Test("mock store source is preserved and records map to bridge DTOs")
  func mapsRecordsAndPreservesSource() throws {
    let id = UUID()
    let record = MemoraSharedAudioFileRecord(
      id: id,
      title: "RN adapter test",
      createdAt: Date(timeIntervalSince1970: 1_000),
      duration: 125,
      audioURL: "/tmp/test.m4a",
      isTranscribed: true,
      isSummarized: true,
      summary: "Summary"
    )
    let adapter = MemoraSharedStoreBridgeAdapter(
      store: MemoraInMemoryAudioFileStore(records: [record])
    )

    #expect(adapter.sourceDescription == "mock")
    let fetched = try adapter.getAudioFile(id: id.uuidString)
    let dto = try #require(fetched)
    #expect(dto.id == id.uuidString)
    #expect(dto.title == "RN adapter test")
    #expect(dto.duration == "02:05")
    #expect(dto.status == "ready")
    #expect(dto.summary == "Summary")
    // R11: memo はユーザーメモ専用。内部の格納パス（Stored path）を載せず、
    // actionItems は SwiftData 未接続時は空配列のまま。
    #expect(dto.memo.isEmpty)
    #expect(dto.actionItems.isEmpty)
  }

  @Test("R11: SwiftData の actionItems を行単位の明示フィールドとして読み出す")
  func actionItemsAreReadFromSwiftDataEntityAsExplicitDTOField() throws {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let file = AudioFile(title: "Action fixture", audioURL: "/tmp/actions.m4a")
    file.summary = "Summary"
    file.isSummarized = true
    file.actionItems = "alpha\n\n  beta  \n"
    context.insert(file)
    try context.save()

    let store = MemoraSharedSwiftDataAudioFileStore(container: container)
    let adapter = MemoraSharedStoreBridgeAdapter(store: store, container: container)
    let dto = try #require(try adapter.getAudioFile(id: file.id.uuidString))
    #expect(dto.memo.isEmpty)
    #expect(dto.actionItems == ["alpha", "beta"])
    #expect(dto.summary == "Summary")
  }

  @Test("playback paths are resolved from the same shared record as the DTO")
  func resolvesPlaybackPathsFromSharedStore() throws {
    let singleFileID = UUID()
    let segmentedFileID = UUID()
    let adapter = MemoraSharedStoreBridgeAdapter(
      store: MemoraInMemoryAudioFileStore(records: [
        MemoraSharedAudioFileRecord(
          id: singleFileID,
          title: "Single",
          createdAt: Date(),
          duration: 1,
          audioURL: "/tmp/single.m4a"
        ),
        MemoraSharedAudioFileRecord(
          id: segmentedFileID,
          title: "Segmented",
          createdAt: Date(),
          duration: 2,
          audioURL: "/tmp/legacy-primary.m4a",
          segmentPaths: ["/tmp/segment-1.m4a", "/tmp/segment-2.m4a"]
        )
      ])
    )

    #expect(try adapter.playbackFilePaths(forId: singleFileID.uuidString) == ["/tmp/single.m4a"])
    #expect(try adapter.playbackFilePaths(forId: segmentedFileID.uuidString) == [
      "/tmp/segment-1.m4a", "/tmp/segment-2.m4a"
    ])
    #expect(try adapter.playbackFilePaths(forId: UUID().uuidString).isEmpty)
  }

  @Test("native playback loads a SwiftData-owned audio path without JSON metadata")
  func loadsPlaybackFromSharedStoreWithoutNativeMetadata() throws {
    let id = UUID()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-playback-tests-\(UUID().uuidString)", isDirectory: true)
    let firstSegmentURL = directory.appendingPathComponent("segment-1.wav")
    let secondSegmentURL = directory.appendingPathComponent("segment-2.wav")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try writeSilentAudio(to: firstSegmentURL)
    try writeSilentAudio(to: secondSegmentURL)

    let adapter = MemoraSharedStoreBridgeAdapter(
      store: MemoraInMemoryAudioFileStore(records: [
        MemoraSharedAudioFileRecord(
          id: id,
          title: "SwiftData only",
          createdAt: Date(),
          duration: 0.2,
          audioURL: firstSegmentURL.path,
          segmentPaths: [firstSegmentURL.path, secondSegmentURL.path]
        )
      ])
    )
    let originalReader = MemoraNativeAudioFileReaderRegistry.audioFileReader
    defer { MemoraNativeAudioFileReaderRegistry.audioFileReader = originalReader }
    MemoraNativeAudioFileReaderRegistry.audioFileReader = adapter

    let controller = MemoraAVAudioPlaybackController()
    let status = try controller.load(audioFileId: id.uuidString)
    #expect(status.audioFileId == id.uuidString)
    #expect(status.duration > 0.15)

    let soughtStatus = try controller.seek(to: 0.11)
    #expect(soughtStatus.position >= 0.1)
  }

  @Test("audio session is activated at play time, not at load (R19)")
  func configuresAudioSessionOnlyWhenPlayStarts() throws {
    let id = UUID()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-playback-session-tests-\(UUID().uuidString)", isDirectory: true)
    let segmentURL = directory.appendingPathComponent("segment.wav")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try writeSilentAudio(to: segmentURL)

    let adapter = MemoraSharedStoreBridgeAdapter(
      store: MemoraInMemoryAudioFileStore(records: [
        MemoraSharedAudioFileRecord(
          id: id,
          title: "Session deferral",
          createdAt: Date(),
          duration: 0.1,
          audioURL: segmentURL.path,
          segmentPaths: [segmentURL.path]
        )
      ])
    )
    let originalReader = MemoraNativeAudioFileReaderRegistry.audioFileReader
    defer { MemoraNativeAudioFileReaderRegistry.audioFileReader = originalReader }
    MemoraNativeAudioFileReaderRegistry.audioFileReader = adapter

    let controller = MemoraAVAudioPlaybackController()
    var activationCount = 0
    controller.activateAudioSessionForPlayback = {
      activationCount += 1
    }

    _ = try controller.load(audioFileId: id.uuidString)
    #expect(activationCount == 0, "詳細表示（load）では AudioSession を変更しない")

    _ = try controller.play()
    #expect(activationCount == 1, "play で初めて再生用セッションへ切り替える")

    _ = try controller.pause()
    _ = try controller.seek(to: 0.05)
    #expect(activationCount == 1, "pause / seek では再設定しない")

    _ = try controller.play()
    #expect(activationCount == 2, "一時停止後の再開（play）でも設定できる")
  }

  private func writeSilentAudio(to url: URL) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)!
    buffer.frameLength = 4410
    if let channelData = buffer.floatChannelData {
      for i in 0..<Int(buffer.frameLength) {
        channelData[0][i] = 0.0
      }
    }
    let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
    try audioFile.write(from: buffer)
  }

  @Test("rename, move, and delete mutate the injected shared store")
  func mutatesInjectedStore() throws {
    let id = UUID()
    let projectId = UUID()
    let store = MemoraInMemoryAudioFileStore(records: [
      MemoraSharedAudioFileRecord(
        id: id,
        title: "Before",
        createdAt: Date(),
        duration: 1,
        audioURL: "/tmp/test.m4a"
      )
    ])
    let adapter = MemoraSharedStoreBridgeAdapter(store: store)

    let renamedValue = try adapter.renameAudioFile(id: id.uuidString, title: "After")
    let renamed = try #require(renamedValue)
    #expect(renamed.title == "After")
    #expect(try store.fetch(id: id)?.title == "After")

    let movedValue = try adapter.moveAudioFile(id: id.uuidString, projectId: projectId.uuidString)
    let moved = try #require(movedValue)
    #expect(moved.project == projectId.uuidString)
    #expect(try store.fetch(id: id)?.projectID == projectId)

    let movedToInboxValue = try adapter.moveAudioFile(id: id.uuidString, projectId: nil)
    let movedToInbox = try #require(movedToInboxValue)
    #expect(movedToInbox.project == "Inbox")
    #expect(try store.fetch(id: id)?.projectID == nil)

    #expect(try adapter.deleteAudioFile(id: id.uuidString))
    #expect(try store.fetch(id: id) == nil)
  }

  @Test("invalid IDs and empty titles fail explicitly")
  func rejectsInvalidMutations() throws {
    let adapter = MemoraSharedStoreBridgeAdapter(store: MemoraInMemoryAudioFileStore())
    let dto = MemoraAudioFileDTO(
      id: "not-a-uuid",
      title: "Invalid",
      project: "Inbox",
      source: "iPhone",
      recordedAt: "2026-07-10T00:00:00Z",
      duration: "00:01",
      status: "ready",
      summary: "",
      transcript: [],
      memo: []
    )

    #expect(throws: MemoraSharedStoreBridgeError.self) {
      try adapter.upsertAudioFile(dto, fileURL: URL(fileURLWithPath: "/tmp/test.m4a"))
    }
    #expect(throws: MemoraSharedStoreBridgeError.self) {
      try adapter.renameAudioFile(id: UUID().uuidString, title: "   ")
    }
    #expect(throws: MemoraSharedStoreBridgeError.self) {
      try adapter.moveAudioFile(id: UUID().uuidString, projectId: "not-a-project-uuid")
    }
  }

  @Test("R09: 削除は所有する音声実体（audioURL と分割セグメント）を消し、ストアからも消える")
  func deleteAudioFileRemovesOwnedAudioPayloads() throws {
    let id = UUID()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-delete-owned-\(UUID().uuidString)", isDirectory: true)
    let audioURL = root.appendingPathComponent("Recordings").appendingPathComponent("session.m4a")
    let segmentURLs = [
      root.appendingPathComponent("Segments").appendingPathComponent("segment-1.wav"),
      root.appendingPathComponent("Segments").appendingPathComponent("segment-2.wav")
    ]
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("audio-payload".utf8).write(to: audioURL)
    try FileManager.default.createDirectory(at: segmentURLs[0].deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("segment-1".utf8).write(to: segmentURLs[0])
    try Data("segment-2".utf8).write(to: segmentURLs[1])

    let store = MemoraInMemoryAudioFileStore(records: [
      MemoraSharedAudioFileRecord(
        id: id,
        title: "Delete owned payloads",
        createdAt: Date(),
        duration: 3,
        audioURL: audioURL.path,
        segmentPaths: segmentURLs.map(\.path)
      )
    ])
    let adapter = MemoraSharedStoreBridgeAdapter(store: store, ownedAudioDirectories: [root])

    #expect(try adapter.deleteAudioFile(id: id.uuidString))
    #expect(try store.fetch(id: id) == nil)
    #expect(FileManager.default.fileExists(atPath: audioURL.path) == false)
    #expect(segmentURLs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
  }

  @Test("R09: 所有範囲外の音声パス（importAudio の原本等）は削除しない")
  func deleteAudioFileKeepsPayloadsOutsideOwnedRoots() throws {
    let id = UUID()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-delete-owned-\(UUID().uuidString)", isDirectory: true)
    let externalRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-delete-external-\(UUID().uuidString)", isDirectory: true)
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: externalRoot)
    }

    let ownedAudioURL = root.appendingPathComponent("owned.m4a")
    let externalAudioURL = externalRoot.appendingPathComponent("original-import.m4a")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: externalRoot, withIntermediateDirectories: true)
    try Data("owned".utf8).write(to: ownedAudioURL)
    try Data("external-original".utf8).write(to: externalAudioURL)

    let store = MemoraInMemoryAudioFileStore(records: [
      MemoraSharedAudioFileRecord(
        id: id,
        title: "Delete record but keep import original",
        createdAt: Date(),
        duration: 1,
        audioURL: externalAudioURL.path,
        segmentPaths: [ownedAudioURL.path]
      )
    ])
    let adapter = MemoraSharedStoreBridgeAdapter(store: store, ownedAudioDirectories: [root])

    #expect(try adapter.deleteAudioFile(id: id.uuidString))
    #expect(try store.fetch(id: id) == nil)
    // 所有ルート配下の実体のみ削除され、所有外（原本）は残る。
    #expect(FileManager.default.fileExists(atPath: ownedAudioURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: externalAudioURL.path))
  }

  @Test("R09: 実体削除に失敗したらエラーを返し、レコードは残って再試行できる")
  func deleteAudioFileFailureKeepsRecordForRetry() throws {
    let id = UUID()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-delete-failure-\(UUID().uuidString)", isDirectory: true)
    let audioURL = root.appendingPathComponent("locked.m4a")
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
      try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("locked-payload".utf8).write(to: audioURL)
    // 親ディレクトリから書き込み権限を外し、removeItem を確実に失敗させる。
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)

    let store = MemoraInMemoryAudioFileStore(records: [
      MemoraSharedAudioFileRecord(
        id: id,
        title: "Delete failure",
        createdAt: Date(),
        duration: 1,
        audioURL: audioURL.path
      )
    ])
    let adapter = MemoraSharedStoreBridgeAdapter(store: store, ownedAudioDirectories: [root])

    #expect(throws: (any Error).self) {
      try adapter.deleteAudioFile(id: id.uuidString)
    }
    // 実体削除失敗時はレコード削除まで進まない（再試行可能な状態を保つ）。
    #expect(try store.fetch(id: id) != nil)
    #expect(FileManager.default.fileExists(atPath: audioURL.path))
  }

  @Test("processing retries deduplicate, persist attempts, and complete")
  func persistsProcessingRetries() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-retry-tests-\(UUID().uuidString)", isDirectory: true)
    let storageURL = root.appendingPathComponent("processing-retries.json")
    defer { try? FileManager.default.removeItem(at: root) }

    let queue = MemoraFileProcessingRetryQueue(storageURL: storageURL)
    let first = try queue.enqueue(
      audioFileId: "audio-1",
      operation: "transcription",
      lastError: "Network unavailable"
    )
    let duplicate = try queue.enqueue(
      audioFileId: "audio-1",
      operation: "transcription",
      lastError: "Timed out"
    )

    #expect(duplicate.id == first.id)
    #expect(try queue.list().count == 1)
    #expect(duplicate.lastError == "Timed out")

    let attemptedValue = try queue.recordFailedAttempt(id: first.id, lastError: "Still offline")
    let attempted = try #require(attemptedValue)
    #expect(attempted.attemptCount == 1)
    #expect(attempted.lastError == "Still offline")

    let restoredQueue = MemoraFileProcessingRetryQueue(storageURL: storageURL)
    let restored = try #require(try restoredQueue.list().first)
    #expect(restored.id == first.id)
    #expect(restored.attemptCount == 1)

    #expect(try restoredQueue.complete(id: first.id))
    #expect(try restoredQueue.list().isEmpty)
    #expect(try restoredQueue.complete(id: first.id) == false)

    #expect(throws: MemoraProcessingRetryError.self) {
      try queue.enqueue(audioFileId: "audio-1", operation: "export", lastError: nil)
    }
  }

  @Test("transcript DTO preserves raw segments and fills missing cleaned text")
  func transcriptDTOUsesRawIndexesAndCleaningFallback() throws {
    let container = try ModelContainer(for: Schema(versionedSchema: MemoraSchemaV6.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    let file = AudioFile(title: "Fixture", audioURL: "/tmp/a.m4a")
    let transcript = Transcript(audioFileID: file.id, text: "raw")
    transcript.audioFile = file
    transcript.segmentTexts = ["えー、最初です", "あの、次です", "はい、最後です"]
    transcript.cleanedSegmentTexts = ["保存済み"]
    transcript.speakerLabels = ["A"]
    transcript.segmentStartTimes = [1]
    context.insert(file); context.insert(transcript); try context.save()
    let record = MemoraSharedAudioFileRecord(id: file.id, title: file.title, createdAt: file.createdAt, duration: 0, audioURL: file.audioURL)
    let dto = try #require(try MemoraSharedStoreBridgeAdapter(store: MemoraInMemoryAudioFileStore(records: [record]), container: container).getAudioFile(id: file.id.uuidString))
    #expect(dto.transcript.count == 3)
    #expect(dto.transcript[0]["text"] as? String == "えー、最初です")
    #expect(dto.transcript[0]["cleanedText"] as? String == "保存済み")
    #expect(dto.transcript[1]["cleanedText"] as? String == "次です")
    #expect(dto.transcript[2]["speaker"] as? String == "")
  }

  @Test("custom vocabulary CRUD persists in the shared SwiftData container")
  func customVocabularyCRUD() throws {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let manager = MemoraSharedStoreCustomVocabularyManager(container: container)
    let created = try manager.save(MemoraCustomVocabularyDTO(dictionary: [
      "id": UUID().uuidString,
      "pattern": "メモラ",
      "replacement": "Memora",
      "enabled": true,
      "createdAt": "2026-07-20T00:00:00Z"
    ]))
    #expect(try manager.list().count == 1)

    let updated = try manager.save(MemoraCustomVocabularyDTO(dictionary: [
      "id": created.id,
      "pattern": "メモラ",
      "replacement": "Memora AI",
      "enabled": false,
      "createdAt": created.createdAt
    ]))
    #expect(updated.replacement == "Memora AI")
    #expect(updated.enabled == false)
    #expect(try manager.delete(id: created.id))
    #expect(try manager.list().isEmpty)
  }

  @Test("custom vocabulary only applies enabled rules without chaining replacements")
  func customVocabularyAppliesEnabledRulesWithoutChaining() {
    let enabledFirst = CustomVocabulary(pattern: "A", replacement: "B", enabled: true, createdAt: .distantPast)
    let enabledSecond = CustomVocabulary(pattern: "B", replacement: "C", enabled: true, createdAt: .distantFuture)
    let disabled = CustomVocabulary(pattern: "未使用", replacement: "変更", enabled: false)
    let applier = MemoraCustomVocabularyApplier(vocabulary: [enabledFirst, enabledSecond, disabled])

    #expect(applier.apply(to: "AB 未使用") == "BC 未使用")
  }

  @Test("empty custom vocabulary leaves cleaned text unchanged")
  func emptyCustomVocabularyLeavesTextUnchanged() {
    #expect(MemoraCustomVocabularyApplier(vocabulary: []).apply(to: "既存の整形結果") == "既存の整形結果")
  }

  @Test("STT 保存で辞書適用済みの cleanedText を DTO 読込時に再適用しない")
  func transcriptDTODoesNotReapplyVocabularyAfterPersist() throws {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let file = AudioFile(title: "Vocabulary fixture", audioURL: "/tmp/vocabulary.m4a")
    let transcript = Transcript(audioFileID: file.id, text: "CRMを導入しました")
    transcript.audioFile = file
    let rawSegments = ["CRMを導入しました", "CRMの商談です"]
    transcript.segmentTexts = rawSegments
    context.insert(file)
    context.insert(transcript)
    context.insert(CustomVocabulary(pattern: "CRM", replacement: "CRMシステム", enabled: true))
    context.insert(CustomVocabulary(pattern: "商談", replacement: "商談済み", enabled: false))
    try context.save()

    // 保存時（MemoraRNTranscriptionBridge.persist）の適用順を再現する:
    // clean 後に辞書を1回だけ適用し、適用済み文字列を cleanedSegmentTexts へ保存する。
    let postProcessor = TranscriptPostProcessor()
    let vocabularyApplier = MemoraCustomVocabularyApplier(
      vocabulary: try context.fetch(FetchDescriptor<CustomVocabulary>())
    )
    transcript.cleanedSegmentTexts = rawSegments.map {
      vocabularyApplier.apply(to: postProcessor.clean($0))
    }
    try context.save()

    let record = MemoraSharedAudioFileRecord(id: file.id, title: file.title, createdAt: file.createdAt, duration: 0, audioURL: file.audioURL)
    let dto = try #require(try MemoraSharedStoreBridgeAdapter(store: MemoraInMemoryAudioFileStore(records: [record]), container: container).getAudioFile(id: file.id.uuidString))
    // text は補正前のまま
    #expect(dto.transcript[0]["text"] as? String == "CRMを導入しました")
    #expect(dto.transcript[1]["text"] as? String == "CRMの商談です")
    // cleanedText は保存時の適用結果（1回のみ）。二重適用なら「CRMシステムシステム」になる。
    #expect(dto.transcript[0]["cleanedText"] as? String == "CRMシステムを導入しました")
    #expect(dto.transcript[1]["cleanedText"] as? String == "CRMシステムの商談です")
    #expect((dto.transcript[0]["cleanedText"] as? String)?.contains("システムシステム") == false)
  }

  @Test("cleanedSegmentTexts 欠落時も DTO は辞書を再適用せず補正のみ行う")
  func transcriptDTOFallbackNeverReappliesVocabulary() throws {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let file = AudioFile(title: "Vocabulary fallback fixture", audioURL: "/tmp/vocabulary-fallback.m4a")
    let transcript = Transcript(audioFileID: file.id, text: "CRMです")
    transcript.audioFile = file
    transcript.segmentTexts = ["CRMです", "えー、CRMの計画です"]
    // 保存時に辞書適用済みの1件のみ保持（後続セグメントは保存時の欠落を模す）
    transcript.cleanedSegmentTexts = ["CRMシステムです"]
    context.insert(file)
    context.insert(transcript)
    context.insert(CustomVocabulary(pattern: "CRM", replacement: "CRMシステム", enabled: true))
    try context.save()

    let record = MemoraSharedAudioFileRecord(id: file.id, title: file.title, createdAt: file.createdAt, duration: 0, audioURL: file.audioURL)
    let dto = try #require(try MemoraSharedStoreBridgeAdapter(store: MemoraInMemoryAudioFileStore(records: [record]), container: container).getAudioFile(id: file.id.uuidString))
    // 保存済みの適用結果は素通し（再適用すると「CRMシステムシステムです」になる）
    #expect(dto.transcript[0]["cleanedText"] as? String == "CRMシステムです")
    // 欠落セグメントはフィラー除去などの補正のみ（辞書は適用しない）
    #expect(dto.transcript[1]["cleanedText"] as? String == "CRMの計画です")
    #expect(dto.transcript[1]["text"] as? String == "えー、CRMの計画です")
  }

  @Test("録音が51件以上でも一覧は全件を新しい順で返す（50件上限の撤廃）")
  func listsAllRecordingsBeyondLegacyFiftyRecordCap() throws {
    let totalCount = 53
    let baseDate = Date(timeIntervalSince1970: 1_000_000)
    let records = (0..<totalCount).map { index in
      MemoraSharedAudioFileRecord(
        id: UUID(),
        title: "Recording \(index)",
        createdAt: baseDate.addingTimeInterval(TimeInterval(index)),
        duration: 1,
        audioURL: "/tmp/recording-\(index).m4a"
      )
    }
    // 生成順 = createdAt 昇順のため、先頭が最古、末尾が最新。
    let oldest = try #require(records.first)
    let newest = try #require(records.last)
    let adapter = MemoraSharedStoreBridgeAdapter(
      store: MemoraInMemoryAudioFileStore(records: records)
    )

    let dtos = try adapter.listAudioFiles()

    // 旧実装は limit: 50 のため 51件目以降（最古の録音）が一覧結果に含まれなかった。
    #expect(dtos.count == totalCount)
    #expect(dtos.contains { $0.id == oldest.id.uuidString })
    // ページングの重複・欠落がないことと、既存の並び順（新しい順）の維持。
    #expect(Set(dtos.map(\.id)).count == totalCount)
    #expect(dtos.first?.id == newest.id.uuidString)
  }
}

@Suite("RN shared store task bridge adapter")
struct MemoraSharedStoreTaskBridgeAdapterTests {
  private func makeAdapter() throws -> MemoraSharedStoreTaskBridgeAdapter {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return MemoraSharedStoreTaskBridgeAdapter(container: container)
  }

  private func makeDTO(
    id: String = UUID().uuidString,
    title: String = "会議メモを整理する",
    dueDate: String? = nil,
    sourceAudioFileID: String? = nil
  ) -> MemoraTaskDTO {
    MemoraTaskDTO(
      id: id,
      title: title,
      priority: "medium",
      dueDate: dueDate,
      sourceAudioFileID: sourceAudioFileID,
      isCompleted: false,
      createdAt: "2026-08-09T00:00:00Z"
    )
  }

  @Test("create, list, toggle, update, and delete persist through the repository")
  func taskAdapterCRUD() throws {
    let adapter = try makeAdapter()
    let created = try adapter.createTask(makeDTO())
    #expect(created.id != "")
    #expect(try adapter.listTasks().map(\.id) == [created.id])

    let toggled = try #require(try adapter.toggleTask(id: created.id, completed: true))
    #expect(toggled.isCompleted)
    #expect(toggled.completedAt != nil)

    let updatedValue = try adapter.updateTask(MemoraTaskDTO(dictionary: [
      "id": created.id,
      "title": "更新済みタイトル",
      "priority": "high",
      "isCompleted": true,
      "createdAt": toggled.createdAt
    ]))
    let updated = try #require(updatedValue)
    #expect(updated.title == "更新済みタイトル")
    #expect(updated.priority == "high")

    #expect(try adapter.deleteTask(id: created.id))
    #expect(try adapter.listTasks().isEmpty)
  }

  @Test("due dates and source links survive the DTO round trip")
  func taskAdapterRoundTripsDatesAndSource() throws {
    let adapter = try makeAdapter()
    _ = try adapter.createTask(makeDTO(
      title: "期限付きタスク",
      dueDate: "2026-08-10T05:00:00.000Z",
      sourceAudioFileID: UUID().uuidString
    ))

    let listed = try #require(try adapter.listTasks().first)
    #expect(listed.dueDate?.hasPrefix("2026-08-10") == true)
    #expect(listed.sourceAudioFileID != nil)
    #expect(listed.isCompleted == false)
  }

  @Test("unknown IDs fail safely")
  func taskAdapterRejectsUnknownIDs() throws {
    let adapter = try makeAdapter()
    #expect(try adapter.updateTask(makeDTO(id: UUID().uuidString)) == nil)
    #expect(try adapter.toggleTask(id: UUID().uuidString, completed: true) == nil)
    #expect(try adapter.deleteTask(id: UUID().uuidString) == false)
  }
}

@Suite("RN shared store project bridge adapter")
struct MemoraSharedStoreProjectBridgeAdapterTests {
  private func makeAdapter() throws -> MemoraSharedStoreProjectBridgeAdapter {
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV6.self),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return MemoraSharedStoreProjectBridgeAdapter(container: container)
  }

  @Test("lists projects in title ascending order")
  func projectAdapterListsSortedByTitle() throws {
    let adapter = try makeAdapter()
    let context = ModelContext(adapter.container)
    context.insert(Project(title: "B プロジェクト"))
    context.insert(Project(title: "C プロジェクト"))
    context.insert(Project(title: "A プロジェクト"))
    try context.save()

    let projects = try adapter.listProjects()
    #expect(projects.map(\.title) == ["A プロジェクト", "B プロジェクト", "C プロジェクト"])
    #expect(projects.map(\.id).allSatisfy { UUID(uuidString: $0) != nil })
  }

  @Test("returns an empty array when no projects exist")
  func projectAdapterReturnsEmptyWhenNoProjects() throws {
    let adapter = try makeAdapter()
    #expect(try adapter.listProjects().isEmpty)
  }
}

@Suite("RN native-files memo/photos deletion (R09)")
struct MemoraNativeMemoDataDeletionTests {
  /// R09: MemoraNativeModule.deleteAudioFile がレコード削除前に
  /// MemoraMemoHandling.deleteMemoData を呼ぶ設計の実体削除側の検証。
  /// モジュール層（AsyncFunction）自体はこのテストターゲットから直接呼べないため、
  /// MemoraNativeFileMemoStore の実体削除（メモ JSON レコード・写真ディレクトリ）を
  /// 対象ファイルのみ削除し他レコードを保持することを確認する。
  @Test("メモと写真は対象ファイルのみ削除し、他レコードは保持する")
  func deletesOnlyTargetMemoAndPhotos() throws {
    let memoStore = MemoraNativeFileMemoStore()
    let targetID = UUID().uuidString
    let otherID = UUID().uuidString
    let documents = try #require(
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    )
    let memoFileURL = documents
      .appendingPathComponent("MemoraNativeMetadata", isDirectory: true)
      .appendingPathComponent("memo-notes.json")
    let photosRootURL = documents.appendingPathComponent("MemoraNativeMemoPhotos", isDirectory: true)
    let targetPhotosURL = photosRootURL.appendingPathComponent(targetID, isDirectory: true)

    // テストが書き込んだファイルだけを確実に後始末する（既存データは保持）。
    let memoFileExistedBefore = FileManager.default.fileExists(atPath: memoFileURL.path)
    let photosRootExistedBefore = FileManager.default.fileExists(atPath: photosRootURL.path)
    defer {
      try? memoStore.deleteMemoData(audioFileId: targetID)
      try? memoStore.deleteMemoData(audioFileId: otherID)
      if !memoFileExistedBefore, FileManager.default.fileExists(atPath: memoFileURL.path),
         let data = try? Data(contentsOf: memoFileURL),
         String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" {
        try? FileManager.default.removeItem(at: memoFileURL)
      }
      if !photosRootExistedBefore, FileManager.default.fileExists(atPath: photosRootURL.path),
         let contents = try? FileManager.default.contentsOfDirectory(atPath: photosRootURL.path),
         contents.isEmpty {
        try? FileManager.default.removeItem(at: photosRootURL)
      }
    }

    // 写真のコピー元（テスト専用の一時ファイル）。
    let sourceRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-memo-photo-source-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: sourceRoot) }
    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let sourceURL = sourceRoot.appendingPathComponent("photo.jpg")
    try Data("fake-jpeg-payload".utf8).write(to: sourceURL)

    try memoStore.saveMemoDraft(audioFileId: otherID, text: "他ファイルのメモ")
    try memoStore.saveMemoDraft(audioFileId: targetID, text: "削除対象メモ")
    _ = try memoStore.addPhotoAttachment(audioFileId: targetID, sourceUri: sourceURL.absoluteString)
    #expect(try memoStore.listPhotoAttachments(audioFileId: targetID).count == 1)
    #expect(FileManager.default.fileExists(atPath: targetPhotosURL.path))

    // 対象の削除: メモ本文・写真の一覧・写真ディレクトリ実体が消える。
    try memoStore.deleteMemoData(audioFileId: targetID)
    #expect(try memoStore.getMemoDraft(audioFileId: targetID).isEmpty)
    #expect(try memoStore.listPhotoAttachments(audioFileId: targetID).isEmpty)
    #expect(FileManager.default.fileExists(atPath: targetPhotosURL.path) == false)

    // 他レコードは保持される。
    #expect(try memoStore.getMemoDraft(audioFileId: otherID) == "他ファイルのメモ")

    // べき等: 2回目・未知 ID の削除は副作用なく成功する。
    try memoStore.deleteMemoData(audioFileId: targetID)
    try memoStore.deleteMemoData(audioFileId: UUID().uuidString)
  }
}
