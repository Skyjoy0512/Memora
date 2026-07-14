import Testing
import Foundation
import SwiftData
@testable import Memora

// MARK: - CheckpointChunkResult DTO Tests

struct TranscriptionCheckpointDTOTests {

    @Test("CheckpointChunkResult ↔ TranscriptionResult の往復変換で等価性が保たれる")
    func dtoRoundTripPreservesData() {
        let original = TranscriptionResult(
            fullText: "こんにちは、世界",
            language: "ja",
            segments: [
                TranscriptionSegment(
                    id: "s1",
                    speakerLabel: "話者1",
                    startSec: 0.0,
                    endSec: 2.5,
                    text: "こんにちは、",
                    isEstimatedTiming: true
                ),
                TranscriptionSegment(
                    id: "s2",
                    speakerLabel: "話者1",
                    startSec: 2.5,
                    endSec: 4.0,
                    text: "世界"
                )
            ]
        )

        let dto = CheckpointChunkResult(from: original)
        let restored = dto.toTranscriptionResult()

        #expect(restored.fullText == original.fullText)
        #expect(restored.language == original.language)
        #expect(restored.segments.count == original.segments.count)

        for i in 0..<original.segments.count {
            #expect(restored.segments[i].id == original.segments[i].id)
            #expect(restored.segments[i].speakerLabel == original.segments[i].speakerLabel)
            #expect(restored.segments[i].startSec == original.segments[i].startSec)
            #expect(restored.segments[i].endSec == original.segments[i].endSec)
            #expect(restored.segments[i].text == original.segments[i].text)
            #expect(restored.segments[i].isEstimatedTiming == original.segments[i].isEstimatedTiming)
        }
    }

    @Test("空の segments でも正しく往復できる")
    func emptySegmentsRoundTrip() {
        let original = TranscriptionResult(
            fullText: "",
            language: "en",
            segments: []
        )
        let dto = CheckpointChunkResult(from: original)
        let restored = dto.toTranscriptionResult()

        #expect(restored.fullText == "")
        #expect(restored.language == "en")
        #expect(restored.segments.isEmpty)
    }

    @Test("JSON エンコード / デコードで等価性が保たれる")
    func jsonRoundTripPreservesData() throws {
        let original = CheckpointChunkResult(from: TranscriptionResult(
            fullText: "テスト",
            language: "ja",
            segments: [
                TranscriptionSegment(id: "s0", speakerLabel: "", startSec: 1.0, endSec: 2.0, text: "テスト")
            ]
        ))

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(CheckpointChunkResult.self, from: data)

        let originalResult = original.toTranscriptionResult()
        let restoredResult = restored.toTranscriptionResult()

        #expect(restoredResult.fullText == originalResult.fullText)
        #expect(restoredResult.language == originalResult.language)
        #expect(restoredResult.segments.count == originalResult.segments.count)
    }
}

struct TranscriptionCheckpointStoreTests {
    @Test("保存・復元・削除を本体DBとは独立したファイルで行う")
    func fileStoreRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("checkpoint-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let audioFileID = UUID()
        let store = TranscriptionCheckpointStore(directoryURL: directory)
        let original = CheckpointChunkResult(from: TranscriptionResult(
            fullText: "途中結果",
            language: "ja",
            segments: [
                TranscriptionSegment(
                    id: "segment",
                    speakerLabel: "Speaker 1",
                    startSec: 0,
                    endSec: 1,
                    text: "途中結果",
                    isEstimatedTiming: true
                )
            ]
        ))

        await store.save(
            audioFileID: audioFileID,
            fingerprint: "fingerprint",
            totalChunks: 2,
            chunkIndex: 0,
            result: original
        )

        let restored = await store.load(audioFileID: audioFileID, fingerprint: "fingerprint")
        #expect(restored[0]?.fullText == "途中結果")
        #expect(restored[0]?.segments.first?.isEstimatedTiming == true)

        let mismatched = await store.load(audioFileID: audioFileID, fingerprint: "changed")
        #expect(mismatched.isEmpty)
        #expect(await store.load(audioFileID: audioFileID, fingerprint: "fingerprint").isEmpty)
    }
}

struct MemoraSchemaMigrationTests {
    @Test("V2ストアをユーザーデータ削除なしでV3へ移行できる")
    func v2StoreMigratesToV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Memora.store")
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let audioFileID = UUID()

        do {
            let v2Container = try ModelContainer(
                for: Schema(versionedSchema: MemoraSchemaV2.self),
                configurations: [configuration]
            )
            let context = ModelContext(v2Container)
            context.insert(AudioFile(title: "保持対象", audioURL: "/tmp/audio.m4a"))
            context.insert(TranscriptionCheckpoint(
                audioFileID: audioFileID,
                audioFingerprint: "obsolete",
                totalChunks: 1
            ))
            try context.save()
        }

        let v3Container = try ModelContainer(
            for: Schema(versionedSchema: MemoraSchemaV3.self),
            migrationPlan: MemoraMigrationPlan.self,
            configurations: [configuration]
        )
        let context = ModelContext(v3Container)
        let audioFiles = try context.fetch(FetchDescriptor<AudioFile>())
        #expect(audioFiles.count == 1)
        #expect(audioFiles.first?.title == "保持対象")
        #expect(try context.fetch(FetchDescriptor<Transcript>()).isEmpty)
    }
}
