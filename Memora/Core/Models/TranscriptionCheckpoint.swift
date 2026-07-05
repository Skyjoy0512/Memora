import Foundation
import SwiftData

/// 文字起こしのチャンク単位チェックポイント。
/// 完了済みチャンクの結果を保持し、中断後の再実行で再利用する。
/// 成功完了時に削除される揮発性の中間データ。
@Model
final class TranscriptionCheckpoint {
    @Attribute(.unique) var audioFileID: UUID
    var audioFingerprint: String
    var totalChunks: Int
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var chunkResultsBlob: Data

    init(audioFileID: UUID, audioFingerprint: String, totalChunks: Int) {
        self.audioFileID = audioFileID
        self.audioFingerprint = audioFingerprint
        self.totalChunks = totalChunks
        self.createdAt = Date()
        self.updatedAt = Date()
        self.chunkResultsBlob = Data()
    }
}

/// チェックポイントに保存するチャンク結果。
/// TranscriptionResult 自体を Codable 化せず、保存用の独立 DTO とする。
struct CheckpointChunkResult: Codable, Sendable {
    struct Segment: Codable, Sendable {
        let id: String
        let speakerLabel: String
        let startSec: Double
        let endSec: Double
        let text: String
        let isEstimatedTiming: Bool
    }
    let fullText: String
    let language: String
    let segments: [Segment]

    init(from result: TranscriptionResult) {
        self.fullText = result.fullText
        self.language = result.language
        self.segments = result.segments.map {
            Segment(
                id: $0.id,
                speakerLabel: $0.speakerLabel,
                startSec: $0.startSec,
                endSec: $0.endSec,
                text: $0.text,
                isEstimatedTiming: $0.isEstimatedTiming
            )
        }
    }

    func toTranscriptionResult() -> TranscriptionResult {
        TranscriptionResult(
            fullText: fullText,
            language: language,
            segments: segments.map {
                TranscriptionSegment(
                    id: $0.id,
                    speakerLabel: $0.speakerLabel,
                    startSec: $0.startSec,
                    endSec: $0.endSec,
                    text: $0.text,
                    isEstimatedTiming: $0.isEstimatedTiming
                )
            }
        )
    }
}
