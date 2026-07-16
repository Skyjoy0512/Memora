import Foundation
@preconcurrency import AVFoundation
import Speech

// Core transcription boundary. Changes require explicit STT approval and regression checks.

/// Callback API と Swift Concurrency の境界で continuation を厳密に1回だけ完了させる。
/// ロック操作は同期メソッド内に閉じ込め、async コンテキストで NSLock を直接扱わない。
private final class STTContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var pendingError: Error?
    private var isFinished = false
    private var cancelUnderlying: (@Sendable () -> Void)?
    private var timeoutTask: Task<Void, Never>?

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        let pendingError: Error? = lock.withLock {
            if isFinished {
                return self.pendingError ?? CancellationError()
            }
            self.continuation = continuation
            return nil
        }
        if let pendingError {
            continuation.resume(throwing: pendingError)
        }
    }

    func installCancellation(_ action: @escaping @Sendable () -> Void) {
        let shouldCancel = lock.withLock {
            if isFinished { return true }
            cancelUnderlying = action
            return false
        }
        if shouldCancel { action() }
    }

    func installTimeoutTask(_ task: Task<Void, Never>) {
        let shouldCancel = lock.withLock {
            if isFinished { return true }
            timeoutTask = task
            return false
        }
        if shouldCancel { task.cancel() }
    }

    var hasFinished: Bool {
        lock.withLock { isFinished }
    }

    func resume(returning value: Value) {
        let completion: (CheckedContinuation<Value, Error>?, Task<Void, Never>?) = lock.withLock {
            guard !isFinished else { return (nil, nil) }
            isFinished = true
            let continuation = self.continuation
            let timeoutTask = self.timeoutTask
            self.continuation = nil
            self.cancelUnderlying = nil
            self.timeoutTask = nil
            return (continuation, timeoutTask)
        }
        completion.1?.cancel()
        completion.0?.resume(returning: value)
    }

    func resume(throwing error: Error, cancellingUnderlying: Bool = false) {
        let completion: (
            continuation: CheckedContinuation<Value, Error>?,
            cancellation: (@Sendable () -> Void)?,
            timeoutTask: Task<Void, Never>?
        ) = lock.withLock {
            guard !isFinished else { return (nil, nil, nil) }
            isFinished = true
            pendingError = error
            let continuation = self.continuation
            let cancellation = cancellingUnderlying ? cancelUnderlying : nil
            let timeoutTask = self.timeoutTask
            self.continuation = nil
            self.cancelUnderlying = nil
            self.timeoutTask = nil
            return (continuation, cancellation, timeoutTask)
        }
        completion.timeoutTask?.cancel()
        completion.cancellation?()
        completion.continuation?.resume(throwing: error)
    }
}

private func withSTTTimeout<Value: Sendable, TimeoutFailure: Error & Sendable>(
    seconds: TimeInterval,
    timeoutError: TimeoutFailure,
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    let gate = STTContinuationGate<Value>()
    return try await withTaskCancellationHandler {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)

            let work = Task {
                do {
                    gate.resume(returning: try await operation())
                } catch {
                    gate.resume(throwing: error)
                }
            }
            gate.installCancellation { work.cancel() }

            let timeoutNanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                } catch {
                    return
                }
                gate.resume(throwing: timeoutError, cancellingUnderlying: true)
            }
            gate.installTimeoutTask(timeoutTask)
        }
    } onCancel: {
        gate.resume(throwing: CancellationError(), cancellingUnderlying: true)
    }
}

private struct STTOperationTimeoutError: Error, Sendable {}

public final class STTTaskHandle: STTTaskHandleProtocol, @unchecked Sendable {
    public let id: String
    public var taskId: String { id }
    public let audioURL: URL
    public let language: String?
    private let consoleLogger: any STTConsoleLogging

    private let lock = NSLock()
    private let streamStorage: AsyncStream<STTEvent>
    private var continuation: AsyncStream<STTEvent>.Continuation?
    private var resultTask: Task<TranscriptionResult, Error>?
    private var running = true

    deinit {
        let stillRunning: Bool
        lock.lock()
        stillRunning = running
        lock.unlock()
        if stillRunning {
            consoleLogger.logDetailed("[MemoraSTT] STTTaskHandle.deinit — ⚠️ まだ running=true のまま解放: taskId=\(taskId), url=\(audioURL.lastPathComponent)")
        } else {
            consoleLogger.logDetailed("[MemoraSTT] STTTaskHandle.deinit — 正常解放: taskId=\(taskId)")
        }
    }

    init(audioURL: URL, language: String?, consoleLogger: any STTConsoleLogging) {
        self.id = UUID().uuidString
        self.audioURL = audioURL
        self.language = language
        self.consoleLogger = consoleLogger

        var storedContinuation: AsyncStream<STTEvent>.Continuation?
        // .unbounded バッファリングでイベントドロップを防止
        self.streamStorage = AsyncStream(
            bufferingPolicy: .unbounded
        ) { continuation in
            storedContinuation = continuation
        }
        self.continuation = storedContinuation
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    var events: AsyncStream<STTEvent> {
        streamStorage
    }

    func attach(task: Task<TranscriptionResult, Error>) {
        lock.lock()
        resultTask = task
        lock.unlock()
    }

    func yield(_ event: STTEvent) {
        lock.lock()
        let continuation = continuation
        lock.unlock()
        continuation?.yield(event)
    }

    func finish() {
        lock.lock()
        running = false
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.finish()
    }

    public func result() async throws -> TranscriptionResult {
        let task = currentTask()

        guard let task else {
            throw CoreError.transcriptionError(.transcriptionFailed("Task result is unavailable"))
        }
        return try await task.value
    }

    public func cancel() async {
        let task = markCancelledAndGetTask()
        task?.cancel()
    }

    private func currentTask() -> Task<TranscriptionResult, Error>? {
        lock.lock()
        let task = resultTask
        lock.unlock()
        return task
    }

    private func markCancelledAndGetTask() -> Task<TranscriptionResult, Error>? {
        lock.lock()
        let task = resultTask
        running = false
        lock.unlock()
        return task
    }
}

public final class STTReadiness: STTReadinessProtocol, @unchecked Sendable {
    private let preferredLocale = Locale(identifier: "ja_JP")

    public init() {}

    public var isReady: Bool {
        get async {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                return false
            }
            guard let recognizer = SFSpeechRecognizer(locale: preferredLocale) else {
                return false
            }
            return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
        }
    }

    public var supportedLanguages: [String] {
        get async {
            let languages = SFSpeechRecognizer.supportedLocales().compactMap { locale -> String? in
                guard SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true else {
                    return nil
                }
                return STTLanguageNormalizer.baseLanguageCode(for: locale.identifier)
            }
            return Array(Set(languages)).sorted()
        }
    }

    public var requiresDownload: Bool {
        get async { false }
    }

    public func prepare() async throws {
        let granted = await requestSpeechPermissionIfNeeded()
        guard granted else {
            throw CoreError.transcriptionError(.transcriptionFailed("Speech permission denied"))
        }
    }

    private func requestSpeechPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

public protocol STTBackendProcessing: Sendable {
    func transcribe(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult
}

private final class STTBackendExecutor: STTBackendProcessing, @unchecked Sendable {
    private let taskId: String
    private let configuration: STTExecutionConfiguration
    private let dependencies: STTReadOnlyHostDependencies
    private let executionDependencies: STTBackendExecutionDependencies

    init(
        taskId: String,
        configuration: STTExecutionConfiguration,
        dependencies: STTReadOnlyHostDependencies,
        executionDependencies: STTBackendExecutionDependencies
    ) {
        self.taskId = taskId
        self.configuration = configuration
        self.dependencies = dependencies
        self.executionDependencies = executionDependencies
    }


    func transcribe(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CoreError.transcriptionError(.audioFileInvalid)
        }

        switch configuration.transcriptionMode {
        case .local:
            return try await transcribeLocally(
                audioURL: audioURL,
                language: language,
                progress: progress,
                partialResult: partialResult
            )
        case .api:
            return try await transcribeRemotely(
                audioURL: audioURL,
                language: language,
                progress: progress
            )
        }
    }

    private func transcribeLocally(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        let locale = localeForRecognition(language: language)
        let transcriptionStart = ContinuousClock.now
        dependencies.logger.log("STTBackend", "transcribeLocally 開始 — locale: \(locale.identifier), file: \(audioURL.lastPathComponent)", level: .info)

        // SpeechAnalyzer (iOS 26) を優先使用。
        // 高レベルAPI analyzeSequence(from:) で MP3/M4A を直接処理。
        // 失敗時は SFSpeechRecognizer にフォールバック。
        #if !targetEnvironment(simulator)
        if configuration.allowsSpeechAnalyzer {
            if #available(iOS 26.0, *) {
            let result = await executionDependencies.speechAnalyzerPreflight.run(locale: locale)

            switch result {
            case .ready(let diag):
                dependencies.logger.log("STTBackend", "SpeechAnalyzer preflight passed — \(diag.summary)", level: .info)
                do {
                    let transcription = try await transcribeWithSpeechAnalyzerWithTimeout(
                        audioURL: audioURL,
                        locale: locale,
                        progress: progress,
                        partialResult: partialResult
                    )
                    let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
                    let ms = DurationFormatter.milliseconds(elapsed)
                    dependencies.diagnostics.record(STTBackendDiagnosticEntry(
                        taskId: taskId,
                        backend: .speechAnalyzer,
                        locale: locale.identifier,
                        assetState: diag.assetStatus,
                        audioFormat: diag.compatibleFormatsDescription,
                        fallbackReason: nil,
                        processingTimeMs: ms,
                        recordedAt: Date()
                    ))
                    return transcription
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    dependencies.logger.log("STTBackend", "SpeechAnalyzer runtime fallback: \(error.localizedDescription)", level: .warning)
                    dependencies.diagnostics.record(STTBackendDiagnosticEntry(
                        taskId: taskId,
                        backend: .speechAnalyzer,
                        locale: locale.identifier,
                        assetState: diag.assetStatus,
                        audioFormat: nil,
                        fallbackReason: "runtime error: \(error.localizedDescription)",
                        processingTimeMs: nil,
                        recordedAt: Date()
                    ))
                }

            case .unavailable(let reason, let diag):
                dependencies.logger.log("STTBackend", "SpeechAnalyzer preflight failed — \(reason.description)", level: .warning)
                dependencies.diagnostics.record(STTBackendDiagnosticEntry(
                    taskId: taskId,
                    backend: .sfSpeechRecognizer,
                    locale: locale.identifier,
                    assetState: diag.assetStatus,
                    audioFormat: nil,
                    fallbackReason: reason.description,
                    processingTimeMs: nil,
                    recordedAt: Date()
                ))
            }
            }
        }
        #endif

        try Task.checkCancellation()
        dependencies.consoleLogger.logDetailed("[MemoraSTT] SFSpeechRecognizer パスを使用（on-device only）")
        dependencies.logger.log("STTBackend", "SFSpeechRecognizer パス開始 — on-device only", level: .info)

        let transcription = try await transcribeWithSpeechRecognizerWithTimeout(
            audioURL: audioURL,
            locale: locale,
            progress: progress,
            partialResult: partialResult
        )

        // SFSpeechRecognizer は無音区間や低品質区間で早期に isFinal=true を
        // 返すことがあるため、セグメントカバレッジをチェックする。
        let chunkDuration = await audioFileDuration(for: audioURL)
        let lastEnd = transcription.segments.last?.endSec ?? 0
        let coverage = chunkDuration > 1.0 ? lastEnd / chunkDuration : 1.0
        if coverage < 0.8 {
            let tailRMS = AudioSilenceProbe.averageRMS(
                url: audioURL,
                startSec: lastEnd,
                endSec: chunkDuration
            )
            let silenceThreshold: Float = 0.008
            if let tailRMS, tailRMS < silenceThreshold {
                dependencies.logger.log(
                    "STTBackend",
                    "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) だが末尾は無音 (RMS=\(String(format: "%.4f", tailRMS)))",
                    level: .info
                )
            } else {
                dependencies.logger.log(
                    "STTBackend",
                    "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) — ローカル専用のため外部認識へ送信せず失敗扱い",
                    level: .warning
                )
                throw OnDeviceTranscriptionTimeoutError()
            }
        }

        let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
        let ms = DurationFormatter.milliseconds(elapsed)
        dependencies.diagnostics.record(STTBackendDiagnosticEntry(
            taskId: taskId,
            backend: .sfSpeechRecognizer,
            locale: locale.identifier,
            assetState: nil,
            audioFormat: nil,
            fallbackReason: nil,
            processingTimeMs: ms,
            recordedAt: Date()
        ))
        return transcription
    }

    private func transcribeWithSpeechRecognizer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        guard let recognizer = executionDependencies.localBackendFactory.makeSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            dependencies.consoleLogger.logDetailed("[MemoraSTT] SFSpeechRecognizer 利用不可 — locale: \(locale.identifier)")
            throw CoreError.transcriptionError(.engineNotAvailable)
        }
        guard recognizer.supportsOnDeviceRecognition else {
            dependencies.logger.log(
                "STTBackend",
                "オンデバイス認識非対応 — locale: \(locale.identifier)",
                level: .warning
            )
            throw CoreError.transcriptionError(.languageNotSupported(locale.identifier))
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.contextualStrings = dependencies.settings.contextualVocabulary
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        dependencies.consoleLogger.logDetailed("[MemoraSTT] SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: true")
        dependencies.logger.log("STTBackend", "SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: true", level: .info)
        progress(0.2)

        let timeoutSeconds: TimeInterval = 30
        let gate = STTContinuationGate<SFSpeechRecognitionResult>()
        let recognitionResult = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)

                let task = recognizer.recognitionTask(with: request) { result, error in
                    guard !gate.hasFinished else { return }
                    if let error {
                        gate.resume(throwing: error)
                        return
                    }
                    guard let result else { return }
                    if result.isFinal {
                        gate.resume(returning: result)
                    } else {
                        partialResult(result.bestTranscription.formattedString)
                    }
                }
                gate.installCancellation { task.cancel() }

                let timeoutTask = Task {
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(timeoutSeconds * 1_000_000_000)
                        )
                    } catch {
                        return
                    }
                    dependencies.consoleLogger.logDetailed("[MemoraSTT] SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: true")
                    dependencies.logger.log(
                        "STTBackend",
                        "SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: true",
                        level: .warning
                    )
                    gate.resume(
                        throwing: OnDeviceTranscriptionTimeoutError(),
                        cancellingUnderlying: true
                    )
                }
                gate.installTimeoutTask(timeoutTask)
            }
        } onCancel: {
            gate.resume(throwing: CancellationError(), cancellingUnderlying: true)
        }

        progress(0.92)
        dependencies.logger.log("STTBackend", "SFSpeechRecognizer 認識完了 — \(recognitionResult.bestTranscription.segments.count)セグメント", level: .info)

        let baseSegments = recognitionResult.bestTranscription.segments.enumerated().map { index, segment in
            TranscriptionSegment(
                id: "segment-\(index)",
                speakerLabel: "Speaker 1",
                startSec: segment.timestamp,
                endSec: segment.timestamp + segment.duration,
                text: segment.substring
            )
        }

        // 話者分離はチャンク単位ではなく、マージ後に全体ファイルで一括実行するため
        // ここではセグメントをそのまま返す

        return TranscriptionResult(
            fullText: recognitionResult.bestTranscription.formattedString,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: baseSegments
        )
    }

    /// SFSpeechRecognizer に60秒タイムアウトを追加したラッパー。
    /// コールバックが永久に返らない iOS バグを防止する。
    private func transcribeWithSpeechRecognizerWithTimeout(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await transcribeWithSpeechRecognizer(
            audioURL: audioURL,
            locale: locale,
            progress: progress,
            partialResult: partialResult
        )
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzerWithTimeout(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        do {
            return try await withSTTTimeout(
                seconds: 60,
                timeoutError: OnDeviceTranscriptionTimeoutError()
            ) {
                try await self.transcribeWithSpeechAnalyzer(
                    audioURL: audioURL,
                    locale: locale,
                    progress: progress,
                    partialResult: partialResult
                )
            }
        } catch is OnDeviceTranscriptionTimeoutError {
            dependencies.logger.log("STTBackend", "SpeechAnalyzer 60秒タイムアウト", level: .warning)
            throw OnDeviceTranscriptionTimeoutError()
        }
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        dependencies.consoleLogger.logDetailed("[MemoraSTT] transcribeWithSpeechAnalyzer 開始")
        dependencies.logger.log("STTBackend", "SpeechAnalyzer transcribe 開始 — \(audioURL.lastPathComponent)", level: .info)
        let service = executionDependencies.localBackendFactory.makeSpeechAnalyzerTranscriber(locale: locale)

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        dependencies.consoleLogger.logDetailed("[MemoraSTT] transcribeWithSpeechAnalyzer: SpeechAnalyzerService26 完了 — \(text.count)文字")
        dependencies.logger.log("STTBackend", "SpeechAnalyzer transcribe 完了 — \(text.count)文字", level: .info)
        partialResult(text)
        progress(0.92)

        let duration = await audioFileDuration(for: audioURL)
        dependencies.consoleLogger.logDetailed("[MemoraSTT] transcribeWithSpeechAnalyzer: duration=\(duration)s")
        dependencies.logger.log("STTBackend", "SpeechAnalyzer duration=\(String(format: "%.1f", duration))s, セグメント生成完了", level: .info)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)

        let result = TranscriptionResult(
            fullText: text,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: baseSegments
        )
        dependencies.consoleLogger.logDetailed("[MemoraSTT] transcribeWithSpeechAnalyzer: TranscriptionResult 生成完了")
        return result
    }

    private func transcribeRemotely(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard !configuration.apiKey.isEmpty else {
            throw CoreError.transcriptionError(.transcriptionFailed("API key is missing"))
        }

        dependencies.consoleLogger.logDetailed("[MemoraSTT] API パス開始 — provider: \(configuration.provider.rawValue)")
        dependencies.logger.log("STTBackend", "API パス開始 — provider: \(configuration.provider.rawValue)", level: .info)
        let remoteStart = ContinuousClock.now

        progress(0.2)
        let text = try await executionDependencies.remoteTranscriber.transcribe(
            RemoteTranscriptionRequest(
                audioURL: audioURL,
                providerIdentifier: configuration.provider.rawValue,
                apiKey: configuration.apiKey
            )
        )
        progress(0.92)

        dependencies.consoleLogger.logDetailed("[MemoraSTT] API パス完了 — text length: \(text.count)")
        dependencies.logger.log("STTBackend", "API パス完了 — \(text.count)文字", level: .info)

        let duration = await audioFileDuration(for: audioURL)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)

        let elapsed = remoteStart.duration(to: ContinuousClock.now)
        let ms = DurationFormatter.milliseconds(elapsed)
        dependencies.diagnostics.record(STTBackendDiagnosticEntry(
            taskId: taskId,
            backend: .cloudAPI,
            locale: language ?? "unknown",
            assetState: nil,
            audioFormat: nil,
            fallbackReason: nil,
            processingTimeMs: ms,
            recordedAt: Date()
        ))

        return TranscriptionResult(
            fullText: text,
            language: language.map(STTLanguageNormalizer.baseLanguageCode(for:)) ?? "ja",
            segments: baseSegments
        )
    }

    private func makeFallbackSegments(
        from text: String,
        duration: TimeInterval
    ) -> [TranscriptionSegment] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        let segmentDuration = duration > 0 ? duration / Double(lines.count) : 0
        return lines.enumerated().map { index, line in
            let start = Double(index) * segmentDuration
            let end = duration > 0 ? min(start + segmentDuration, duration) : start
            return TranscriptionSegment(
                id: "segment-\(index)",
                speakerLabel: "Speaker 1",
                startSec: start,
                endSec: end,
                text: line,
                isEstimatedTiming: true
            )
        }
    }

    private func localeForRecognition(language: String?) -> Locale {
        guard let language, !language.isEmpty else {
            return Locale(identifier: "ja_JP")
        }

        let normalized = language.replacingOccurrences(of: "-", with: "_")
        if normalized.contains("_") {
            return Locale(identifier: normalized)
        }

        switch normalized.lowercased() {
        case "ja":
            return Locale(identifier: "ja_JP")
        case "en":
            return Locale(identifier: "en_US")
        default:
            return Locale(identifier: normalized)
        }
    }

    private func audioFileDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }

}

public final class STTService: STTServiceProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private let configurationLock = NSLock()

    private let postProcessor = TranscriptPostProcessor()
    private var activeTasks: [String: STTTaskHandle] = [:]
    private var configuration = STTExecutionConfiguration.localDefault
    private var backgroundTaskTokens: [String: STTBackgroundTaskToken] = [:]
    /// Plaud 等の参照データから抽出した話者数ヒント。
    /// 文字起こし時の話者分離で numSpeakers として使用。
    private var referenceSpeakerCount: Int?

    /// チェックポイント操作用フック。PipelineCoordinator が注入する。
    /// nil の場合は checkpoint 機能は無効（何もしない）。
    private var checkpointHooks: STTCheckpointHooks?

    /// メモリ警告時に API 並列度を 4→1 に下げるフラグ（PR-B11）
    private var underMemoryPressure = false


    /// isIdleTimerDisabled の参照カウント。複数タスク同時実行時に
    /// 先に終わったタスクが画面ロック抑止を解除してしまう問題を防ぐ。
    private var idleTimerHoldCount = 0
    private let readiness: STTReadinessProtocol
    private let chunkerFactory: @Sendable () -> AudioChunkerProtocol
    private let backendFactory: @Sendable (String, STTExecutionConfiguration) -> any STTBackendProcessing
    private let dependencies: STTReadOnlyHostDependencies
    private let capabilities: STTExecutionHostCapabilities
    private let executionDependencies: STTServiceExecutionDependencies

    public init(
        readiness: STTReadinessProtocol = STTReadiness(),
        chunkerFactory: @escaping @Sendable () -> AudioChunkerProtocol = { AudioChunker() },
        backendFactory: (@Sendable (String, STTExecutionConfiguration) -> any STTBackendProcessing)? = nil,
        dependencies: STTReadOnlyHostDependencies,
        capabilities: STTExecutionHostCapabilities,
        executionDependencies: STTServiceExecutionDependencies
    ) {
        self.readiness = readiness
        self.chunkerFactory = chunkerFactory
        self.dependencies = dependencies
        self.capabilities = capabilities
        self.executionDependencies = executionDependencies
        let backendExecutionDependencies = executionDependencies.backend
        self.backendFactory = backendFactory ?? { taskId, configuration in
            STTBackendExecutor(
                taskId: taskId,
                configuration: configuration,
                dependencies: dependencies,
                executionDependencies: backendExecutionDependencies
            )
        }

        // メモリ警告時の observer を登録（PR-B11: 並列度を自動で下げる）
        capabilities.memoryWarnings.observeMemoryWarnings { [weak self] in
            self?.markMemoryPressure()
            self?.dependencies.logger.log("STTService", "メモリ警告受信 — 並列度を下げます", level: .warning)
        }
    }

    public func updateReferenceSpeakerCount(_ count: Int?) {
        stateLock.withLock { referenceSpeakerCount = count }
    }

    public func updateCheckpointHooks(_ hooks: STTCheckpointHooks?) {
        stateLock.withLock { checkpointHooks = hooks }
    }

    public func updateConfiguration(
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode
    ) {
        configurationLock.lock()
        configuration = STTExecutionConfiguration(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode,
            allowsSpeechAnalyzer: dependencies.settings.isSpeechAnalyzerEnabled
        )
        configurationLock.unlock()
    }


    /// 文字起こし開始前の事前見積もり（PR-B11）。
    /// plan() から総時間・チャンク数・概算処理時間を返す。
    /// 長時間ファイルの確認ダイアログ表示に使う。
    public func estimateTranscription(
        fileURL: URL,
        transcriptionMode: TranscriptionMode = .local
    ) async throws -> TranscriptionEstimate {
        let chunker = chunkerFactory()
        let plan = try await chunker.plan(fileURL: fileURL)
        return TranscriptionEstimate(
            sourceURL: fileURL,
            totalDuration: plan.totalDuration,
            chunkCount: plan.count,
            isAPIMode: transcriptionMode == .api
        )
    }

    private func audioFileDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }

    public func makeFingerprint(url: URL, chunkCount: Int) async -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? -1
        let duration = Int(await audioFileDuration(for: url))
        return "\(size)-\(duration)-\(chunkCount)"
    }

    @MainActor
    private func acquireIdleTimerHold() {
        idleTimerHoldCount += 1
        capabilities.idleTimer.setIdleTimerDisabled(true)
    }

    @MainActor
    private func releaseIdleTimerHold() {
        idleTimerHoldCount = max(0, idleTimerHoldCount - 1)
        if idleTimerHoldCount == 0 {
            capabilities.idleTimer.setIdleTimerDisabled(false)
        }
    }
    public func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (any STTTaskHandleProtocol, AsyncStream<STTEvent>) {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CoreError.transcriptionError(.audioFileInvalid)
        }

        let configuration = configurationSnapshot()
        let checkpointHooks = checkpointHooksSnapshot()
        let referenceSpeakerCount = referenceSpeakerCountSnapshot()
        try await validateStartRequest(language: language, configuration: configuration)

        let handle = STTTaskHandle(
            audioURL: audioURL,
            language: language,
            consoleLogger: dependencies.consoleLogger
        )
        store(handle: handle)
        dependencies.logger.log("STTService", "startTranscription — handle 作成: \(handle.taskId), mode: \(configuration.transcriptionMode.rawValue)", level: .info)

        // バックグラウンドタスクを登録: アプリがバックグラウンドに移行しても文字起こしを継続
        // 画面自動ロックを防止: 文字起こし中は画面を点灯したままにする
        await MainActor.run { self.acquireIdleTimerHold() }
        let backgroundTaskToken = await MainActor.run {
            capabilities.backgroundTasks.beginBackgroundTask(
                named: "MemoraSTT-\(handle.taskId)"
            ) { [weak self, weak handle] in
                self?.dependencies.logger.log("STTService", "backgroundTask 期限切れ — タスクをキャンセル: \(handle?.taskId ?? "?")", level: .warning)
                Task { [weak self, weak handle] in
                    await handle?.cancel()
                    await self?.endBackgroundTaskOnMain(taskId: handle?.taskId)
                }
            }
        }
        if let backgroundTaskToken {
            storeBackgroundTaskToken(backgroundTaskToken, taskId: handle.taskId)
            dependencies.logger.log("STTService", "beginBackgroundTask 登録: \(handle.taskId)", level: .info)
        }

        let task = Task(priority: .userInitiated) { [weak self] () throws -> TranscriptionResult in
            guard let self else {
                throw CoreError.dependencyNotSet("STTService")
            }
            return try await self.runTask(
                handle: handle,
                configuration: configuration,
                checkpointHooks: checkpointHooks,
                referenceSpeakerCount: referenceSpeakerCount
            )
        }

        handle.attach(task: task)

        Task { [weak self] in
            do {
                _ = try await task.value
            } catch {
                dependencies.consoleLogger.logDetailed("[MemoraSTT] バックグラウンドタスクエラー: \(error.localizedDescription)")
            }
            self?.removeTask(taskId: handle.taskId)
            await self?.endBackgroundTaskOnMain(taskId: handle.taskId)
            await self?.releaseIdleTimerHold()
        }

        return (handle, handle.events)
    }

    public func getActiveTasks() -> [any STTTaskHandleProtocol] {
        stateLock.withLock { Array(activeTasks.values) }
    }

    public func cancelAllTasks() async {
        let tasks = getActiveTasks()
        for task in tasks {
            await task.cancel()
        }
    }

    private func runTask(
        handle: STTTaskHandle,
        configuration: STTExecutionConfiguration,
        checkpointHooks: STTCheckpointHooks?,
        referenceSpeakerCount: Int?
    ) async throws -> TranscriptionResult {
        let chunker = chunkerFactory()

        dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask 開始 — taskId: \(handle.taskId), url: \(handle.audioURL.lastPathComponent)")
        dependencies.logger.log("STTService", "runTask 開始 — taskId: \(handle.taskId), url: \(handle.audioURL.lastPathComponent)", level: .info)

        do {
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: .transcriptionStarted を yield")
            dependencies.logger.log("STTService", "yield .transcriptionStarted", level: .info)
            handle.yield(.transcriptionStarted(taskId: handle.taskId))
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: .transcriptionProgress(0.02) を yield")
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 0.02))

            // plan: ファイル書き出しなしでチャンク境界を計算（軽量）
            let plan = try await chunker.plan(fileURL: handle.audioURL)
            let totalChunks = max(plan.count, 1)

            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: チャンク計画 \(plan.count)（遅延生成）")
            dependencies.logger.log("STTService", "チャンク計画: \(plan.count)（遅延生成）", level: .info)

            let processingConfiguration = configuration
            let progressThrottler = STTProgressThrottler.forTranscription(
                mode: processingConfiguration.transcriptionMode,
                totalChunks: totalChunks
            )

            // Live Activity 開始（Dynamic Island / ロック画面に進捗表示）
            await MainActor.run {
                capabilities.progress.start(
                    fileName: handle.audioURL.lastPathComponent,
                    totalChunks: totalChunks
                )
            }

            // checkpoint: fingerprint 生成と復元
            let fingerprint = await makeFingerprint(url: handle.audioURL, chunkCount: plan.count)
            let restoredResults = await checkpointHooks?.load(fingerprint) ?? [:]
            if !restoredResults.isEmpty {
                dependencies.logger.log("STTService",
                    "チェックポイント復元 — \(restoredResults.count)/\(plan.count) チャンクを再利用",
                    level: .info)
            }

            var merger = StreamingTranscriptMerger()

            if processingConfiguration.transcriptionMode == .api && plan.count > 1 {
                // 並列経路: merger を inout で渡して逐次蓄積
                try await processChunksConcurrently(
                    plan: plan,
                    chunker: chunker,
                    merger: &merger,
                    handle: handle,
                    configuration: processingConfiguration,
                    totalChunks: totalChunks,
                    restoredResults: restoredResults,
                    fingerprint: fingerprint,
                    checkpointHooks: checkpointHooks
                )
            } else {
                // 直列経路: 1チャンクずつ export → transcribe → append → cleanup
                for slice in plan.slices {
                    try Task.checkCancellation()

                    // checkpoint: 復元済みチャンクはスキップ
                    if let savedResult = restoredResults[slice.index] {
                        let result = savedResult.toTranscriptionResult()
                        merger.append(chunk: AudioChunk(index: slice.index, startSec: slice.startSec, endSec: slice.endSec, url: handle.audioURL, isTemporary: false), result: result)
                        dependencies.logger.log("STTService", "chunk \(slice.index) 復元済み（スキップ）", level: .info)
                        handle.yield(.audioChunkCompleted(chunkIndex: slice.index, result: result))

                        // Live Activity 進捗更新（復元チャンクでも更新）
                        let overallProgress = 0.12 + (0.78 * Double(slice.index + 1) / Double(totalChunks))
                        if progressThrottler.shouldUpdateLiveActivity(completedChunkCount: slice.index + 1, totalChunks: totalChunks) {
                            await MainActor.run {
                                capabilities.progress.update(
                                    progress: overallProgress,
                                    currentChunk: slice.index + 1,
                                    totalChunks: totalChunks
                                )
                            }
                        }
                        continue
                    }

                    dependencies.logger.log("STTService", "chunk \(slice.index)/\(plan.count) 開始", level: .info)
                    handle.yield(.audioChunkStarted(chunkIndex: slice.index))

                    let chunk = try await chunker.exportSlice(slice, from: plan)

                    let engine = backendFactory(
                        "\(handle.taskId)-chunk-\(slice.index)",
                        processingConfiguration
                    )
                    let result: TranscriptionResult
                    do {
                        result = try await engine.transcribe(
                            audioURL: chunk.url,
                            language: handle.language,
                            progress: { chunkProgress in
                                let overall = (Double(slice.index) + chunkProgress) / Double(totalChunks)
                                let progress = 0.12 + (0.78 * overall)
                                if progressThrottler.shouldEmitProgress(progress) {
                                    handle.yield(.audioChunkProgress(chunkIndex: slice.index, progress: chunkProgress))
                                    handle.yield(
                                        .transcriptionProgress(
                                            taskId: handle.taskId,
                                            progress: progress
                                        )
                                    )
                                }
                            },
                            partialResult: { partialText in
                                if progressThrottler.shouldEmitPartial() {
                                    handle.yield(.transcriptionPartialResult(taskId: handle.taskId, text: partialText))
                                }
                            }
                        )
                    } catch {
                        await chunker.cleanupChunk(chunk)
                        throw error
                    }

                    merger.append(chunk: chunk, result: result)
                    // 処理済みチャンクの一時ファイルを即削除（メモリ&ディスク解放）
                    await chunker.cleanupChunk(chunk)

                    dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: chunk \(slice.index) 完了 — text: \(result.fullText.prefix(40))")
                    dependencies.logger.log("STTService", "chunk \(slice.index) 完了 — \(result.fullText.count)文字", level: .info)
                    handle.yield(.audioChunkCompleted(chunkIndex: slice.index, result: result))

                    // checkpoint: チャンク結果を保存
                    await checkpointHooks?.save(fingerprint, plan.count, slice.index, CheckpointChunkResult(from: result))

                    // Live Activity 進捗更新
                    let overallProgress = 0.12 + (0.78 * Double(slice.index + 1) / Double(totalChunks))
                    if progressThrottler.shouldUpdateLiveActivity(completedChunkCount: slice.index + 1, totalChunks: totalChunks) {
                        await MainActor.run {
                            capabilities.progress.update(
                                progress: overallProgress,
                                currentChunk: slice.index + 1,
                                totalChunks: totalChunks
                            )
                        }
                    }
                }
            }

            let mergedResult = postProcessor.process(merger.finalize(preferredLanguage: handle.language))
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: merge 完了 — \(mergedResult.fullText.count)文字, \(mergedResult.segments.count)セグメント")
            dependencies.logger.log("STTService", "merge 完了 — \(mergedResult.fullText.count)文字, \(mergedResult.segments.count)セグメント", level: .info)

            // 話者分離は有料/API モードで明示的に有効化された場合だけ実行する。
            // ローカル処理では常にスキップし、文字起こし完了までの時間と電池消費を抑える。
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 0.92))
            let shouldRunSpeakerDiarization = processingConfiguration.transcriptionMode == .api
                && dependencies.settings.isSpeakerDiarizationEnabled
            let finalSegments: [TranscriptionSegment]
            if shouldRunSpeakerDiarization {
                finalSegments = await detectSpeakersWithTimeout(
                    audioURL: handle.audioURL,
                    segments: mergedResult.segments,
                    numSpeakers: referenceSpeakerCount
                )
            } else {
                dependencies.logger.log(
                    "STTService",
                    "話者分離はローカル処理または設定OFFのためスキップ",
                    level: .info
                )
                finalSegments = removingSpeakerLabels(from: mergedResult.segments)
            }
            let finalResult = postProcessor.process(TranscriptionResult(
                fullText: mergedResult.fullText,
                language: mergedResult.language,
                segments: finalSegments
            ))

            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 1.0))
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: .transcriptionCompleted を yield — \(finalResult.fullText.count)文字")
            handle.yield(.transcriptionCompleted(taskId: handle.taskId, result: finalResult))
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: .transcriptionCompleted yield 完了")
            dependencies.logger.log("STTService", "yield .transcriptionCompleted — finish() 呼び出し", level: .info)
            handle.finish()
            // Live Activity 終了（成功）
            await MainActor.run {
                capabilities.progress.finish(
                    success: true,
                    characterCount: finalResult.fullText.count
                )
            }
            dependencies.consoleLogger.logDetailed("[MemoraSTT] runTask: finish() 完了")
            return finalResult
        } catch is CancellationError {
            dependencies.logger.log("STTService", "runTask cancelled — taskId: \(handle.taskId)", level: .warning)
            handle.yield(.transcriptionCancelled(taskId: handle.taskId))
            handle.finish()
            await MainActor.run { capabilities.progress.finish(success: false, characterCount: 0) }
            throw CancellationError()
        } catch let coreError as CoreError {
            dependencies.logger.log("STTService", "runTask CoreError — taskId: \(handle.taskId): \(coreError.localizedDescription)", level: .error)
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: coreError))
            handle.finish()
            await MainActor.run { capabilities.progress.finish(success: false, characterCount: 0) }
            throw coreError
        } catch {
            let mappedError = STTErrorMapper.mapToCoreError(error)
            dependencies.logger.log("STTService", "runTask error — taskId: \(handle.taskId): \(error.localizedDescription)", level: .error)
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: mappedError))
            handle.finish()
            await MainActor.run { capabilities.progress.finish(success: false, characterCount: 0) }
            throw mappedError
        }
    }

    /// API モードでチャンクを並列処理する（ストリーミング版）。
    /// plan の slices をバッチに分け、バッチ単位で export → 並列文字起こし → merge → cleanup。
    private func processChunksConcurrently(
        plan: AudioChunkPlan,
        chunker: AudioChunkerProtocol,
        merger: inout StreamingTranscriptMerger,
        handle: STTTaskHandle,
        configuration: STTExecutionConfiguration,
        totalChunks: Int,
        restoredResults: [Int: CheckpointChunkResult],
        fingerprint: String,
        checkpointHooks: STTCheckpointHooks?
    ) async throws {
        dependencies.logger.log("STTService", "並列チャンク処理開始 — \(plan.count)チャンク（ストリーミング）", level: .info)

        let maxConcurrentChunks = memoryPressureSnapshot() ? 1 : min(4, max(1, plan.count))
        let sliceBatches = plan.slices.chunked(into: maxConcurrentChunks)
        var completedCount = 0
        let backendFactory = self.backendFactory

        for batch in sliceBatches {
            try Task.checkCancellation()
            let pendingSlices = batch.filter { restoredResults[$0.index] == nil }
            var chunksByIndex: [Int: AudioChunk] = [:]

            // export は逐次化し、途中失敗時にも生成済み一時ファイルを必ず把握して削除する。
            do {
                for slice in pendingSlices {
                    try Task.checkCancellation()
                    handle.yield(.audioChunkStarted(chunkIndex: slice.index))
                    chunksByIndex[slice.index] = try await chunker.exportSlice(slice, from: plan)
                }
            } catch {
                for chunk in chunksByIndex.values {
                    await chunker.cleanupChunk(chunk)
                }
                throw error
            }

            let newResults: [(Int, TranscriptionResult)]
            do {
                newResults = try await withThrowingTaskGroup(
                    of: (Int, TranscriptionResult).self
                ) { group in
                    for (index, chunk) in chunksByIndex {
                        group.addTask {
                            let engine = backendFactory(
                                "\(handle.taskId)-chunk-\(index)",
                                configuration
                            )
                            let result = try await engine.transcribe(
                                audioURL: chunk.url,
                                language: handle.language,
                                progress: { _ in },
                                partialResult: { _ in }
                            )
                            return (index, result)
                        }
                    }
                    var accumulated: [(Int, TranscriptionResult)] = []
                    for try await result in group { accumulated.append(result) }
                    return accumulated.sorted { $0.0 < $1.0 }
                }
            } catch {
                for chunk in chunksByIndex.values {
                    await chunker.cleanupChunk(chunk)
                }
                throw error
            }
            let newResultsByIndex = Dictionary(uniqueKeysWithValues: newResults)

            // 復元結果と新規結果を元のチャンク順にマージする。
            for slice in batch.sorted(by: { $0.index < $1.index }) {
                let isRestored = restoredResults[slice.index] != nil
                let result: TranscriptionResult
                let chunk: AudioChunk
                if let restored = restoredResults[slice.index] {
                    result = restored.toTranscriptionResult()
                    chunk = AudioChunk(
                        index: slice.index,
                        startSec: slice.startSec,
                        endSec: slice.endSec,
                        url: plan.sourceURL,
                        isTemporary: false
                    )
                    dependencies.logger.log(
                        "STTService",
                        "並列 chunk \(slice.index) 復元済み（スキップ）",
                        level: .info
                    )
                } else {
                    guard let newResult = newResultsByIndex[slice.index],
                          let exportedChunk = chunksByIndex[slice.index] else {
                        for chunk in chunksByIndex.values {
                            await chunker.cleanupChunk(chunk)
                        }
                        throw CoreError.transcriptionError(
                            .transcriptionFailed("Missing chunk result at index \(slice.index)")
                        )
                    }
                    result = newResult
                    chunk = exportedChunk
                }

                merger.append(chunk: chunk, result: result)
                if !isRestored {
                    await checkpointHooks?.save(
                        fingerprint,
                        plan.count,
                        slice.index,
                        CheckpointChunkResult(from: result)
                    )
                }
                completedCount += 1
                let overall = 0.12 + (0.78 * Double(completedCount) / Double(totalChunks))
                handle.yield(.transcriptionProgress(
                    taskId: handle.taskId,
                    progress: overall
                ))
                handle.yield(.audioChunkCompleted(
                    chunkIndex: slice.index,
                    result: result
                ))
                let liveActivityCompletedCount = completedCount
                await MainActor.run {
                    capabilities.progress.update(
                        progress: overall,
                        currentChunk: liveActivityCompletedCount,
                        totalChunks: totalChunks
                    )
                }
                dependencies.logger.log(
                    "STTService",
                    "並列 chunk \(slice.index) 完了 — \(result.fullText.count)文字",
                    level: .info
                )
            }

            for chunk in chunksByIndex.values {
                await chunker.cleanupChunk(chunk)
            }
        }
    }

    private func merge(
        chunks: [AudioChunk],
        results: [TranscriptionResult],
        preferredLanguage: String?
    ) -> TranscriptionResult {
        let fullText = results
            .map(\.fullText)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let mergedSegments = zip(chunks, results).flatMap { chunk, result in
            result.segments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: "\(chunk.index)-\(segment.id)-\(index)",
                    speakerLabel: segment.speakerLabel,
                    startSec: segment.startSec + chunk.startSec,
                    endSec: segment.endSec + chunk.startSec,
                    text: segment.text,
                    isEstimatedTiming: segment.isEstimatedTiming
                )
            }
        }
        let language = preferredLanguage.map(STTLanguageNormalizer.baseLanguageCode(for:))
            ?? results.first?.language
            ?? "ja"

        return TranscriptionResult(
            fullText: fullText,
            language: language,
            segments: mergedSegments
        )
    }

    private func removingSpeakerLabels(from segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                speakerLabel: "",
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: segment.text,
                isEstimatedTiming: segment.isEstimatedTiming
            )
        }
    }

    private func validateStartRequest(
        language: String?,
        configuration: STTExecutionConfiguration
    ) async throws {
        guard configuration.transcriptionMode == .local else { return }

        try await readiness.prepare()

        let supportedLanguages = await readiness.supportedLanguages
        if let language,
           !supportedLanguages.isEmpty,
           !supportedLanguages.contains(STTLanguageNormalizer.baseLanguageCode(for: language)) {
            throw CoreError.transcriptionError(.languageNotSupported(language))
        }
    }

    private func configurationSnapshot() -> STTExecutionConfiguration {
        configurationLock.withLock { configuration }
    }

    private func checkpointHooksSnapshot() -> STTCheckpointHooks? {
        stateLock.withLock { checkpointHooks }
    }

    private func referenceSpeakerCountSnapshot() -> Int? {
        stateLock.withLock { referenceSpeakerCount }
    }

    private func markMemoryPressure() {
        stateLock.withLock { underMemoryPressure = true }
    }

    private func memoryPressureSnapshot() -> Bool {
        stateLock.withLock { underMemoryPressure }
    }

    private func store(handle: STTTaskHandle) {
        stateLock.withLock { activeTasks[handle.taskId] = handle }
    }

    private func removeTask(taskId: String) {
        _ = stateLock.withLock { activeTasks.removeValue(forKey: taskId) }
    }

    private func storeBackgroundTaskToken(
        _ token: STTBackgroundTaskToken,
        taskId: String
    ) {
        stateLock.withLock { backgroundTaskTokens[taskId] = token }
    }

    private func takeBackgroundTaskToken(taskId: String) -> STTBackgroundTaskToken? {
        stateLock.withLock { backgroundTaskTokens.removeValue(forKey: taskId) }
    }

    private func endBackgroundTaskOnMain(taskId: String?) async {
        guard let taskId else { return }
        guard let backgroundTaskToken = takeBackgroundTaskToken(taskId: taskId) else { return }
        await MainActor.run {
            capabilities.backgroundTasks.endBackgroundTask(backgroundTaskToken)
        }
        dependencies.logger.log("STTService", "endBackgroundTask: \(taskId)", level: .info)
    }

    /// FluidAudio（CoreML / ANE）による全体ファイル話者分離。
    /// 指定秒数でタイムアウトし、フォールバックとして元セグメントを返す。
    private func detectSpeakersWithTimeout(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int? = nil,
        timeout: TimeInterval = 300
    ) async -> [TranscriptionSegment] {
        dependencies.logger.log("STTService", "全体ファイル話者分離開始 — \(segments.count)セグメント, numSpeakers: \(numSpeakers?.description ?? "auto"), timeout: \(timeout)s", level: .info)
        do {
            let speakers = try await withSTTTimeout(
                seconds: timeout,
                timeoutError: STTOperationTimeoutError()
            ) {
                await self.executionDependencies.diarizationService.detectSpeakers(
                    audioURL: audioURL,
                    segments: segments,
                    numSpeakers: numSpeakers
                )
            }
            dependencies.logger.log("STTService", "全体ファイル話者分離完了 — \(speakers.count)セグメント", level: .info)
            return speakers
        } catch {
            dependencies.logger.log("STTService", "全体ファイル話者分離タイムアウト (\(timeout)s)", level: .warning)
            return segments
        }
    }


    // MARK: - Post-hoc Speaker Diarization (opt-in)

    /// 保存済み transcript のセグメントに対する後付け話者分離。
    /// 文字起こしパイプラインとは独立に呼び出せる。
    /// - Returns: 話者ラベルを付与したセグメント。タイムアウト/失敗時は入力をそのまま返す。
    public func detectSpeakersPostHoc(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int? = nil,
        timeout: TimeInterval = 300
    ) async -> [TranscriptionSegment] {
        guard FileManager.default.fileExists(atPath: audioURL.path), !segments.isEmpty else {
            return segments
        }
        dependencies.logger.log("STTService",
            "後付け話者分離 開始 — \(segments.count)セグメント",
            level: .info)
        return await detectSpeakersWithTimeout(
            audioURL: audioURL,
            segments: segments,
            numSpeakers: numSpeakers,
            timeout: timeout
        )
    }

}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
