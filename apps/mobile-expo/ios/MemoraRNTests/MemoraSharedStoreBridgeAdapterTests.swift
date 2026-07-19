import AVFoundation
import Foundation
import Testing
@testable import MemoraRN
import MemoraSharedData
internal import MemoraNative

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

  private func writeSilentAudio(to url: URL) throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: 8_000,
      channels: 1,
      interleaved: true
    )!
    let audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 800)!
    buffer.frameLength = 800
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
}
