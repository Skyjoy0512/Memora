import Foundation
import SwiftData
import Testing
@testable import MemoraSharedData
@testable import MemoraSharedSchema
@testable import MemoraSharedCore

@Suite("MemoraSharedData contract")
struct MemoraSharedDataTests {
  @Test("store migration copies the store and SQLite sidecars")
  func storeMigrationCopiesSidecars() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-store-test-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("old/Memora.store")
    let destination = root.appendingPathComponent("new/Memora.store")
    try FileManager.default.createDirectory(
      at: source.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("store".utf8).write(to: source)
    try Data("shared".utf8).write(to: URL(fileURLWithPath: source.path + "-shm"))
    try Data("wal".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))
    defer { try? FileManager.default.removeItem(at: root) }

    let copied = try MemoraStoreMigration.copyStore(from: source, to: destination)

    #expect(copied.count == 3)
    #expect(try Data(contentsOf: destination) == Data("store".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: destination.path + "-shm")) == Data("shared".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: destination.path + "-wal")) == Data("wal".utf8))
  }

  @Test("store migration rejects a destination sidecar before copying")
  func storeMigrationRejectsExistingSidecar() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-store-conflict-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("old/Memora.store")
    let destination = root.appendingPathComponent("new/Memora.store")
    try FileManager.default.createDirectory(
      at: source.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("store".utf8).write(to: source)
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let destinationSidecar = URL(fileURLWithPath: destination.path + "-wal")
    try Data("existing".utf8).write(to: destinationSidecar)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: MemoraStoreMigration.Error.destinationAlreadyExists(destinationSidecar)) {
      try MemoraStoreMigration.copyStore(from: source, to: destination)
    }
    #expect(!FileManager.default.fileExists(atPath: destination.path))
  }

  @Test("store migration rejects a missing source store")
  func storeMigrationRejectsMissingSource() {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-store-missing-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("old/Memora.store")
    let destination = root.appendingPathComponent("new/Memora.store")
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: MemoraStoreMigration.Error.sourceStoreMissing(source)) {
      try MemoraStoreMigration.copyStore(from: source, to: destination)
    }
  }

  @Test("atomic migration retains the legacy store and installs all sidecars together")
  func atomicMigrationRetainsLegacyStore() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-store-atomic-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("legacy/Memora.store")
    let destination = root.appendingPathComponent("group/Memora/Memora.store")
    try FileManager.default.createDirectory(
      at: source.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("store".utf8).write(to: source)
    try Data("shared".utf8).write(to: URL(fileURLWithPath: source.path + "-shm"))
    try Data("wal".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))
    defer { try? FileManager.default.removeItem(at: root) }

    let migrated = try MemoraStoreMigration.migrateStoreAtomically(
      from: source,
      to: destination,
      stagingDirectoryName: ".migration-test"
    )

    #expect(migrated.count == 3)
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(try Data(contentsOf: destination) == Data("store".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: destination.path + "-shm")) == Data("shared".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: destination.path + "-wal")) == Data("wal".utf8))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("group/.migration-test").path))
  }

  @Test("atomic migration does not overwrite an existing destination directory")
  func atomicMigrationRejectsExistingDestinationDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-store-atomic-conflict-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("legacy/Memora.store")
    let destination = root.appendingPathComponent("group/Memora/Memora.store")
    try FileManager.default.createDirectory(
      at: source.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("store".utf8).write(to: source)
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: MemoraStoreMigration.Error.destinationDirectoryAlreadyExists(destination.deletingLastPathComponent())) {
      try MemoraStoreMigration.migrateStoreAtomically(from: source, to: destination)
    }
    #expect(FileManager.default.fileExists(atPath: source.path))
  }

  @Test("shared store URL is stable inside a container")
  func sharedStoreURL() {
    let containerURL = URL(fileURLWithPath: "/tmp/memora-shared-container")

    #expect(
      MemoraSharedStoreLocation.storeURL(in: containerURL).path
        == "/tmp/memora-shared-container/Memora/Memora.store"
    )
    #expect(
      MemoraSharedStoreLocation.audioFilesDirectory(in: containerURL).path
        == "/tmp/memora-shared-container/Memora/AudioFiles"
    )
  }

  @Test("audio record preserves bridge-safe fields")
  func audioRecordRoundTrip() throws {
    let id = UUID()
    let record = MemoraSharedAudioFileRecord(
      id: id,
      title: "Weekly Growth",
      createdAt: Date(timeIntervalSince1970: 1_000),
      duration: 42,
      audioURL: "/tmp/weekly-growth.m4a",
      segmentPaths: ["/tmp/weekly-growth.m4a", "/tmp/weekly-growth-2.m4a"],
      isSummarized: true,
      summary: "A concise summary"
    )

    let encoded = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(MemoraSharedAudioFileRecord.self, from: encoded)

    #expect(decoded == record)
    #expect(decoded.segmentPaths.count == 2)
  }

  @Test("V4 and V5 have distinct schema checksums")
  func v4AndV5SchemasAreDistinct() {
    let v4 = Schema(versionedSchema: MemoraSchemaV4.self)
    let v5 = Schema(versionedSchema: MemoraSchemaV5.self)

    #expect(v4 != v5)
  }

  @Test("V5 and V6 have distinct schema checksums and V6 starts with no custom vocabulary")
  func v5AndV6SchemasAreDistinct() throws {
    #expect(Schema(versionedSchema: MemoraSchemaV5.self) != Schema(versionedSchema: MemoraSchemaV6.self))
    let container = try ModelContainer(for: Schema(versionedSchema: MemoraSchemaV6.self), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    #expect(try ModelContext(container).fetch(FetchDescriptor<CustomVocabulary>()).isEmpty)
  }

  @Test("V3 and V4 have distinct schema checksums")
  func v3AndV4SchemasAreDistinct() {
    let v3 = Schema(versionedSchema: MemoraSchemaV3.self)
    let v4 = Schema(versionedSchema: MemoraSchemaV4.self)

    #expect(v3 != v4)
  }

  @Test("V4 fixed snapshot store migrates through the shared store factory")
  func v4StoreMigratesThroughSharedStoreFactory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-v4-v5-\(UUID().uuidString)", isDirectory: true)
    let storeURL = root.appendingPathComponent("Memora.store")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyID = UUID()
    do {
      let container = try ModelContainer(
        for: Schema(versionedSchema: MemoraSchemaV4.self),
        configurations: ModelConfiguration(url: storeURL, allowsSave: true, cloudKitDatabase: .none)
      )
      let context = ModelContext(container)
      let legacy = MemoraSchemaV4.AudioFile(
        title: "V4 recording",
        audioURL: "/tmp/v4.m4a"
      )
      legacy.id = legacyID
      context.insert(legacy)
      let legacyTranscript = MemoraSchemaV4.Transcript(audioFileID: legacyID, text: "元の文字起こし")
      legacyTranscript.audioFile = legacy
      legacyTranscript.segmentTexts = ["元のセグメント"]
      context.insert(legacyTranscript)
      try context.save()
    }

    let migrated = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
    let files = try ModelContext(migrated).fetch(FetchDescriptor<AudioFile>())
    let file = try #require(files.first(where: { $0.id == legacyID }))
    #expect(file.title == "V4 recording")
    #expect(file.audioURL == "/tmp/v4.m4a")
    #expect(file.segmentPaths.isEmpty)
    let transcripts = try ModelContext(migrated).fetch(FetchDescriptor<Transcript>())
    let transcript = try #require(transcripts.first(where: { $0.audioFileID == legacyID }))
    #expect(transcript.text == "元の文字起こし")
    #expect(transcript.segmentTexts == ["元のセグメント"])
    #expect(transcript.cleanedText == nil)
    #expect(transcript.cleanedSegmentTexts.isEmpty)
  }

  @Test("in-memory store supports page, update, and delete")
  func inMemoryStoreCRUD() throws {
    let first = MemoraSharedAudioFileRecord(
      id: UUID(),
      title: "Older",
      createdAt: Date(timeIntervalSince1970: 1),
      duration: 1,
      audioURL: "older.m4a"
    )
    let second = MemoraSharedAudioFileRecord(
      id: UUID(),
      title: "Newer",
      createdAt: Date(timeIntervalSince1970: 2),
      duration: 2,
      audioURL: "newer.m4a"
    )
    let store = MemoraInMemoryAudioFileStore(records: [first, second])

    #expect(store.sourceDescription == "mock")
    #expect(try store.fetchPage(offset: 0, limit: 1).map(\.id) == [second.id])

    var updated = first
    updated.title = "Renamed"
    try store.save(updated)
    #expect(try store.fetch(id: first.id)?.title == "Renamed")

    try store.delete(id: first.id)
    #expect(try store.fetch(id: first.id) == nil)
  }
}

@Suite("MemoraSharedSchema repository")
struct MemoraSharedSchemaRepositoryTests {
  @Test("in-memory AudioFile repository supports CRUD")
  func audioFileRepositoryCRUD() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: Schema(versionedSchema: MemoraSchemaV5.self),
      configurations: configuration
    )
    let repository = AudioFileRepository(modelContext: ModelContext(container))
    let audioFile = AudioFile(title: "Repository fixture", audioURL: "fixture.m4a")

    try repository.save(audioFile)
    #expect(try repository.fetch(id: audioFile.id)?.title == "Repository fixture")

    audioFile.title = "Updated fixture"
    try repository.save(audioFile)
    #expect(try repository.search(query: "updated").map(\.id) == [audioFile.id])

    try repository.delete(id: audioFile.id)
    #expect(try repository.fetch(id: audioFile.id) == nil)
  }
}

@Suite("MemoraSharedCore audio chunking")
struct MemoraSharedCoreAudioChunkerTests {
  @Test("audio chunk plan keeps its streaming boundaries")
  func audioChunkPlanRetainsBoundaries() {
    let sourceURL = URL(fileURLWithPath: "/tmp/source.m4a")
    let plan = AudioChunkPlan(
      sourceURL: sourceURL,
      totalDuration: 180,
      slices: [
        .init(index: 0, startSec: 0, endSec: 90),
        .init(index: 1, startSec: 90, endSec: 180)
      ]
    )

    #expect(plan.sourceURL == sourceURL)
    #expect(plan.count == 2)
    #expect(!plan.isSingleChunk)
    #expect(plan.slices.map(\.index) == [0, 1])
  }

  @Test("cleanup deletes only temporary chunk files")
  func cleanupDeletesOnlyTemporaryFiles() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("memora-audio-chunker-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let temporaryURL = root.appendingPathComponent("temporary.m4a")
    let sourceURL = root.appendingPathComponent("source.m4a")
    try Data("temporary".utf8).write(to: temporaryURL)
    try Data("source".utf8).write(to: sourceURL)

    let chunker = AudioChunker()
    await chunker.cleanup(chunks: [
      .init(index: 0, startSec: 0, endSec: 1, url: temporaryURL, isTemporary: true),
      .init(index: 1, startSec: 1, endSec: 2, url: sourceURL, isTemporary: false)
    ])

    #expect(!FileManager.default.fileExists(atPath: temporaryURL.path))
    #expect(FileManager.default.fileExists(atPath: sourceURL.path))
  }
}
