import Foundation
@testable import Memora

// MARK: - STT Test Doubles

/// 常に準備完了を返すフェイク。
final class FakeReadiness: STTReadinessProtocol, @unchecked Sendable {
    var isReady: Bool { get async { true } }
    var supportedLanguages: [String] { get async { ["ja", "en"] } }
    var requiresDownload: Bool { get async { false } }
    func prepare() async throws {}
}

/// 固定チャンク構成を返すフェイク。実音声ファイル不要。
final class FakeChunker: AudioChunkerProtocol, @unchecked Sendable {
    let chunks: [AudioChunk]
    private(set) var cleanupCalled = false

    init(chunks: [AudioChunk]) { self.chunks = chunks }

    func analyzeAndChunk(fileURL: URL, onProgress: AudioChunkProgressHandler?) async throws -> [AudioChunk] {
        onProgress?(chunks.count, chunks.count)
        return chunks
    }

    func plan(fileURL: URL) async throws -> AudioChunkPlan {
        let slices = chunks.map {
            AudioChunkPlan.Slice(index: $0.index, startSec: $0.startSec, endSec: $0.endSec)
        }
        let totalDuration = chunks.last?.endSec ?? 0
        return AudioChunkPlan(sourceURL: fileURL, totalDuration: totalDuration, slices: slices)
    }

    func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk {
        guard let chunk = chunks.first(where: { $0.index == slice.index }) else {
            throw NSError(domain: "FakeChunker", code: 1, userInfo: [NSLocalizedDescriptionKey: "unknown slice"])
        }
        return chunk
    }

    func cleanup(chunks: [AudioChunk]) async { cleanupCalled = true }
    func cleanupChunk(_ chunk: AudioChunk) async {}
}
