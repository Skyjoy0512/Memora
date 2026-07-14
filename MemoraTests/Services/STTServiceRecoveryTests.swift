import Foundation
import Testing
@testable import Memora

@Suite("STTService recovery", .serialized)
struct STTServiceRecoveryTests {
    @Test("API並列経路は復元済みチャンクを再実行せず新規結果だけ保存する")
    func concurrentPathRestoresAndSavesOnlyMissingChunks() async throws {
        let sourceURL = try Self.makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let chunker = FakeChunker(chunks: [
            AudioChunk(index: 0, startSec: 0, endSec: 90, url: URL(fileURLWithPath: "/tmp/restored.m4a"), isTemporary: true),
            AudioChunk(index: 1, startSec: 90, endSec: 180, url: URL(fileURLWithPath: "/tmp/new.m4a"), isTemporary: true)
        ])
        let backendRecorder = BackendInvocationRecorder()
        let checkpointRecorder = CheckpointHookRecorder(restored: [
            0: CheckpointChunkResult(from: Self.makeResult(index: 0, text: "復元", estimated: true))
        ])
        let previousDiarizationSetting = STTLocalProcessingSettings.isSpeakerDiarizationEnabled
        STTLocalProcessingSettings.isSpeakerDiarizationEnabled = false
        defer { STTLocalProcessingSettings.isSpeakerDiarizationEnabled = previousDiarizationSetting }

        let service = STTService(
            readiness: FakeReadiness(),
            chunkerFactory: { chunker },
            backendFactory: { taskID, _ in
                let index = Self.chunkIndex(from: taskID)
                return FakeSTTBackend(index: index, recorder: backendRecorder) {
                    Self.makeResult(index: index, text: "新規", estimated: true)
                }
            }
        )
        service.updateConfiguration(
            apiKey: "test-key",
            provider: .openai,
            transcriptionMode: .api
        )
        service.updateCheckpointHooks(checkpointRecorder.hooks)

        let (rawHandle, _) = try await service.startTranscription(
            audioURL: sourceURL,
            language: "ja"
        )
        let handle = try #require(rawHandle as? STTTaskHandle)
        let result = try await handle.result()

        #expect(result.fullText == "復元\n新規")
        #expect(result.segments.count == 2)
        #expect(result.segments.map(\.isEstimatedTiming) == [true, true])
        #expect(backendRecorder.indices == [1])
        #expect(checkpointRecorder.savedIndices == [1])
        #expect(checkpointRecorder.clearCount == 0)
        #expect(chunker.cleanedChunkIndices == [1])
    }

    @Test("直列経路はbackend失敗時にも書き出し済みチャンクを削除する")
    func serialPathCleansChunkAfterFailure() async throws {
        let sourceURL = try Self.makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let chunker = FakeChunker(chunks: [
            AudioChunk(index: 0, startSec: 0, endSec: 30, url: URL(fileURLWithPath: "/tmp/failure.m4a"), isTemporary: true)
        ])
        let backendRecorder = BackendInvocationRecorder()
        let service = STTService(
            readiness: FakeReadiness(),
            chunkerFactory: { chunker },
            backendFactory: { taskID, _ in
                let index = Self.chunkIndex(from: taskID)
                return FakeSTTBackend(index: index, recorder: backendRecorder) {
                    throw TestBackendError.failed
                }
            }
        )

        let (rawHandle, _) = try await service.startTranscription(
            audioURL: sourceURL,
            language: "ja"
        )
        let handle = try #require(rawHandle as? STTTaskHandle)

        do {
            _ = try await handle.result()
            Issue.record("backend error が伝播する必要があります")
        } catch {
            #expect(backendRecorder.indices == [0])
            #expect(chunker.cleanedChunkIndices == [0])
        }
    }

    @Test("キャンセルはbackendへ伝播し一時チャンクを削除する")
    func cancellationCleansExportedChunk() async throws {
        let sourceURL = try Self.makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let chunker = FakeChunker(chunks: [
            AudioChunk(index: 0, startSec: 0, endSec: 30, url: URL(fileURLWithPath: "/tmp/cancel.m4a"), isTemporary: true)
        ])
        let backendRecorder = BackendInvocationRecorder()
        let service = STTService(
            readiness: FakeReadiness(),
            chunkerFactory: { chunker },
            backendFactory: { taskID, _ in
                let index = Self.chunkIndex(from: taskID)
                return FakeSTTBackend(index: index, recorder: backendRecorder) {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    return Self.makeResult(index: index, text: "遅延", estimated: false)
                }
            }
        )

        let (rawHandle, _) = try await service.startTranscription(
            audioURL: sourceURL,
            language: "ja"
        )
        let handle = try #require(rawHandle as? STTTaskHandle)
        while backendRecorder.indices.isEmpty {
            await Task.yield()
        }
        await handle.cancel()

        do {
            _ = try await handle.result()
            Issue.record("キャンセルが結果待機へ伝播する必要があります")
        } catch is CancellationError {
            #expect(chunker.cleanedChunkIndices == [0])
        } catch {
            Issue.record("CancellationError を期待しました: \(error)")
        }
    }

    private static func makeTemporarySourceFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stt-recovery-\(UUID().uuidString).m4a")
        try Data().write(to: url)
        return url
    }

    private static func chunkIndex(from taskID: String) -> Int {
        Int(taskID.split(separator: "-").last ?? "0") ?? 0
    }

    private static func makeResult(
        index: Int,
        text: String,
        estimated: Bool
    ) -> TranscriptionResult {
        TranscriptionResult(
            fullText: text,
            language: "ja",
            segments: [
                TranscriptionSegment(
                    id: "segment-\(index)",
                    speakerLabel: "Speaker 1",
                    startSec: 0,
                    endSec: 1,
                    text: text,
                    isEstimatedTiming: estimated
                )
            ]
        )
    }
}

private enum TestBackendError: Error {
    case failed
}

private final class BackendInvocationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []

    var indices: [Int] {
        lock.withLock { storage.sorted() }
    }

    func record(_ index: Int) {
        lock.withLock { storage.append(index) }
    }
}

private final class FakeSTTBackend: STTBackendProcessing, @unchecked Sendable {
    private let index: Int
    private let recorder: BackendInvocationRecorder
    private let operation: @Sendable () async throws -> TranscriptionResult

    init(
        index: Int,
        recorder: BackendInvocationRecorder,
        operation: @escaping @Sendable () async throws -> TranscriptionResult
    ) {
        self.index = index
        self.recorder = recorder
        self.operation = operation
    }

    func transcribe(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        recorder.record(index)
        return try await operation()
    }
}

private final class CheckpointHookRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let restored: [Int: CheckpointChunkResult]
    private var savedIndicesStorage: [Int] = []
    private var clearCountStorage = 0

    init(restored: [Int: CheckpointChunkResult]) {
        self.restored = restored
    }

    var savedIndices: [Int] {
        lock.withLock { savedIndicesStorage.sorted() }
    }

    var clearCount: Int {
        lock.withLock { clearCountStorage }
    }

    var hooks: STTCheckpointHooks {
        STTCheckpointHooks(
            load: { [self] _ in restored },
            save: { [self] _, _, index, _ in
                lock.withLock { savedIndicesStorage.append(index) }
            },
            clear: { [self] in
                lock.withLock { clearCountStorage += 1 }
            }
        )
    }
}
