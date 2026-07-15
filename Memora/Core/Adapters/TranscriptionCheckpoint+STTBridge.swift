import Foundation

/// Host-only STT conversion for the checkpoint's Codable persistence payload.
/// The SwiftData model itself remains independent of STT result types.
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
        fullText = result.fullText
        language = result.language
        segments = result.segments.map {
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
