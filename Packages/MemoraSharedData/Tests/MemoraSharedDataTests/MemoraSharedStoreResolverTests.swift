import Foundation
import Testing
@testable import MemoraSharedData

@Suite("MemoraSharedStoreResolver")
struct MemoraSharedStoreResolverTests {
  @Test("既存の共有ストアを優先し、legacy が残っていても再移行しない")
  func existingSharedStoreWins() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-shared-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)
    try makeLegacyStore(at: legacyURL)
    try makeSharedStore(at: sharedURL)

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )

    #expect(resolution.storeURL == sharedURL)
    #expect(resolution.usesSharedStore)
    #expect(!resolution.didMigrate)
    #expect(try Data(contentsOf: sharedURL) == Data("shared-store".utf8))
    #expect(FileManager.default.fileExists(atPath: legacyURL.path))
  }

  @Test("legacy のみのとき移行して共有ストアを作成し、legacy は保持する")
  func migratesLegacyWhenOnlyLegacyExists() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-migrate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)
    try makeLegacyStore(at: legacyURL)

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )

    #expect(resolution.storeURL == sharedURL)
    #expect(resolution.usesSharedStore)
    #expect(resolution.didMigrate)
    #expect(try Data(contentsOf: sharedURL) == Data("legacy-store".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: sharedURL.path + "-shm")) == Data("legacy-shm".utf8))
    #expect(try Data(contentsOf: URL(fileURLWithPath: sharedURL.path + "-wal")) == Data("legacy-wal".utf8))
    #expect(FileManager.default.fileExists(atPath: legacyURL.path))
    #expect(try Data(contentsOf: legacyURL) == Data("legacy-store".utf8))
  }

  @Test("どちらもないときは共有ストア URL を返し、空ストア生成は SwiftData に任せる")
  func freshInstallReturnsSharedStoreURL() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-fresh-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )

    #expect(resolution.storeURL == sharedURL)
    #expect(resolution.usesSharedStore)
    #expect(!resolution.didMigrate)
    #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    #expect(FileManager.default.fileExists(atPath: sharedURL.deletingLastPathComponent().path))
  }

  @Test("移行失敗時は既知の安全な legacy ストアにフォールバックする")
  func migrationFailureFallsBackToLegacy() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-fallback-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)
    try makeLegacyStore(at: legacyURL)
    let failingFileManager = VerificationFailingFileManager()

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer,
      fileManager: failingFileManager
    )

    #expect(resolution.storeURL == legacyURL)
    #expect(!resolution.usesSharedStore)
    #expect(!resolution.didMigrate)
    #expect(!FileManager.default.fileExists(atPath: sharedURL.path))
    #expect(try Data(contentsOf: legacyURL) == Data("legacy-store".utf8))
  }

  @Test("再入呼び出しでも二重移行しない（冪等）")
  func repeatedResolutionIsIdempotent() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-rerun-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)
    try makeLegacyStore(at: legacyURL)

    let first = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )
    let second = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )

    #expect(first.storeURL == sharedURL)
    #expect(first.didMigrate)
    #expect(second.storeURL == sharedURL)
    #expect(second.usesSharedStore)
    #expect(!second.didMigrate)
    #expect(try Data(contentsOf: sharedURL) == Data("legacy-store".utf8))
    #expect(try Data(contentsOf: legacyURL) == Data("legacy-store".utf8))
  }

  @Test("並行呼び出しでも移行は一度だけ")
  func concurrentResolutionMigratesOnce() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-concurrent-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainer)
    try makeLegacyStore(at: legacyURL)

    let results = ResolverResultCollector()
    DispatchQueue.concurrentPerform(iterations: 32) { _ in
      do {
        results.append(try MemoraSharedStoreResolver.resolveSharedStoreURL(
          legacyStoreURL: legacyURL,
          appGroupContainerURL: appGroupContainer
        ))
      } catch {
        results.append(error)
      }
    }

    #expect(results.count == 32)
    #expect(results.errorCount == 0)
    #expect(results.migratedCount == 1)
    #expect(results.allResolveToSharedStore(sharedStoreURL: sharedURL))
    #expect(try Data(contentsOf: sharedURL) == Data("legacy-store".utf8))
    #expect(FileManager.default.fileExists(atPath: legacyURL.path))
  }

  @Test("App Group が使えないときは legacy ストアにフォールバックする")
  func unavailableAppGroupFallsBackToLegacy() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-no-group-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    try makeLegacyStore(at: legacyURL)

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: nil
    )

    #expect(resolution.storeURL == legacyURL)
    #expect(!resolution.usesSharedStore)
    #expect(!resolution.didMigrate)
    #expect(try Data(contentsOf: legacyURL) == Data("legacy-store".utf8))
  }

  @Test("共有ディレクトリだけ存在する部分状態では legacy をフォールバックする")
  func partialSharedDirectoryFallsBackToLegacy() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("resolver-partial-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyURL = root.appendingPathComponent("legacy/Memora.store")
    let appGroupContainer = root.appendingPathComponent("group")
    let sharedDirectory = appGroupContainer.appendingPathComponent("Memora", isDirectory: true)
    try makeLegacyStore(at: legacyURL)
    try FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)

    let resolution = try MemoraSharedStoreResolver.resolveSharedStoreURL(
      legacyStoreURL: legacyURL,
      appGroupContainerURL: appGroupContainer
    )

    #expect(resolution.storeURL == legacyURL)
    #expect(!resolution.usesSharedStore)
    #expect(!resolution.didMigrate)
    #expect(try Data(contentsOf: legacyURL) == Data("legacy-store".utf8))
  }

  private func makeLegacyStore(at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("legacy-store".utf8).write(to: url)
    try Data("legacy-shm".utf8).write(to: URL(fileURLWithPath: url.path + "-shm"))
    try Data("legacy-wal".utf8).write(to: URL(fileURLWithPath: url.path + "-wal"))
  }

  private func makeSharedStore(at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("shared-store".utf8).write(to: url)
  }
}

private final class ResolverResultCollector: @unchecked Sendable {
  private let lock = NSLock()
  private var resolutions: [MemoraSharedStoreResolution] = []
  private var errors: [Error] = []

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return resolutions.count + errors.count
  }

  var errorCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return errors.count
  }

  var migratedCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return resolutions.filter(\.didMigrate).count
  }

  func append(_ resolution: MemoraSharedStoreResolution) {
    lock.lock()
    defer { lock.unlock() }
    resolutions.append(resolution)
  }

  func append(_ error: Error) {
    lock.lock()
    defer { lock.unlock() }
    errors.append(error)
  }

  func allResolveToSharedStore(sharedStoreURL: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return !resolutions.isEmpty
      && resolutions.allSatisfy { $0.usesSharedStore && $0.storeURL == sharedStoreURL }
  }
}

private final class VerificationFailingFileManager: FileManager {
  override func contentsEqual(atPath path1: String, andPath path2: String) -> Bool {
    false
  }
}
