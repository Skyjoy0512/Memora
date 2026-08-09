import Foundation

/// The result of resolving the single SwiftData store both hosts must open.
public struct MemoraSharedStoreResolution: Equatable, Sendable {
  /// The store URL the caller should open.
  public let storeURL: URL
  /// Whether the resolved store lives in the app group shared container.
  public let usesSharedStore: Bool
  /// Whether this call performed a legacy → shared store migration.
  public let didMigrate: Bool

  public init(storeURL: URL, usesSharedStore: Bool, didMigrate: Bool) {
    self.storeURL = storeURL
    self.usesSharedStore = usesSharedStore
    self.didMigrate = didMigrate
  }
}

/// Single entry point for resolving the shared SwiftData store (ADR-004 decision 3).
///
/// Ownership follows the shared store contract:
/// - A shared store that already exists wins and is never re-migrated (idempotent).
/// - Otherwise a legacy sandbox store is migrated into the app group atomically,
///   exactly once, and the legacy store is retained for rollback.
/// - Otherwise the shared store URL is returned so SwiftData creates an empty
///   store on first launch.
public enum MemoraSharedStoreResolver {
  private static let lock = NSLock()

  /// Resolves the store URL to open, migrating a legacy store into the app group
  /// shared container exactly once when needed.
  ///
  /// - Parameters:
  ///   - legacyStoreURL: The sandbox store inside the app's `Application Support`
  ///     directory (e.g. `MemoraSharedStoreLocation.storeURL(in: appSupport)`).
  ///   - appGroupContainerURL: The App Group container. `nil` when the group is
  ///     unavailable, in which case the legacy store is used.
  ///   - fileManager: File manager to use. Injected for tests.
  @discardableResult
  public static func resolveSharedStoreURL(
    legacyStoreURL: URL,
    appGroupContainerURL: URL?,
    fileManager: FileManager = .default
  ) throws -> MemoraSharedStoreResolution {
    lock.lock()
    defer { lock.unlock() }

    guard let appGroupContainerURL else {
      try prepareStoreDirectory(for: legacyStoreURL, fileManager: fileManager)
      return MemoraSharedStoreResolution(storeURL: legacyStoreURL, usesSharedStore: false, didMigrate: false)
    }

    let sharedStoreURL = MemoraSharedStoreLocation.storeURL(in: appGroupContainerURL)
    let sharedDirectory = sharedStoreURL.deletingLastPathComponent()
    let hasSharedStore = fileManager.fileExists(atPath: sharedStoreURL.path)
    let hasLegacyStore = fileManager.fileExists(atPath: legacyStoreURL.path)

    if hasSharedStore {
      return MemoraSharedStoreResolution(storeURL: sharedStoreURL, usesSharedStore: true, didMigrate: false)
    }

    if hasLegacyStore && !fileManager.fileExists(atPath: sharedDirectory.path) {
      do {
        try MemoraStoreMigration.migrateStoreAtomically(
          from: legacyStoreURL,
          to: sharedStoreURL,
          fileManager: fileManager
        )
        return MemoraSharedStoreResolution(storeURL: sharedStoreURL, usesSharedStore: true, didMigrate: true)
      } catch {
        // Migration failed: keep using the known-good legacy store. The source is
        // never removed by migration.
        try prepareStoreDirectory(for: legacyStoreURL, fileManager: fileManager)
        return MemoraSharedStoreResolution(storeURL: legacyStoreURL, usesSharedStore: false, didMigrate: false)
      }
    }

    if !hasLegacyStore && !fileManager.fileExists(atPath: sharedDirectory.path) {
      // First launch: SwiftData creates the empty store at this URL.
      try prepareStoreDirectory(for: sharedStoreURL, fileManager: fileManager)
      return MemoraSharedStoreResolution(storeURL: sharedStoreURL, usesSharedStore: true, didMigrate: false)
    }

    // A partial or manually created destination directory must never replace a
    // valid store. Fall back to the legacy store.
    try prepareStoreDirectory(for: legacyStoreURL, fileManager: fileManager)
    return MemoraSharedStoreResolution(storeURL: legacyStoreURL, usesSharedStore: false, didMigrate: false)
  }

  /// Ensures the directory containing `storeURL` exists.
  @discardableResult
  public static func prepareStoreDirectory(
    for storeURL: URL,
    fileManager: FileManager
  ) throws -> URL {
    let directoryURL = storeURL.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: directoryURL.path) {
      try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
    return storeURL
  }
}
