import Testing
import Foundation
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
                    text: "こんにちは、"
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
