import Foundation
import Testing
@testable import MemoraSharedData

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
      isSummarized: true,
      summary: "A concise summary"
    )

    let encoded = try JSONEncoder().encode(record)
    let decoded = try JSONDecoder().decode(MemoraSharedAudioFileRecord.self, from: encoded)

    #expect(decoded == record)
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
