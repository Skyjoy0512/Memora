import Foundation
@preconcurrency import Speech

/// API 文字起こしをホスト実装へ委譲するための、共有可能な入力値。
public struct RemoteTranscriptionRequest: Sendable {
    public let audioURL: URL
    public let providerIdentifier: String
    public let apiKey: String

    public init(audioURL: URL, providerIdentifier: String, apiKey: String) {
        self.audioURL = audioURL
        self.providerIdentifier = providerIdentifier
        self.apiKey = apiKey
    }
}

/// API 文字起こしのホスト境界。API キーは呼び出し時の値としてのみ渡す。
public protocol RemoteTranscribing: Sendable {
    func transcribe(_ request: RemoteTranscriptionRequest) async throws -> String
}

/// SpeechAnalyzer の実装をホスト側に保ったまま使うための最小契約。
public protocol SpeechAnalyzerTranscribing {
    func transcribe(audioURL: URL) async throws -> String
}

/// ローカル認識バックエンドを生成するホスト境界。
/// 選択順は呼び出し側が保持し、この契約は実装の生成だけを担う。
public protocol LocalSTTBackendFactory: Sendable {
    @available(iOS 26.0, *)
    func makeSpeechAnalyzerTranscriber(locale: Locale) -> any SpeechAnalyzerTranscribing

    func makeSpeechRecognizer(locale: Locale) -> SFSpeechRecognizer?
}

/// STTBackendExecutor が必要とする、Sendable な実行バックエンド依存。
public struct STTBackendExecutionDependencies: Sendable {
    public let remoteTranscriber: any RemoteTranscribing
    public let localBackendFactory: any LocalSTTBackendFactory
    public let speechAnalyzerPreflight: any SpeechAnalyzerPreflighting

    public init(
        remoteTranscriber: any RemoteTranscribing,
        localBackendFactory: any LocalSTTBackendFactory,
        speechAnalyzerPreflight: any SpeechAnalyzerPreflighting
    ) {
        self.remoteTranscriber = remoteTranscriber
        self.localBackendFactory = localBackendFactory
        self.speechAnalyzerPreflight = speechAnalyzerPreflight
    }
}

/// 話者分離の共有契約。実装選択はホストの `.live` に残す。
public protocol SpeakerDiarizationProtocol {
    func detectSpeakers(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int?
    ) async -> [TranscriptionSegment]
}

/// STTService へ注入する3つの実行サービス依存。
/// `.live` 実装はホスト側で提供し、共有コアは具体サービスを知らない。
public struct STTServiceExecutionDependencies {
    public let backend: STTBackendExecutionDependencies
    public let diarizationService: any SpeakerDiarizationProtocol

    public init(
        backend: STTBackendExecutionDependencies,
        diarizationService: any SpeakerDiarizationProtocol
    ) {
        self.backend = backend
        self.diarizationService = diarizationService
    }
}
