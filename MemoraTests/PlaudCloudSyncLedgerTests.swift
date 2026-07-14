import Foundation
import Testing
@testable import Memora

@Suite("PLAUDクラウド同期台帳")
struct PlaudCloudSyncLedgerTests {
    @Test("同期済み録音はリロード後も重複扱いになる")
    func persistsImportedRecordingIDs() throws {
        let url = temporaryLedgerURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let ledger = PlaudCloudSyncLedger(storageURL: url)
        ledger.recordSuccess(remoteID: "plaud-1", localAudioFileID: "local-1", createdAt: Date())
        ledger.markSuccessfulSync(at: Date())
        try ledger.save()

        let reloaded = PlaudCloudSyncLedger(storageURL: url)
        #expect(reloaded.contains(remoteID: "plaud-1"))
        #expect(reloaded.lastSuccessfulSyncAt != nil)
    }

    @Test("失敗した録音は次回同期で再試行対象になる")
    func failedRecordingIsNotMarkedImported() {
        let url = temporaryLedgerURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let ledger = PlaudCloudSyncLedger(storageURL: url)
        ledger.recordFailure(remoteID: "plaud-2", message: "network")

        #expect(ledger.contains(remoteID: "plaud-2") == false)
    }

    private func temporaryLedgerURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("ledger.json")
    }
}
