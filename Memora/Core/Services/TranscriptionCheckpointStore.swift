import Foundation
import os

/// チャンク単位の文字起こし結果を、SwiftData の本体ストアとは分離して保存する。
///
/// チェックポイントは再生成可能な中間データのため、アプリ本体のスキーマ変更や
/// マイグレーション失敗がユーザーデータへ波及しないファイルストアを使う。
actor TranscriptionCheckpointStore {
    private struct StoredCheckpoint: Codable {
        let audioFileID: UUID
        let audioFingerprint: String
        let totalChunks: Int
        let createdAt: Date
        var updatedAt: Date
        var chunkResults: [Int: CheckpointChunkResult]
    }

    private let directoryURL: URL
    private let fileManager: FileManager
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.memora.Memora",
        category: "TranscriptionCheckpoint"
    )

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
    }

    func load(audioFileID: UUID, fingerprint: String) -> [Int: CheckpointChunkResult] {
        guard let checkpoint = read(audioFileID: audioFileID) else { return [:] }
        guard checkpoint.audioFingerprint == fingerprint else {
            delete(audioFileID: audioFileID)
            return [:]
        }
        return checkpoint.chunkResults
    }

    func save(
        audioFileID: UUID,
        fingerprint: String,
        totalChunks: Int,
        chunkIndex: Int,
        result: CheckpointChunkResult
    ) {
        let now = Date()
        var checkpoint: StoredCheckpoint
        if let existing = read(audioFileID: audioFileID),
           existing.audioFingerprint == fingerprint {
            checkpoint = existing
        } else {
            checkpoint = StoredCheckpoint(
                audioFileID: audioFileID,
                audioFingerprint: fingerprint,
                totalChunks: totalChunks,
                createdAt: now,
                updatedAt: now,
                chunkResults: [:]
            )
        }

        checkpoint.chunkResults[chunkIndex] = result
        checkpoint.updatedAt = now

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(checkpoint)
            try data.write(to: fileURL(audioFileID: audioFileID), options: .atomic)
        } catch {
            logFailure(operation: "save", error: error)
        }
    }

    func delete(audioFileID: UUID) {
        let url = fileURL(audioFileID: audioFileID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logFailure(operation: "delete", error: error)
        }
    }

    private func read(audioFileID: UUID) -> StoredCheckpoint? {
        let url = fileURL(audioFileID: audioFileID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(
                StoredCheckpoint.self,
                from: Data(contentsOf: url)
            )
        } catch {
            logFailure(operation: "load", error: error)
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    private func fileURL(audioFileID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(audioFileID.uuidString.lowercased()).json")
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Memora", isDirectory: true)
            .appendingPathComponent("TranscriptionCheckpoints", isDirectory: true)
    }

    private func logFailure(operation: String, error: Error) {
        logger.error(
            "Failed to \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
    }
}
