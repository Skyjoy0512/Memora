import Foundation
import SwiftData
import Testing
@testable import MemoraSharedSchema

/// 実際のアプリが書き出した旧バージョンのストアファイルが、
/// 現行スキーマで開けることを保証する。
///
/// テスト内で旧バージョンのコンテナを生成する方式では、同名の `@Model` クラスが
/// 同一プロセスに複数存在してエンティティ解決が混線するため、
/// 実ファイルを fixture として持ち込む形にしている。
/// またこの方式なら、スキーマのバージョンが上がっても移行の連鎖全体を検証し続けられる。
@Suite("Legacy store migration")
struct LegacyStoreMigrationTests {
    @Test("実アプリが作成した V3 期のストアを現行スキーマで開ける")
    func opensLegacyV3Store() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let storeURL = workspace.appendingPathComponent("Memora.store")
        try FileManager.default.copyItem(at: legacyStoreFixtureURL(), to: storeURL)

        let container = try MemoraSharedStoreFactory.makePersistentContainer(at: storeURL)
        let context = ModelContext(container)

        // 移行が成立し、各エンティティを読み出せること。
        // fixture は空ストアなので件数は 0 が正しい。
        #expect(try context.fetch(FetchDescriptor<AudioFile>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty)

        // 移行後のストアに新規レコードを書き込めること。
        let audioFile = AudioFile(title: "post-migration", audioURL: "/tmp/post-migration.m4a")
        context.insert(audioFile)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<AudioFile>()).count == 1)
    }
}

private func legacyStoreFixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("legacy_v3_store.sqlite")
}
