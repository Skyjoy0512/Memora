import Foundation
import Speech

// 現行の具体サービス生成を保持するホスト側 `.live` 実装。
// 共有コアはこれらの型を直接参照しない。
@available(iOS 26.0, *)
extension SpeechAnalyzerService26: SpeechAnalyzerTranscribing {}

struct AIServiceRemoteTranscriber: RemoteTranscribing {
    let dependencies: STTReadOnlyHostDependencies

    func transcribe(_ request: RemoteTranscriptionRequest) async throws -> String {
        let service = AIService(dependencies: dependencies)
        switch request.providerIdentifier {
        case AIProvider.openai.rawValue:
            service.setProvider(.openai)
        case AIProvider.gemini.rawValue:
            service.setProvider(.gemini)
        case AIProvider.deepseek.rawValue:
            service.setProvider(.deepseek)
        case AIProvider.local.rawValue:
            service.setProvider(.local)
        default:
            preconditionFailure("Unsupported AI provider identifier: \(request.providerIdentifier)")
        }
        service.setTranscriptionMode(.api)
        try await service.configure(apiKey: request.apiKey)
        return try await service.transcribe(audioURL: request.audioURL)
    }
}

struct LiveLocalSTTBackendFactory: LocalSTTBackendFactory {
    @available(iOS 26.0, *)
    func makeSpeechAnalyzerTranscriber(locale: Locale) -> any SpeechAnalyzerTranscribing {
        SpeechAnalyzerService26(locale: locale)
    }

    func makeSpeechRecognizer(locale: Locale) -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: locale)
    }
}

/// `STTBackendExecutor` は iOS 26 availability check の内側でのみ preflight を呼ぶ。
/// 依存コンテナ自体は iOS 17 から組み立てられるため、この薄い host adapter だけが
/// availability 境界を保持する。
struct LiveSpeechAnalyzerPreflight: SpeechAnalyzerPreflighting {
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult {
        guard #available(iOS 26.0, *) else {
            preconditionFailure("SpeechAnalyzer preflight must only run on iOS 26 or later")
        }
        return await SpeechAnalyzerPreflight().run(locale: locale)
    }

    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics {
        guard #available(iOS 26.0, *) else {
            preconditionFailure("SpeechAnalyzer preflight must only run on iOS 26 or later")
        }
        return await SpeechAnalyzerPreflight().diagnostics(for: locale)
    }
}

extension STTServiceExecutionDependencies {
    static func live(
        dependencies: STTReadOnlyHostDependencies = .live
    ) -> STTServiceExecutionDependencies {
        STTServiceExecutionDependencies(
            backend: STTBackendExecutionDependencies(
                remoteTranscriber: AIServiceRemoteTranscriber(
                    dependencies: dependencies
                ),
                localBackendFactory: LiveLocalSTTBackendFactory(),
                speechAnalyzerPreflight: LiveSpeechAnalyzerPreflight()
            ),
            diarizationService: {
                if #available(macOS 14.0, iOS 17.0, *) {
                    return FluidAudioDiarizationService()
                } else {
                    return SpeakerDiarizationService()
                }
            }()
        )
    }
}
