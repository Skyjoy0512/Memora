import Testing
import Foundation
@testable import Memora

// MARK: - StreamingTranscriptMerger Tests

struct StreamingTranscriptMergerTests {

    @Test("チャンクオフセットがセグメント時刻に加算される")
    func mergerAddsChunkOffsetToSegmentTimes() {
        var merger = StreamingTranscriptMerger()
        let chunk = AudioChunk(index: 1, startSec: 90, endSec: 180, url: URL(fileURLWithPath: "/tmp/a.m4a"), isTemporary: true)
        let result = TranscriptionResult(
            fullText: "こんにちは",
            language: "ja",
            segments: [
                TranscriptionSegment(id: "s1", speakerLabel: "", startSec: 1.0, endSec: 3.0, text: "こんにちは")
            ]
        )
        merger.append(chunk: chunk, result: result)
        let final = merger.finalize()
        #expect(final.segments.count == 1)
        #expect(final.segments[0].startSec == 91.0)
        #expect(final.segments[0].endSec == 93.0)
    }

    @Test("推定時刻フラグがチャンク結合後も保持される")
    func mergerPreservesEstimatedTiming() {
        var merger = StreamingTranscriptMerger()
        let chunk = AudioChunk(index: 0, startSec: 0, endSec: 90, url: URL(fileURLWithPath: "/tmp/a.m4a"), isTemporary: true)
        let result = TranscriptionResult(
            fullText: "こんにちは",
            language: "ja",
            segments: [
                TranscriptionSegment(
                    id: "s1",
                    speakerLabel: "",
                    startSec: 1.0,
                    endSec: 3.0,
                    text: "こんにちは",
                    isEstimatedTiming: true
                )
            ]
        )

        merger.append(chunk: chunk, result: result)

        #expect(merger.finalize().segments.first?.isEstimatedTiming == true)
    }

    @Test("複数チャンクの全文が改行で結合される")
    func mergerJoinsTextWithNewlines() {
        var merger = StreamingTranscriptMerger()
        let chunk1 = AudioChunk(index: 0, startSec: 0, endSec: 90, url: URL(fileURLWithPath: "/tmp/a.m4a"), isTemporary: true)
        let chunk2 = AudioChunk(index: 1, startSec: 90, endSec: 180, url: URL(fileURLWithPath: "/tmp/b.m4a"), isTemporary: true)
        merger.append(chunk: chunk1, result: TranscriptionResult(fullText: "hello", language: "ja", segments: []))
        merger.append(chunk: chunk2, result: TranscriptionResult(fullText: "world", language: "ja", segments: []))
        let final = merger.finalize()
        #expect(final.fullText == "hello\nworld")
    }

    @Test("最初の結果から言語が採用される")
    func mergerUsesFirstResultLanguage() {
        var merger = StreamingTranscriptMerger()
        merger.append(
            chunk: AudioChunk(index: 0, startSec: 0, endSec: 90, url: URL(fileURLWithPath: "/tmp/a.m4a"), isTemporary: true),
            result: TranscriptionResult(fullText: "a", language: "en", segments: [])
        )
        merger.append(
            chunk: AudioChunk(index: 1, startSec: 90, endSec: 180, url: URL(fileURLWithPath: "/tmp/b.m4a"), isTemporary: true),
            result: TranscriptionResult(fullText: "b", language: "ja", segments: [])
        )
        #expect(merger.finalize().language == "en")
    }

    @Test("finalize with preferredLanguage が detectedLanguage より優先される")
    func preferredLanguageOverridesDetected() {
        var merger = StreamingTranscriptMerger()
        merger.append(
            chunk: AudioChunk(index: 0, startSec: 0, endSec: 90, url: URL(fileURLWithPath: "/tmp/a.m4a"), isTemporary: true),
            result: TranscriptionResult(fullText: "a", language: "en", segments: [])
        )
        let final = merger.finalize(preferredLanguage: "ja-JP")
        #expect(final.language == "ja")
    }
}
