import Foundation
import Speech
import Testing
@testable import Memora

@Suite("STTService injected service dependencies", .serialized)
struct STTServiceDependencyInjectionTests {
    @Test("API文字起こしは注入されたRemoteTranscribingへ同じproviderとAPIキーを渡す")
    func apiTranscriptionUsesInjectedRemoteTranscriber() async throws {
        let sourceURL = try makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let remote = RecordingRemoteTranscriber(result: "remote transcript")
        let service = makeService(
            sourceURL: sourceURL,
            executionDependencies: makeExecutionDependencies(remote: remote)
        )
        service.updateConfiguration(
            apiKey: "test-api-key",
            provider: .gemini,
            transcriptionMode: .api
        )

        let (rawHandle, _) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        let handle = try #require(rawHandle as? STTTaskHandle)
        let result = try await handle.result()

        #expect(result.fullText == "remote transcript")
        #expect(remote.requests.map(\.providerIdentifier) == [AIProvider.gemini.rawValue])
        #expect(remote.requests.map(\.apiKey) == ["test-api-key"])
        #expect(remote.requests.map(\.audioURL) == [sourceURL])
    }

    @Test("話者分離は注入されたサービスをAPIモードで一度だけ呼ぶ")
    func apiTranscriptionUsesInjectedDiarizationService() async throws {
        let sourceURL = try makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let diarizer = RecordingDiarizationService()
        let executionDependencies = makeExecutionDependencies(
            remote: RecordingRemoteTranscriber(result: "speaker transcript"),
            diarizationService: diarizer
        )
        let service = makeService(
            sourceURL: sourceURL,
            dependencies: STTReadOnlyHostDependencies(
                logger: NoopSTTLogger(),
                consoleLogger: NoopSTTConsoleLogger(),
                settings: TestSTTSettings(
                    isSpeechAnalyzerEnabled: false,
                    isSpeakerDiarizationEnabled: true
                )
            ),
            executionDependencies: executionDependencies
        )
        service.updateConfiguration(apiKey: "test-api-key", provider: .openai, transcriptionMode: .api)

        let (rawHandle, _) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        let handle = try #require(rawHandle as? STTTaskHandle)
        let result = try await handle.result()

        #expect(diarizer.callCount == 1)
        #expect(result.segments.allSatisfy { $0.speakerLabel == "Injected Speaker" })
    }

    @Test("ローカル認識は注入されたfactory経由でSFSpeechRecognizerを生成する")
    func localTranscriptionUsesInjectedLocalBackendFactory() async throws {
        let sourceURL = try makeTemporarySourceFile()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let localFactory = RecordingLocalBackendFactory()
        let executionDependencies = STTServiceExecutionDependencies(
            backend: STTBackendExecutionDependencies(
                remoteTranscriber: RecordingRemoteTranscriber(result: "unused"),
                localBackendFactory: localFactory,
                speechAnalyzerPreflight: UnusedSpeechAnalyzerPreflight()
            ),
            diarizationService: RecordingDiarizationService()
        )
        let service = makeService(
            sourceURL: sourceURL,
            dependencies: STTReadOnlyHostDependencies(
                logger: NoopSTTLogger(),
                consoleLogger: NoopSTTConsoleLogger(),
                settings: TestSTTSettings(
                    isSpeechAnalyzerEnabled: false,
                    isSpeakerDiarizationEnabled: false
                )
            ),
            executionDependencies: executionDependencies
        )

        let (rawHandle, _) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        let handle = try #require(rawHandle as? STTTaskHandle)
        do {
            _ = try await handle.result()
            Issue.record("factory が返す認識器なしエラーが伝播する必要があります")
        } catch {
            #expect(localFactory.speechRecognizerLocales == ["ja_JP"])
        }
    }

    private func makeService(
        sourceURL: URL,
        dependencies: STTReadOnlyHostDependencies = STTReadOnlyHostDependencies(
            logger: NoopSTTLogger(),
            consoleLogger: NoopSTTConsoleLogger(),
            settings: TestSTTSettings(
                isSpeechAnalyzerEnabled: false,
                isSpeakerDiarizationEnabled: false
            )
        ),
        executionDependencies: STTServiceExecutionDependencies
    ) -> STTService {
        let chunker = FakeChunker(chunks: [
            AudioChunk(index: 0, startSec: 0, endSec: 1, url: sourceURL, isTemporary: false)
        ])
        return STTService(
            readiness: FakeReadiness(),
            chunkerFactory: { chunker },
            dependencies: dependencies,
            capabilities: .live,
            executionDependencies: executionDependencies
        )
    }

    private func makeExecutionDependencies(
        remote: RecordingRemoteTranscriber,
        diarizationService: any SpeakerDiarizationProtocol = RecordingDiarizationService()
    ) -> STTServiceExecutionDependencies {
        STTServiceExecutionDependencies(
            backend: STTBackendExecutionDependencies(
                remoteTranscriber: remote,
                localBackendFactory: RecordingLocalBackendFactory(),
                speechAnalyzerPreflight: UnusedSpeechAnalyzerPreflight()
            ),
            diarizationService: diarizationService
        )
    }

    private func makeTemporarySourceFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stt-dependency-injection-\(UUID().uuidString).m4a")
        try Data().write(to: url)
        return url
    }
}

private struct NoopSTTLogger: STTLogging {
    func log(_ category: String, _ message: String, level: STTLogLevel) {}
}

private struct NoopSTTConsoleLogger: STTConsoleLogging {
    func logDetailed(_ message: @autoclosure () -> String) {}
}

private struct UnusedSpeechAnalyzerPreflight: SpeechAnalyzerPreflighting {
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult {
        preconditionFailure("SpeechAnalyzer preflight is not used by this test")
    }

    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics {
        preconditionFailure("SpeechAnalyzer preflight is not used by this test")
    }
}

private struct TestSTTSettings: STTSettingsProviding {
    let isSpeechAnalyzerEnabled: Bool
    let isSpeakerDiarizationEnabled: Bool
    let contextualVocabulary: [String] = []
}

private final class RecordingRemoteTranscriber: RemoteTranscribing, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [RemoteTranscriptionRequest] = []
    private let result: String

    init(result: String) {
        self.result = result
    }

    var requests: [RemoteTranscriptionRequest] {
        lock.withLock { storage }
    }

    func transcribe(_ request: RemoteTranscriptionRequest) async throws -> String {
        lock.withLock { storage.append(request) }
        return result
    }
}

private final class RecordingDiarizationService: SpeakerDiarizationProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var callCount: Int {
        lock.withLock { storage }
    }

    func detectSpeakers(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int?
    ) async -> [TranscriptionSegment] {
        lock.withLock { storage += 1 }
        return segments.map {
            TranscriptionSegment(
                id: $0.id,
                speakerLabel: "Injected Speaker",
                startSec: $0.startSec,
                endSec: $0.endSec,
                text: $0.text,
                isEstimatedTiming: $0.isEstimatedTiming
            )
        }
    }
}

private final class RecordingLocalBackendFactory: LocalSTTBackendFactory, @unchecked Sendable {
    private let lock = NSLock()
    private var locales: [String] = []

    var speechRecognizerLocales: [String] {
        lock.withLock { locales }
    }

    @available(iOS 26.0, *)
    func makeSpeechAnalyzerTranscriber(locale: Locale) -> any SpeechAnalyzerTranscribing {
        UnusedSpeechAnalyzerTranscriber()
    }

    func makeSpeechRecognizer(locale: Locale) -> SFSpeechRecognizer? {
        lock.withLock { locales.append(locale.identifier) }
        return nil
    }
}

private struct UnusedSpeechAnalyzerTranscriber: SpeechAnalyzerTranscribing {
    func transcribe(audioURL: URL) async throws -> String {
        throw CancellationError()
    }
}
