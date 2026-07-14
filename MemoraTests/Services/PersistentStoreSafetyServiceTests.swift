import Foundation
import Testing
@testable import Memora

struct PersistentStoreSafetyServiceTests {
    @Test
    func 自動削除なしではストアとサイドカーを保持する() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Memora.store")
        let service = PersistentStoreSafetyService(backupRootURL: directory.appendingPathComponent("backups"))
        for file in service.storeFiles(for: storeURL) {
            try Data("keep".utf8).write(to: file)
        }

        // 起動失敗経路はこのサービスを呼ばない。読み取りだけで全ファイルが残ることを保証する。
        #expect(service.storeFiles(for: storeURL).allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test
    func 明示的リセットはバックアップ後にストアとサイドカーを削除する() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Memora.store")
        let service = PersistentStoreSafetyService(backupRootURL: directory.appendingPathComponent("backups"))
        for file in service.storeFiles(for: storeURL) {
            try Data(file.lastPathComponent.utf8).write(to: file)
        }

        let backup = try service.backupThenRemoveStore(at: storeURL)
        let backupURL = try #require(backup)
        #expect(service.storeFiles(for: storeURL).allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(service.storeFiles(for: storeURL).allSatisfy {
            FileManager.default.fileExists(atPath: backupURL.appendingPathComponent($0.lastPathComponent).path)
        })
    }

    @Test
    func バックアップ失敗時は元ストアを削除しない() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Memora.store")
        try Data("keep".utf8).write(to: storeURL)
        let blockedBackupRoot = directory.appendingPathComponent("blocked")
        try Data().write(to: blockedBackupRoot)
        let service = PersistentStoreSafetyService(backupRootURL: blockedBackupRoot)

        #expect(throws: PersistentStoreSafetyService.ResetError.self) {
            try service.backupThenRemoveStore(at: storeURL)
        }
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
    }

    @Test
    func タイムアウトは完了しない操作を待たずに戻る() async {
        let clock = ContinuousClock()
        let start = clock.now
        let result: Int? = await ModelContainerLoadTimeout.race(
            operation: {
                try? await Task.sleep(for: .seconds(2))
                return 1
            },
            timeoutNanoseconds: 30_000_000
        )
        let elapsed = start.duration(to: clock.now)
        #expect(result == nil)
        #expect(elapsed < .seconds(1))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistentStoreSafetyServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
