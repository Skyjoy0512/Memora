import Testing
import Foundation
@testable import Memora

/// テスト用の共通ヘルパー
///
/// - Note: iOS 26.2 Simulator において、テストホストアプリが既に ModelContainer を
///   作成している状態で同じスキーマの別 ModelContainer を作成すると
///   SwiftData が EXC_BREAKPOINT を起こすバグがある。
///   そのため ModelContext を使ったテストは不可。
///   @Model オブジェクトのプロパティテストのみ実行する。
enum TestModelContainer {
}

struct STTCoreTests {
    @Test("iOS 26 対応時は SpeechAnalyzer を優先する")
    func speechAnalyzerPreferredWhenSupported() {
        let selection = LocalSTTBackendResolver.resolve(
            osSupportsSpeechAnalyzer: true,
            supportStatus: .available
        )

        #expect(selection == .speechAnalyzer)
    }

    @Test("iOS 26 未満は SFSpeechRecognizer にフォールバックする")
    func speechRecognizerFallbackOnOlderOS() {
        let selection = LocalSTTBackendResolver.resolve(
            osSupportsSpeechAnalyzer: false,
            supportStatus: nil
        )

        #expect(selection == .speechRecognizer(reason: .osTooOld))
    }

    @Test("SpeechAnalyzer の非対応理由をフォールバック理由へ写像する")
    func fallbackReasonMapping() {
        #expect(
            LocalSTTBackendResolver.resolve(
                osSupportsSpeechAnalyzer: true,
                supportStatus: .localeUnavailable
            ) == .speechRecognizer(reason: .localeUnavailable)
        )
        #expect(
            LocalSTTBackendResolver.resolve(
                osSupportsSpeechAnalyzer: true,
                supportStatus: .assetUnavailable
            ) == .speechRecognizer(reason: .assetUnavailable)
        )
    }

    @Test("ローカル STT では pre-chunk を無効化する")
    func localChunkingPolicy() {
        #expect(STTChunkingPolicy.shouldPreChunk(transcriptionMode: .local) == false)
        #expect(STTChunkingPolicy.shouldPreChunk(transcriptionMode: .api) == true)
    }

    #if swift(>=6.2)
    @available(iOS 26.0, *)
    @Test("SpeechAnalyzer の time-indexed segment は core segment にそのまま変換できる")
    func speechAnalyzerSegmentMapping() {
        let output = SpeechAnalyzerTranscriptionOutput(
            fullText: "こんにちは\nよろしくお願いします",
            segments: [
                SpeechAnalyzerTimeIndexedSegment(
                    id: "speech-analyzer-0",
                    startSec: 0,
                    endSec: 1.2,
                    text: "こんにちは"
                ),
                SpeechAnalyzerTimeIndexedSegment(
                    id: "speech-analyzer-1",
                    startSec: 1.2,
                    endSec: 2.8,
                    text: "よろしくお願いします"
                )
            ]
        )

        let mapped = output.segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                speakerLabel: "Speaker 1",
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: segment.text
            )
        }

        #expect(mapped.count == 2)
        #expect(mapped[0].startSec == 0)
        #expect(mapped[0].endSec == 1.2)
        #expect(mapped[1].text == "よろしくお願いします")
    }
    #endif
}
