import Foundation
@preconcurrency import AVFoundation

public typealias AudioChunkProgressHandler = @Sendable (_ completed: Int, _ total: Int) -> Void

/// チャンクの境界だけを持つ軽量プラン（ファイル書き出しはしない）
public struct AudioChunkPlan: Sendable {
    public struct Slice: Sendable {
        public let index: Int
        public let startSec: Double
        public let endSec: Double

        public init(index: Int, startSec: Double, endSec: Double) {
            self.index = index
            self.startSec = startSec
            self.endSec = endSec
        }
    }

    public let sourceURL: URL
    public let totalDuration: Double
    public let slices: [Slice]

    public init(sourceURL: URL, totalDuration: Double, slices: [Slice]) {
        self.sourceURL = sourceURL
        self.totalDuration = totalDuration
        self.slices = slices
    }

    public var count: Int { slices.count }
    public var isSingleChunk: Bool { slices.count == 1 }
}

public protocol AudioChunkerProtocol: Sendable {
    /// 従来 API（短尺・後方互換のため残す）
    func analyzeAndChunk(
        fileURL: URL,
        onProgress: AudioChunkProgressHandler?
    ) async throws -> [AudioChunk]

    /// 新API: 計画だけ作る（書き出さない・軽い）
    func plan(fileURL: URL) async throws -> AudioChunkPlan

    /// 新API: 1スライスだけを一時ファイルへ書き出す（呼ばれた時に初めて書く）
    func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk

    func cleanup(chunks: [AudioChunk]) async

    /// 単一チャンクの後始末（逐次処理用）
    func cleanupChunk(_ chunk: AudioChunk) async
}

public extension AudioChunkerProtocol {
    func analyzeAndChunk(fileURL: URL) async throws -> [AudioChunk] {
        try await analyzeAndChunk(fileURL: fileURL, onProgress: nil)
    }
}

public struct AudioChunk: Sendable, Hashable {
    public let index: Int
    public let startSec: Double
    public let endSec: Double
    public let url: URL
    public let isTemporary: Bool

    public init(index: Int, startSec: Double, endSec: Double, url: URL, isTemporary: Bool) {
        self.index = index
        self.startSec = startSec
        self.endSec = endSec
        self.url = url
        self.isTemporary = isTemporary
    }
}

public enum AudioChunkerError: LocalizedError {
    case fileNotFound
    case durationUnavailable
    case exportSessionUnavailable
    case exportFailed(Error?)

    public var errorDescription: String? {
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

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }
}

public final class AudioChunker: AudioChunkerProtocol {
    // 90秒未満はチャンク分割なし
    private let shortThreshold: TimeInterval = 90
    private let longThreshold: TimeInterval = 60 * 60 * 3
    // SFSpeechRecognizer が確実に処理できるチャンクサイズ（90秒）
    private let standardChunkDuration: TimeInterval = 90
    private let smallChunkDuration: TimeInterval = 90

    public init() {}

    // MARK: - Legacy API (後方互換)

    public func analyzeAndChunk(
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

        do {
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
        } catch {
            await cleanup(chunks: chunks)
            throw error
        }

        return chunks
    }

    // MARK: - Streaming API (PR-B9)

    public func plan(fileURL: URL) async throws -> AudioChunkPlan {
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
            return AudioChunkPlan(
                sourceURL: fileURL,
                totalDuration: duration,
                slices: [.init(index: 0, startSec: 0, endSec: duration)]
            )
        }

        let chunkDuration = duration < longThreshold ? standardChunkDuration : smallChunkDuration
        var slices: [AudioChunkPlan.Slice] = []
        var startSec = 0.0
        var index = 0
        while startSec < duration {
            let endSec = min(startSec + chunkDuration, duration)
            slices.append(.init(index: index, startSec: startSec, endSec: endSec))
            index += 1
            startSec = endSec
        }
        return AudioChunkPlan(sourceURL: fileURL, totalDuration: duration, slices: slices)
    }

    public func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk {
        // 単一チャンク（短尺）は元ファイルをそのまま使い書き出さない
        if plan.isSingleChunk {
            return AudioChunk(
                index: 0,
                startSec: 0,
                endSec: plan.totalDuration,
                url: plan.sourceURL,
                isTemporary: false
            )
        }
        let asset = AVURLAsset(url: plan.sourceURL)
        let url = try await exportChunk(from: asset, start: slice.startSec, end: slice.endSec, index: slice.index)
        return AudioChunk(
            index: slice.index,
            startSec: slice.startSec,
            endSec: slice.endSec,
            url: url,
            isTemporary: true
        )
    }

    public func cleanup(chunks: [AudioChunk]) async {
        let temporaryChunks = chunks.filter(\.isTemporary)
        for chunk in temporaryChunks {
            try? FileManager.default.removeItem(at: chunk.url)
        }
    }

    public func cleanupChunk(_ chunk: AudioChunk) async {
        guard chunk.isTemporary else { return }
        try? FileManager.default.removeItem(at: chunk.url)
    }

    // MARK: - Private

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
        let exportSessionBox = ExportSessionBox(session: exportSession)

        exportSession.outputURL = exportURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: end - start, preferredTimescale: 600)
        )

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    exportSessionBox.session.exportAsynchronously {
                        switch exportSessionBox.session.status {
                        case .completed:
                            continuation.resume()
                        case .failed, .cancelled:
                            continuation.resume(throwing: AudioChunkerError.exportFailed(exportSessionBox.session.error))
                        default:
                            continuation.resume(throwing: AudioChunkerError.exportFailed(exportSessionBox.session.error))
                        }
                    }
                }
            } onCancel: {
                exportSessionBox.session.cancelExport()
            }
        } catch {
            try? FileManager.default.removeItem(at: exportURL)
            throw error
        }

        return exportURL
    }
}

public enum STTFileLocations {
    public static func audioDirectory() throws -> URL {
        try baseDirectory(named: "Audio")
    }

    public static func chunksDirectory() throws -> URL {
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
