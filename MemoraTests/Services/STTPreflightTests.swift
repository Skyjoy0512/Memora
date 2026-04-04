import Testing
import Foundation
@testable import Memora

struct STTPreflightTests {

    // MARK: - STTErrorMapper

    @Test("STTErrorMapper は CoreError をそのまま返す")
    func mapCoreErrorPassesThrough() {
        let original = CoreError.notFound(type: "AudioFile", id: UUID())
        let mapped = STTErrorMapper.mapToCoreError(original)
        #expect(mapped == original)
    }

    @Test("STTErrorMapper は TranscriptionError を .transcriptionError に変換する")
    func mapTranscriptionError() {
        let error = TranscriptionError.audioFileInvalid
        let mapped = STTErrorMapper.mapToCoreError(error)
        #expect(mapped == .transcriptionError(.audioFileInvalid))
    }

    @Test("STTErrorMapper は AudioChunkerError を .pipelineError に変換する")
    func mapAudioChunkerError() {
        let error = AudioChunkerError.fileNotFound
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .pipelineError(.transcriptionFailed(let message)) = mapped {
            #expect(message.contains("音声ファイルが見つかりません"))
        } else {
            Issue.record("Expected .pipelineError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("STTErrorMapper は AIError を .transcriptionError に変換する")
    func mapAIError() {
        let error = AIError.notConfigured
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message.contains("AIサービスが設定されていません"))
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("STTErrorMapper は OpenAIError を .transcriptionError に変換する")
    func mapOpenAIError() {
        let error = OpenAIError.decodingError
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message.contains("解析に失敗"))
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("STTErrorMapper は OnDeviceTranscriptionTimeoutError を .transcriptionError に変換する")
    func mapTimeoutError() {
        let error = OnDeviceTranscriptionTimeoutError()
        let mapped = STTErrorMapper.mapToCoreError(error)
        if case .transcriptionError(.transcriptionFailed(let message)) = mapped {
            #expect(message == OnDeviceTranscriptionTimeoutError.message)
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    @Test("STTErrorMapper は未知の Error を .transcriptionError にフォールバックする")
    func mapUnknownError() {
        struct CustomError: Error {}
        let mapped = STTErrorMapper.mapToCoreError(CustomError())
        if case .transcriptionError(.transcriptionFailed) = mapped {
            // OK
        } else {
            Issue.record("Expected .transcriptionError(.transcriptionFailed), got \(mapped)")
        }
    }

    // MARK: - LocalTranscriptionError

    @Test("LocalTranscriptionError.notSupported のエラーメッセージ")
    func localErrorNotSupported() {
        let error = LocalTranscriptionError.notSupported
        #expect(error.errorDescription == "ローカル文字起こしはサポートされていません")
    }

    @Test("LocalTranscriptionError.localeNotSupported のエラーメッセージ")
    func localErrorLocaleNotSupported() {
        let error = LocalTranscriptionError.localeNotSupported
        #expect(error.errorDescription == "この言語はサポートされていません")
    }

    @Test("LocalTranscriptionError.permissionDenied のエラーメッセージ")
    func localErrorPermissionDenied() {
        let error = LocalTranscriptionError.permissionDenied
        #expect(error.errorDescription == "音声認識の権限が許可されていません")
    }

    @Test("LocalTranscriptionError.assetInstallationFailed のエラーメッセージ")
    func localErrorAssetInstallationFailed() {
        let error = LocalTranscriptionError.assetInstallationFailed("テストエラー")
        #expect(error.errorDescription?.contains("テストエラー") == true)
        #expect(error.errorDescription?.contains("SpeechAnalyzer") == true)
    }

    @Test("LocalTranscriptionError.transcriptionFailed は内部エラーを含む")
    func localErrorTranscriptionFailed() {
        let inner = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "inner error"])
        let error = LocalTranscriptionError.transcriptionFailed(inner)
        #expect(error.errorDescription?.contains("inner error") == true)
        #expect(error.errorDescription?.contains("文字起こしに失敗") == true)
    }

    // MARK: - AIError

    @Test("AIError.notConfigured のエラーメッセージ")
    func aiErrorNotConfigured() {
        #expect(AIError.notConfigured.errorDescription == "AIサービスが設定されていません")
    }

    @Test("AIError.transcriptionNotSupported のエラーメッセージ")
    func aiErrorTranscriptionNotSupported() {
        #expect(AIError.transcriptionNotSupported.errorDescription?.contains("文字起こしをサポート") == true)
    }

    @Test("AIError.apiKeyMissing のエラーメッセージ")
    func aiErrorApiKeyMissing() {
        #expect(AIError.apiKeyMissing.errorDescription == "APIキーが設定されていません")
    }

    @Test("AIError.invalidResponse のエラーメッセージ")
    func aiErrorInvalidResponse() {
        #expect(AIError.invalidResponse.errorDescription == "無効なレスポンスです")
    }

    @Test("AIError.decodingError のエラーメッセージ")
    func aiErrorDecodingError() {
        #expect(AIError.decodingError.errorDescription == "レスポンスの解析に失敗しました")
    }

    @Test("AIError.apiError のエラーメッセージ")
    func aiErrorApiError() {
        let error = AIError.apiError(429, "rate limited")
        #expect(error.errorDescription?.contains("429") == true)
        #expect(error.errorDescription?.contains("rate limited") == true)
    }

    // MARK: - OpenAIError

    @Test("OpenAIError.invalidResponse のエラーメッセージ")
    func openAIErrorInvalidResponse() {
        #expect(OpenAIError.invalidResponse.errorDescription == "無効なレスポンスです")
    }

    @Test("OpenAIError.decodingError のエラーメッセージ")
    func openAIErrorDecodingError() {
        #expect(OpenAIError.decodingError.errorDescription == "レスポンスの解析に失敗しました")
    }

    @Test("OpenAIError.apiError のエラーメッセージ")
    func openAIErrorApiError() {
        let error = OpenAIError.apiError(500, "server error")
        #expect(error.errorDescription?.contains("500") == true)
        #expect(error.errorDescription?.contains("server error") == true)
    }

    // MARK: - SpeechAnalyzerFeatureFlag

    @Test("SpeechAnalyzerFeatureFlag.isEnabled のデフォルトは false")
    func featureFlagDefaultOff() {
        // UserDefaults のテスト用キーをリセット
        let key = "speechAnalyzerEnabled"
        let original = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.set(original, forKey: key) }

        #expect(SpeechAnalyzerFeatureFlag.isEnabled == false)
    }

    // MARK: - STTBackendType

    @Test("STTBackendType の rawValue が正しい")
    func sttBackendTypeRawValues() {
        #expect(STTBackendType.speechAnalyzer.rawValue == "SpeechAnalyzer")
        #expect(STTBackendType.sfSpeechRecognizer.rawValue == "SFSpeechRecognizer")
        #expect(STTBackendType.cloudAPI.rawValue == "CloudAPI")
    }

    // MARK: - STTBackendDiagnosticEntry

    @Test("STTBackendDiagnosticEntry の summary がフォーマットされる")
    func diagnosticEntrySummary() {
        let entry = STTBackendDiagnosticEntry(
            taskId: "task-1",
            backend: .speechAnalyzer,
            locale: "ja_JP",
            assetState: "installed",
            audioFormat: "pcm",
            fallbackReason: nil,
            processingTimeMs: 123.4,
            recordedAt: Date()
        )
        #expect(entry.summary.contains("SpeechAnalyzer"))
        #expect(entry.summary.contains("ja_JP"))
        #expect(entry.summary.contains("asset=installed"))
        #expect(entry.summary.contains("format=pcm"))
        #expect(entry.summary.contains("123.4ms"))
    }

    @Test("STTBackendDiagnosticEntry の id が一意")
    func diagnosticEntryId() {
        let entry1 = STTBackendDiagnosticEntry(
            taskId: "t1", backend: .cloudAPI, locale: "en",
            assetState: nil, audioFormat: nil, fallbackReason: nil,
            processingTimeMs: nil, recordedAt: Date(timeIntervalSince1970: 1000)
        )
        let entry2 = STTBackendDiagnosticEntry(
            taskId: "t1", backend: .cloudAPI, locale: "en",
            assetState: nil, audioFormat: nil, fallbackReason: nil,
            processingTimeMs: nil, recordedAt: Date(timeIntervalSince1970: 2000)
        )
        #expect(entry1.id != entry2.id)
    }

    // MARK: - STTLanguageNormalizer

    @Test("STTLanguageNormalizer はベース言語コードを抽出する")
    func languageNormalizer() {
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "ja_JP") == "ja")
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "en-US") == "en")
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "zh-Hans-CN") == "zh")
        #expect(STTLanguageNormalizer.baseLanguageCode(for: "fr") == "fr")
    }
}
