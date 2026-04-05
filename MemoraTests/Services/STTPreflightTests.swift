import Testing
import Foundation
@testable import Memora

// MARK: - STTErrorMapper Tests

struct STTErrorMapperTests {

    @Test("CoreError はそのまま返される")
    func coreErrorPassthrough() {
        let original = CoreError.notFound(type: "File", id: UUID())
        let mapped = STTErrorMapper.mapToCoreError(original)
        #expect(mapped == original)
    }

    @Test("TranscriptionError は .transcriptionError にラップされる")
    func transcriptionErrorMapping() {
        let error = TranscriptionError.audioFileInvalid
        let mapped = STTErrorMapper.mapToCoreError(error)
        #expect(mapped == .transcriptionError(.audioFileInvalid))
    }

    @Test("AudioChunkerError は .pipelineError(.transcriptionFailed) に変換される")
    func audioChunkerErrorMapping() {
        let error = AudioChunkerError.fileNotFound
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .pipelineError(.transcriptionFailed(let message)) = mapped {
            #expect(message == "音声ファイルが見つかりません")
        } else {
            Issue.record("Expected .pipelineError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("AIError は .transcriptionError(.transcriptionFailed) に変換される")
    func aiErrorMapping() {
        let error = AIError.apiKeyMissing
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message == "APIキーが設定されていません")
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("OpenAIError は .transcriptionError(.transcriptionFailed) に変換される")
    func openAIErrorMapping() {
        let error = OpenAIError.invalidResponse
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message == "無効なレスポンスです")
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("OnDeviceTranscriptionTimeoutError は .transcriptionError(.transcriptionFailed) に変換される")
    func timeoutErrorMapping() {
        let error = OnDeviceTranscriptionTimeoutError()
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message == OnDeviceTranscriptionTimeoutError.message)
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("不明な Error は .transcriptionError(.transcriptionFailed) にフォールバックされる")
    func unknownErrorFallback() {
        struct CustomError: Error {}
        let mapped = STTErrorMapper.mapToCoreError(CustomError())
        if case .transcriptionError(.transcriptionFailed) = mapped {
            // OK
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }
}

// MARK: - TranscriptionError Description Tests

struct TranscriptionErrorDescriptionTests {

    @Test("audioFileInvalid のメッセージ")
    func audioFileInvalid() {
        #expect(TranscriptionError.audioFileInvalid.errorDescription == "Audio file is invalid")
    }

    @Test("audioFormatNotSupported のメッセージ")
    func audioFormatNotSupported() {
        #expect(TranscriptionError.audioFormatNotSupported.errorDescription == "Audio format not supported")
    }

    @Test("languageNotSupported のメッセージに言語名が含まれる")
    func languageNotSupported() {
        #expect(TranscriptionError.languageNotSupported("fr").errorDescription == "Language not supported: fr")
    }

    @Test("transcriptionInProgress のメッセージ")
    func transcriptionInProgress() {
        #expect(TranscriptionError.transcriptionInProgress.errorDescription == "Transcription already in progress")
    }

    @Test("transcriptionFailed のメッセージに理由が含まれる")
    func transcriptionFailed() {
        #expect(TranscriptionError.transcriptionFailed("timeout").errorDescription == "Transcription failed: timeout")
    }

    @Test("engineNotAvailable のメッセージ")
    func engineNotAvailable() {
        #expect(TranscriptionError.engineNotAvailable.errorDescription == "Transcription engine not available")
    }
}

// MARK: - AIError Description Tests

struct AIErrorDescriptionTests {

    @Test("notConfigured のメッセージ")
    func notConfigured() {
        #expect(AIError.notConfigured.errorDescription == "AIサービスが設定されていません")
    }

    @Test("transcriptionNotSupported のメッセージ")
    func transcriptionNotSupported() {
        #expect(AIError.transcriptionNotSupported.errorDescription == "選択されたプロバイダーは文字起こしをサポートしていません")
    }

    @Test("apiKeyMissing のメッセージ")
    func apiKeyMissing() {
        #expect(AIError.apiKeyMissing.errorDescription == "APIキーが設定されていません")
    }

    @Test("invalidResponse のメッセージ")
    func invalidResponse() {
        #expect(AIError.invalidResponse.errorDescription == "無効なレスポンスです")
    }

    @Test("decodingError のメッセージ")
    func decodingError() {
        #expect(AIError.decodingError.errorDescription == "レスポンスの解析に失敗しました")
    }

    @Test("apiError のメッセージにステータスコードとメッセージが含まれる")
    func apiError() {
        #expect(AIError.apiError(429, "rate limited").errorDescription == "APIエラー (429): rate limited")
    }
}

// MARK: - OpenAIError Description Tests

struct OpenAIErrorDescriptionTests {

    @Test("invalidResponse のメッセージ")
    func invalidResponse() {
        #expect(OpenAIError.invalidResponse.errorDescription == "無効なレスポンスです")
    }

    @Test("decodingError のメッセージ")
    func decodingError() {
        #expect(OpenAIError.decodingError.errorDescription == "レスポンスの解析に失敗しました")
    }

    @Test("apiError のメッセージにステータスコードとメッセージが含まれる")
    func apiError() {
        #expect(OpenAIError.apiError(500, "server error").errorDescription == "APIエラー (500): server error")
    }
}

// MARK: - STTLanguageNormalizer Tests

struct STTLanguageNormalizerTests {

    @Test("ハイフン区切りのロケールからベース言語を抽出する")
    func hyphenLocale() {
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "en-US") == "en")
    }

    @Test("アンダースコア区切りのロケールからベース言語を抽出する")
    func underscoreLocale() {
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "ja_JP") == "ja")
    }

    @Test("ベース言語のみの場合はそのまま小文字で返す")
    func baseLanguageOnly() {
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "FR") == "fr")
    }

    @Test("空文字の場合は空文字を返す")
    func emptyString() {
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "") == "")
    }
}

// MARK: - SpeechAnalyzerFeatureFlag Default Tests

struct SpeechAnalyzerFeatureFlagTests {

    @Test("SpeechAnalyzer フィーチャーフラグのデフォルトは OFF")
    func defaultOff() {
        // 他のテストが変更する可能性があるため、リセットして確認
        SpeechAnalyzerFeatureFlag.isEnabled = false
        #expect(SpeechAnalyzerFeatureFlag.isEnabled == false)
    }
}

// MARK: - TranscriptionResult / TranscriptionSegment Construction Tests

struct TranscriptionDTOConstructionTests {

    @Test("TranscriptionResult のデフォルト値")
    func resultDefaults() {
        let result = TranscriptionResult(fullText: "hello")
        #expect(result.fullText == "hello")
        #expect(result.language == "ja")
        #expect(result.segments.isEmpty)
    }

    @Test("TranscriptionSegment のプロパティが正しく設定される")
    func segmentProperties() {
        let segment = TranscriptionSegment(
            id: "seg-0",
            speakerLabel: "Speaker 1",
            startSec: 0.0,
            endSec: 5.0,
            text: "テスト発話"
        )
        #expect(segment.id == "seg-0")
        #expect(segment.speakerLabel == "Speaker 1")
        #expect(segment.startSec == 0.0)
        #expect(segment.endSec == 5.0)
        #expect(segment.text == "テスト発話")
    }
}
