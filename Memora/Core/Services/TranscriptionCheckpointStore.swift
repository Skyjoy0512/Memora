import Foundation
import SwiftData

/// TranscriptionCheckpoint の読み書き。MainActor で ModelContext を扱う。
@MainActor
final class TranscriptionCheckpointStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(audioFileID: UUID, fingerprint: String) -> [Int: CheckpointChunkResult] {
        guard let cp = fetch(audioFileID: audioFileID) else { return [:] }
        guard cp.audioFingerprint == fingerprint else {
            modelContext.delete(cp)
            try? modelContext.save()
            return [:]
        }
        return decode(cp)
    }

    func save(
        audioFileID: UUID,
        fingerprint: String,
        totalChunks: Int,
        chunkIndex: Int,
        result: CheckpointChunkResult
    ) {
        let cp: TranscriptionCheckpoint = fetch(audioFileID: audioFileID) ?? {
            let new = TranscriptionCheckpoint(
                audioFileID: audioFileID,
                audioFingerprint: fingerprint,
                totalChunks: totalChunks
            )
            modelContext.insert(new)
            return new
        }()
        var all = decode(cp)
        all[chunkIndex] = result
        encode(all, into: cp)
        cp.updatedAt = Date()
        try? modelContext.save()
    }

    func delete(audioFileID: UUID) {
        guard let cp = fetch(audioFileID: audioFileID) else { return }
        modelContext.delete(cp)
        try? modelContext.save()
    }

    // MARK: - Private

    private func fetch(audioFileID: UUID) -> TranscriptionCheckpoint? {
        var descriptor = FetchDescriptor<TranscriptionCheckpoint>(
            predicate: #Predicate { $0.audioFileID == audioFileID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func decode(_ cp: TranscriptionCheckpoint) -> [Int: CheckpointChunkResult] {
        guard !cp.chunkResultsBlob.isEmpty,
              let decoded = try? JSONDecoder().decode([Int: CheckpointChunkResult].self, from: cp.chunkResultsBlob)
        else { return [:] }
        return decoded
    }

    private func encode(_ dict: [Int: CheckpointChunkResult], into cp: TranscriptionCheckpoint) {
        if let data = try? JSONEncoder().encode(dict) {
            cp.chunkResultsBlob = data
        }
    }
}
