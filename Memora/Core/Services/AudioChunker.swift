import Foundation
@preconcurrency import AVFoundation

typealias AudioChunkProgressHandler = @Sendable (_ completed: Int, _ total: Int) -> Void

protocol AudioChunkerProtocol: Sendable {
    func analyzeAndChunk(
        fileURL: URL,
        onProgress: AudioChunkProgressHandler?
    ) async throws -> [AudioChunk]

    func cleanup(chunks: [AudioChunk]) async
}

extension AudioChunkerProtocol {
    func analyzeAndChunk(fileURL: URL) async throws -> [AudioChunk] {
        try await analyzeAndChunk(fileURL: fileURL, onProgress: nil)
    }
}

struct AudioChunk: Sendable, Hashable {
    let index: Int
    let startSec: Double
    let endSec: Double
    let url: URL
    let isTemporary: Bool
}

enum AudioChunkerError: LocalizedError {
    case fileNotFound
    case durationUnavailable
    case exportSessionUnavailable
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .durationUnavailable:
            return "音声ファイルの長さを取得できません"
        case .exportSessionUnavailable:
            return "チャンク書き出しセッションを作成できません"
        case .exportFailed(let error):
            if let error {
                return "チャンク書き出しに失敗しました: \(error.localizedDescription)"
            }
            return "チャンク書き出しに失敗しました"
        }
    }
}

final class AudioChunker: AudioChunkerProtocol {
    private let shortThreshold: TimeInterval = 60 * 60
    private let longThreshold: TimeInterval = 60 * 60 * 3
    private let standardChunkDuration: TimeInterval = 10 * 60
    private let smallChunkDuration: TimeInterval = 5 * 60

    func analyzeAndChunk(
        fileURL: URL,
        onProgress: AudioChunkProgressHandler? = nil
    ) async throws -> [AudioChunk] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AudioChunkerError.fileNotFound
        }

        let asset = AVURLAsset(url: fileURL)
        guard let loadedDuration = try? await asset.load(.duration) else {
            throw AudioChunkerError.durationUnavailable
        }

        let duration = CMTimeGetSeconds(loadedDuration)
        guard duration.isFinite, duration >= 0 else {
            throw AudioChunkerError.durationUnavailable
        }

        if duration < shortThreshold {
            onProgress?(1, 1)
            return [
                AudioChunk(
                    index: 0,
                    startSec: 0,
                    endSec: duration,
                    url: fileURL,
                    isTemporary: false
                )
            ]
        }

        let chunkDuration = duration < longThreshold ? standardChunkDuration : smallChunkDuration
        let total = Int(ceil(duration / chunkDuration))

        var chunks: [AudioChunk] = []
        var startSec = 0.0
        var index = 0

        while startSec < duration {
            try Task.checkCancellation()

            let endSec = min(startSec + chunkDuration, duration)
            let url = try await exportChunk(
                from: asset,
                start: startSec,
                end: endSec,
                index: index
            )
            chunks.append(
                AudioChunk(
                    index: index,
                    startSec: startSec,
                    endSec: endSec,
                    url: url,
                    isTemporary: true
                )
            )

            index += 1
            startSec = endSec
            onProgress?(index, total)
        }

        return chunks
    }

    func cleanup(chunks: [AudioChunk]) async {
        let temporaryChunks = chunks.filter(\.isTemporary)
        for chunk in temporaryChunks {
            try? FileManager.default.removeItem(at: chunk.url)
        }
    }

    private func exportChunk(
        from asset: AVURLAsset,
        start: Double,
        end: Double,
        index: Int
    ) async throws -> URL {
        let exportURL = try STTFileLocations.chunksDirectory()
            .appendingPathComponent("chunk_\(index)_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioChunkerError.exportSessionUnavailable
        }

        exportSession.outputURL = exportURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: end - start, preferredTimescale: 600)
        )

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: AudioChunkerError.exportFailed(exportSession.error))
                default:
                    continuation.resume(throwing: AudioChunkerError.exportFailed(exportSession.error))
                }
            }
        }

        return exportURL
    }
}

enum STTFileLocations {
    static func audioDirectory() throws -> URL {
        try baseDirectory(named: "Audio")
    }

    static func chunksDirectory() throws -> URL {
        try baseDirectory(named: "Chunks")
    }

    private static func baseDirectory(named name: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }
}
