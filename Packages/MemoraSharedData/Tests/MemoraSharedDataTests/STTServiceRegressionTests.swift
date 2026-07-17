import Foundation
import Speech
import Testing
@testable import MemoraSharedCore

@Suite("STT service regression")
struct STTServiceRegressionTests {
    @Test("サービス経由でチャンクを入力順・絶対時刻のままマージする")
    func serviceMergesChunkResultsInPlanOrder() async throws {
        let sourceURL = try TestAudioFactory.makeToneThenSilenceWAV(toneSeconds: 0.1, silenceSeconds: 0.1)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let backend = IndexedBackend(results: [
            0: result(text: "最初", start: 1, end: 2),
            1: result(text: "次", start: 2, end: 4)
        ])
        let service = makeService(
            sourceURL: sourceURL,
            backend: backend,
            slices: [
                .init(index: 0, startSec: 0, endSec: 10),
                .init(index: 1, startSec: 10, endSec: 20)
            ]
        )

        let (handle, events) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        let result = try await taskResult(from: handle)

        #expect(result.fullText == "最初\n次")
        #expect(result.segments.map(\.startSec) == [1, 12])
        #expect(result.segments.map(\.endSec) == [2, 14])
        #expect(await backend.invokedIndexes() == [0, 1])

        var completedChunkIndexes: [Int] = []
        for await event in events {
            if case let .audioChunkCompleted(chunkIndex, _) = event {
                completedChunkIndexes.append(chunkIndex)
            }
        }
        #expect(completedChunkIndexes == [0, 1])
    }

    @Test("チェックポイント済みチャンクを復元して未完了チャンクだけを実行する")
    func serviceResumesFromCheckpoint() async throws {
        let sourceURL = try TestAudioFactory.makeSineWAV(seconds: 0.2)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let checkpoints = CheckpointProbe(restored: [0: CheckpointChunkResult(from: result(text: "復元済み", start: 0, end: 2))])
        let backend = IndexedBackend(results: [1: result(text: "再開した処理", start: 0, end: 3)])
        let service = makeService(
            sourceURL: sourceURL,
            backend: backend,
            slices: [
                .init(index: 0, startSec: 0, endSec: 10),
                .init(index: 1, startSec: 10, endSec: 20)
            ]
        )
        service.updateCheckpointHooks(await checkpoints.hooks())

        let (handle, _) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        let result = try await taskResult(from: handle)

        #expect(result.fullText == "復元済み\n再開した処理")
        #expect(result.segments.map(\.startSec) == [0, 10])
        #expect(await backend.invokedIndexes() == [1])
        #expect(await checkpoints.savedIndexes() == [1])
    }

    @Test("キャンセル時はバックエンドを中断して取消イベントを送る")
    func serviceCancelsInFlightTranscription() async throws {
        let sourceURL = try TestAudioFactory.makeSineWAV(seconds: 0.1)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = makeService(
            sourceURL: sourceURL,
            backend: BlockingBackend(),
            slices: [.init(index: 0, startSec: 0, endSec: 10)]
        )
        let (handle, events) = try await service.startTranscription(audioURL: sourceURL, language: "ja")
        await handle.cancel()

        do {
            _ = try await taskResult(from: handle)
            Issue.record("キャンセル済みタスクが成功しました")
        } catch is CancellationError {
            // 期待どおり
        }

        var didReceiveCancellation = false
        for await event in events {
            if case .transcriptionCancelled = event {
                didReceiveCancellation = true
            }
        }
        #expect(didReceiveCancellation)
    }

    @Test("話者分離がタイムアウトしたら元セグメントへ安全にフォールバックする")
    func postHocDiarizationTimesOutSafely() async throws {
        let sourceURL = try TestAudioFactory.makeSineWAV(seconds: 0.1)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = makeService(
            sourceURL: sourceURL,
            backend: IndexedBackend(results: [:]),
            slices: [.init(index: 0, startSec: 0, endSec: 1)],
            diarizer: BlockingDiarizer()
        )
        let segments = [TranscriptionSegment(id: "segment", speakerLabel: "", startSec: 0, endSec: 1, text: "確認")]
        let startedAt = Date()
        let actual = await service.detectSpeakersPostHoc(
            audioURL: sourceURL,
            segments: segments,
            timeout: 0.01
        )

        #expect(actual == segments)
        #expect(Date().timeIntervalSince(startedAt) < 1)
    }
}

private func result(text: String, start: Double, end: Double) -> TranscriptionResult {
    TranscriptionResult(
        fullText: text,
        language: "ja",
        segments: [TranscriptionSegment(id: text, speakerLabel: "Speaker 1", startSec: start, endSec: end, text: text)]
    )
}

private func taskResult(from handle: any STTTaskHandleProtocol) async throws -> TranscriptionResult {
    let task = try #require(handle as? STTTaskHandle)
    return try await task.result()
}

private func makeService(
    sourceURL: URL,
    backend: any STTBackendProcessing,
    slices: [AudioChunkPlan.Slice],
    diarizer: any SpeakerDiarizationProtocol = NoopDiarizer()
) -> STTService {
    let chunker = TestChunker(sourceURL: sourceURL, slices: slices)
    let dependencies = STTReadOnlyHostDependencies(
        logger: NoopLogger(),
        consoleLogger: NoopConsoleLogger(),
        settings: TestSettings(),
        diagnostics: NoopDiagnostics()
    )
    let executionDependencies = STTServiceExecutionDependencies(
        backend: STTBackendExecutionDependencies(
            remoteTranscriber: UnusedRemoteTranscriber(),
            localBackendFactory: UnusedLocalBackendFactory(),
            speechAnalyzerPreflight: UnusedSpeechAnalyzerPreflight()
        ),
        diarizationService: diarizer
    )
    let service = STTService(
        readiness: TestReadiness(),
        chunkerFactory: { chunker },
        backendFactory: { _, _ in backend },
        dependencies: dependencies,
        capabilities: .init(
            backgroundTasks: NoopBackgroundTasks(),
            idleTimer: NoopIdleTimer(),
            memoryWarnings: NoopMemoryWarnings(),
            progress: NoopProgressPresenter()
        ),
        executionDependencies: executionDependencies
    )
    service.updateConfiguration(apiKey: "test-key", provider: .openai, transcriptionMode: .api)
    return service
}

private struct TestChunker: AudioChunkerProtocol {
    let sourceURL: URL
    let slices: [AudioChunkPlan.Slice]

    func analyzeAndChunk(fileURL: URL, onProgress: AudioChunkProgressHandler?) async throws -> [AudioChunk] {
        try await slices.asyncMap { try await exportSlice($0, from: try await plan(fileURL: fileURL)) }
    }

    func plan(fileURL: URL) async throws -> AudioChunkPlan {
        AudioChunkPlan(sourceURL: sourceURL, totalDuration: slices.last?.endSec ?? 0, slices: slices)
    }

    func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk {
        AudioChunk(
            index: slice.index,
            startSec: slice.startSec,
            endSec: slice.endSec,
            url: sourceURL.deletingPathExtension().appendingPathExtension("chunk-\(slice.index).wav"),
            isTemporary: true
        )
    }

    func cleanup(chunks: [AudioChunk]) async {}
    func cleanupChunk(_ chunk: AudioChunk) async {}
}

private actor IndexedBackend: STTBackendProcessing {
    private let results: [Int: TranscriptionResult]
    private var indexes: [Int] = []

    init(results: [Int: TranscriptionResult]) { self.results = results }

    func transcribe(audioURL: URL, language: String?, progress: @escaping @Sendable (Double) -> Void, partialResult: @escaping @Sendable (String) -> Void) async throws -> TranscriptionResult {
        let index = Int(audioURL.deletingPathExtension().lastPathComponent.split(separator: "-").last ?? "") ?? -1
        indexes.append(index)
        progress(1)
        let result = results[index] ?? TranscriptionResult(fullText: "")
        partialResult(result.fullText)
        return result
    }

    func invokedIndexes() -> [Int] { indexes }
}

private actor BlockingBackend: STTBackendProcessing {
    func transcribe(audioURL: URL, language: String?, progress: @escaping @Sendable (Double) -> Void, partialResult: @escaping @Sendable (String) -> Void) async throws -> TranscriptionResult {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return TranscriptionResult(fullText: "完了してはいけません")
    }
}

private actor CheckpointProbe {
    private let restored: [Int: CheckpointChunkResult]
    private var saved: [Int] = []

    init(restored: [Int: CheckpointChunkResult]) { self.restored = restored }

    func hooks() -> STTCheckpointHooks {
        STTCheckpointHooks(
            load: { _ in await self.restoredResults() },
            save: { _, _, index, _ in await self.save(index) },
            clear: {}
        )
    }

    func restoredResults() -> [Int: CheckpointChunkResult] { restored }
    func save(_ index: Int) { saved.append(index) }
    func savedIndexes() -> [Int] { saved }
}

private actor BlockingDiarizer: SpeakerDiarizationProtocol {
    func detectSpeakers(audioURL: URL, segments: [TranscriptionSegment], numSpeakers: Int?) async -> [TranscriptionSegment] {
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        } catch {
            return []
        }
        return []
    }
}

private struct NoopDiarizer: SpeakerDiarizationProtocol {
    func detectSpeakers(audioURL: URL, segments: [TranscriptionSegment], numSpeakers: Int?) async -> [TranscriptionSegment] { segments }
}

private struct TestReadiness: STTReadinessProtocol {
    var isReady: Bool { get async { true } }
    var supportedLanguages: [String] { get async { ["ja"] } }
    var requiresDownload: Bool { get async { false } }
    func prepare() async throws {}
}

private struct TestSettings: STTSettingsProviding {
    let isSpeechAnalyzerEnabled = false
    let isSpeakerDiarizationEnabled = false
    let contextualVocabulary: [String] = []
}

private struct NoopLogger: STTLogging { func log(_ category: String, _ message: String, level: STTLogLevel) {} }
private struct NoopConsoleLogger: STTConsoleLogging { func logDetailed(_ message: @autoclosure () -> String) {} }
private struct NoopDiagnostics: STTDiagnosticsRecording { func record(_ entry: STTBackendDiagnosticEntry) {} }
private struct NoopBackgroundTasks: STTBackgroundTaskManaging {
    @MainActor func beginBackgroundTask(named name: String, expirationHandler: @escaping @Sendable () -> Void) -> STTBackgroundTaskToken? { nil }
    @MainActor func endBackgroundTask(_ token: STTBackgroundTaskToken) {}
}
private struct NoopIdleTimer: STTIdleTimerManaging { @MainActor func setIdleTimerDisabled(_ isDisabled: Bool) {} }
private struct NoopMemoryWarnings: STTMemoryWarningObserving { func observeMemoryWarnings(_ handler: @escaping @Sendable () -> Void) {} }
private struct NoopProgressPresenter: STTProgressPresenting {
    @MainActor func start(fileName: String, totalChunks: Int) {}
    @MainActor func update(progress: Double, currentChunk: Int, totalChunks: Int) {}
    @MainActor func finish(success: Bool, characterCount: Int) {}
}

private struct UnusedRemoteTranscriber: RemoteTranscribing { func transcribe(_ request: RemoteTranscriptionRequest) async throws -> String { "" } }
private struct UnusedLocalBackendFactory: LocalSTTBackendFactory {
    @available(iOS 26.0, *) func makeSpeechAnalyzerTranscriber(locale: Locale) -> any SpeechAnalyzerTranscribing { UnusedSpeechAnalyzerTranscriber() }
    func makeSpeechRecognizer(locale: Locale) -> SFSpeechRecognizer? { nil }
}
private struct UnusedSpeechAnalyzerTranscriber: SpeechAnalyzerTranscribing { func transcribe(audioURL: URL) async throws -> String { "" } }
private struct UnusedSpeechAnalyzerPreflight: SpeechAnalyzerPreflighting {
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult { .unavailable(reason: .featureFlagOff, diagnostics: await diagnostics(for: locale)) }
    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics {
        SpeechAnalyzerDiagnostics(isTranscriberAvailable: false, featureFlagEnabled: false, requestedLocale: locale.identifier, supportedLocale: nil, assetStatus: "unused", compatibleFormatsDescription: "unused", unavailableReason: .featureFlagOff, checkedAt: .now, checkDurationMs: 0)
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for element in self { values.append(try await transform(element)) }
        return values
    }
}
