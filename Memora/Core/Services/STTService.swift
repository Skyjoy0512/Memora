import Foundation
@preconcurrency import AVFoundation
import Speech

// Core transcription boundary. Changes require explicit STT approval and regression checks.

final class STTTaskHandle: STTTaskHandleProtocol, @unchecked Sendable {
    let id: String
    var taskId: String { id }
    let audioURL: URL
    let language: String?

    private let lock = NSLock()
    private let streamStorage: AsyncStream<STTEvent>
    private var continuation: AsyncStream<STTEvent>.Continuation?
    private var resultTask: Task<TranscriptionResult, Error>?
    private var running = true

    init(audioURL: URL, language: String?) {
        self.id = UUID().uuidString
        self.audioURL = audioURL
        self.language = language

        var storedContinuation: AsyncStream<STTEvent>.Continuation?
        self.streamStorage = AsyncStream { continuation in
            storedContinuation = continuation
        }
        self.continuation = storedContinuation
    }

    var isRunning: Bool {
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

    func result() async throws -> TranscriptionResult {
        let task = currentTask()

        guard let task else {
            throw CoreError.transcriptionError(.transcriptionFailed("Task result is unavailable"))
        }
        return try await task.value
    }

    func cancel() async {
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

final class STTReadiness: STTReadinessProtocol, @unchecked Sendable {
    private let preferredLocale = Locale(identifier: "ja_JP")

    var isReady: Bool {
        get async {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                return false
            }
            return SFSpeechRecognizer(locale: preferredLocale)?.isAvailable ?? false
        }
    }

    var supportedLanguages: [String] {
        get async {
            let languages = SFSpeechRecognizer.supportedLocales().compactMap { locale in
                STTLanguageNormalizer.baseLanguageCode(for: locale.identifier)
            }
            return Array(Set(languages)).sorted()
        }
    }

    var requiresDownload: Bool {
        get async { false }
    }

    func prepare() async throws {
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

private final class STTBackendExecutor {
    private let taskId: String
    private let configuration: STTExecutionConfiguration
    private let stateLock = NSLock()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let diarizationService: SpeakerDiarizationProtocol

    init(
        taskId: String,
        configuration: STTExecutionConfiguration,
        diarizationService: SpeakerDiarizationProtocol
    ) {
        self.taskId = taskId
        self.configuration = configuration
        self.diarizationService = diarizationService
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

        #if !targetEnvironment(simulator)
        if #available(iOS 26.0, *) {
            let preflight = SpeechAnalyzerPreflight()
            let result = await preflight.run(locale: locale)

            switch result {
            case .ready(let diag):
                print("[MemoraSTT] SpeechAnalyzer preflight passed — \(diag.summary)")
                do {
                    let transcription = try await transcribeWithSpeechAnalyzerWithTimeout(
                        audioURL: audioURL,
                        locale: locale,
                        progress: progress,
                        partialResult: partialResult
                    )
                    let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
                    let ms = Double(elapsed.components.seconds) * 1000.0
                        + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
                    STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
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
                } catch {
                    print("[MemoraSTT] SpeechAnalyzer runtime fallback: \(error.localizedDescription)")
                    STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
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
                print("[MemoraSTT] SpeechAnalyzer preflight failed — \(reason.description)")
                STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
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
        #endif

        print("[MemoraSTT] SFSpeechRecognizer パスを使用（タイムアウト付き）")
        do {
            let transcription = try await transcribeWithSpeechRecognizerWithTimeout(
                audioURL: audioURL,
                locale: locale,
                progress: progress,
                partialResult: partialResult
            )
            let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
            let ms = Double(elapsed.components.seconds) * 1000.0
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
            STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
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
        } catch is OnDeviceTranscriptionTimeoutError {
            print("[MemoraSTT] オンモデバイス認識タイムアウト — requiresOnDeviceRecognition=false でリトライ")
            STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
                taskId: taskId,
                backend: .sfSpeechRecognizer,
                locale: locale.identifier,
                assetState: nil,
                audioFormat: nil,
                fallbackReason: "on-device timeout, retrying with server recognition",
                processingTimeMs: nil,
                recordedAt: Date()
            ))
            let transcription = try await transcribeWithSpeechRecognizerWithTimeout(
                audioURL: audioURL,
                locale: locale,
                progress: progress,
                partialResult: partialResult,
                forceOnDevice: false
            )
            let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
            let ms = Double(elapsed.components.seconds) * 1000.0
                + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
            STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
                taskId: taskId,
                backend: .sfSpeechRecognizer,
                locale: locale.identifier,
                assetState: nil,
                audioFormat: nil,
                fallbackReason: "server recognition (on-device timed out)",
                processingTimeMs: ms,
                recordedAt: Date()
            ))
            return transcription
        }
    }

    private func transcribeWithSpeechRecognizer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void,
        forceOnDevice: Bool = true
    ) async throws -> TranscriptionResult {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            print("[MemoraSTT] SFSpeechRecognizer 利用不可 — locale: \(locale.identifier)")
            throw CoreError.transcriptionError(.engineNotAvailable)
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = forceOnDevice
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        print("[MemoraSTT] SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: \(forceOnDevice)")
        progress(0.2)

        let recognitionResult = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                let callbackLock = NSLock()
                var didResume = false

                let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    if let result {
                        partialResult(result.bestTranscription.formattedString)
                    }

                    if let error {
                        callbackLock.lock()
                        let shouldResume = !didResume
                        didResume = true
                        callbackLock.unlock()

                        guard shouldResume else { return }
                        self?.clearRecognitionTask()
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let result, result.isFinal else { return }

                    callbackLock.lock()
                    let shouldResume = !didResume
                    didResume = true
                    callbackLock.unlock()

                    guard shouldResume else { return }
                    self?.clearRecognitionTask()
                    continuation.resume(returning: result)
                }

                self.storeRecognitionTask(task)
            }
        } onCancel: {
            self.cancelRecognitionTask()
        }

        progress(0.92)

        let baseSegments = recognitionResult.bestTranscription.segments.enumerated().map { index, segment in
            TranscriptionSegment(
                id: "segment-\(index)",
                speakerLabel: "Speaker 1",
                startSec: segment.timestamp,
                endSec: segment.timestamp + segment.duration,
                text: segment.substring
            )
        }

        let segmentsWithSpeakers = await detectSpeakersWithTimeout(
            audioURL: audioURL,
            segments: baseSegments
        )

        return TranscriptionResult(
            fullText: recognitionResult.bestTranscription.formattedString,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: segmentsWithSpeakers
        )
    }

    /// SFSpeechRecognizer に60秒タイムアウトを追加したラッパー。
    /// コールバックが永久に返らない iOS バグを防止する。
    private func transcribeWithSpeechRecognizerWithTimeout(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void,
        forceOnDevice: Bool = true
    ) async throws -> TranscriptionResult {
        try await withThrowingTaskGroup(of: TranscriptionResult.self) { group in
            group.addTask {
                try await self.transcribeWithSpeechRecognizer(
                    audioURL: audioURL,
                    locale: locale,
                    progress: progress,
                    partialResult: partialResult,
                    forceOnDevice: forceOnDevice
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60秒
                self.cancelRecognitionTask()
                throw OnDeviceTranscriptionTimeoutError()
            }
            guard let result = try await group.next() else {
                group.cancelAll()
                throw CoreError.transcriptionError(.transcriptionFailed("SFSpeechRecognizer produced no result"))
            }
            group.cancelAll()
            return result
        }
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzerWithTimeout(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        try await withThrowingTaskGroup(of: TranscriptionResult.self) { group in
            group.addTask {
                try await self.transcribeWithSpeechAnalyzer(
                    audioURL: audioURL,
                    locale: locale,
                    progress: progress,
                    partialResult: partialResult
                )
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60秒
                throw OnDeviceTranscriptionTimeoutError()
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw CoreError.transcriptionError(.transcriptionFailed("SpeechAnalyzer produced no result"))
            }
            group.cancelAll()
            return result
        }
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        let service = SpeechAnalyzerService26()

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        partialResult(text)
        progress(0.92)

        let duration = await audioFileDuration(for: audioURL)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)
        let segmentsWithSpeakers = await detectSpeakersWithTimeout(
            audioURL: audioURL,
            segments: baseSegments
        )

        return TranscriptionResult(
            fullText: text,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: segmentsWithSpeakers
        )
    }

    private func transcribeRemotely(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard !configuration.apiKey.isEmpty else {
            throw CoreError.transcriptionError(.transcriptionFailed("API key is missing"))
        }

        print("[MemoraSTT] API パス開始 — provider: \(configuration.provider.rawValue)")
        let remoteStart = ContinuousClock.now

        let service = AIService()
        service.setProvider(configuration.provider)
        service.setTranscriptionMode(.api)
        try await service.configure(apiKey: configuration.apiKey)

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        progress(0.92)

        print("[MemoraSTT] API パス完了 — text length: \(text.count)")

        let duration = await audioFileDuration(for: audioURL)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)
        let segmentsWithSpeakers = await detectSpeakersWithTimeout(
            audioURL: audioURL,
            segments: baseSegments
        )

        let elapsed = remoteStart.duration(to: ContinuousClock.now)
        let ms = Double(elapsed.components.seconds) * 1000.0
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
        STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
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
            segments: segmentsWithSpeakers
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
                text: line
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

    private func storeRecognitionTask(_ task: SFSpeechRecognitionTask?) {
        stateLock.lock()
        recognitionTask = task
        stateLock.unlock()
    }

    private func clearRecognitionTask() {
        stateLock.lock()
        recognitionTask = nil
        stateLock.unlock()
    }

    private func cancelRecognitionTask() {
        stateLock.lock()
        recognitionTask?.cancel()
        recognitionTask = nil
        stateLock.unlock()
    }

    /// 話者分離にタイムアウトを追加。ハング時にフォールバックとして元セグメントを返す。
    private func detectSpeakersWithTimeout(
        audioURL: URL,
        segments: [TranscriptionSegment],
        timeout: TimeInterval = 60
    ) async -> [TranscriptionSegment] {
        do {
            return try await withThrowingTaskGroup(of: [TranscriptionSegment].self) { group in
                group.addTask { [self] in
                    await diarizationService.detectSpeakers(
                        audioURL: audioURL,
                        segments: segments
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    print("[MemoraSTT] 話者分離タイムアウト(\(Int(timeout))秒) — フォールバック使用")
                    return segments
                }
                guard let result = try await group.next() else {
                    group.cancelAll()
                    return segments
                }
                group.cancelAll()
                return result
            }
        } catch {
            print("[MemoraSTT] 話者分離エラー — フォールバック使用: \(error)")
            return segments
        }
    }
}

final class STTService: STTServiceProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private let configurationLock = NSLock()

    private var activeTasks: [String: STTTaskHandle] = [:]
    private var configuration = STTExecutionConfiguration.localDefault

    private let readiness: STTReadinessProtocol
    private let chunkerFactory: @Sendable () -> AudioChunkerProtocol
    private let diarizationService: SpeakerDiarizationProtocol = SpeakerDiarizationService()

    init(
        readiness: STTReadinessProtocol = STTReadiness(),
        chunkerFactory: @escaping @Sendable () -> AudioChunkerProtocol = { AudioChunker() }
    ) {
        self.readiness = readiness
        self.chunkerFactory = chunkerFactory
    }

    func updateConfiguration(
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode
    ) {
        configurationLock.lock()
        configuration = STTExecutionConfiguration(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode
        )
        configurationLock.unlock()
    }

    func startTranscription(
        audioURL: URL,
        language: String?
    ) async throws -> (any STTTaskHandleProtocol, AsyncStream<STTEvent>) {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CoreError.transcriptionError(.audioFileInvalid)
        }

        let configuration = configurationSnapshot()
        try await validateStartRequest(language: language, configuration: configuration)

        let handle = STTTaskHandle(audioURL: audioURL, language: language)
        store(handle: handle)

        let task = Task(priority: .userInitiated) { [weak self] () throws -> TranscriptionResult in
            guard let self else {
                throw CoreError.dependencyNotSet("STTService")
            }
            return try await self.runTask(handle: handle, configuration: configuration)
        }

        handle.attach(task: task)

        Task { [weak self] in
            do {
                _ = try await task.value
            } catch {
                print("[MemoraSTT] バックグラウンドタスクエラー: \(error.localizedDescription)")
            }
            self?.removeTask(taskId: handle.taskId)
        }

        return (handle, handle.events)
    }

    func getActiveTasks() -> [any STTTaskHandleProtocol] {
        stateLock.lock()
        let tasks = Array(activeTasks.values)
        stateLock.unlock()
        return tasks
    }

    func cancelAllTasks() async {
        let tasks = getActiveTasks()
        for task in tasks {
            await task.cancel()
        }
    }

    private func runTask(
        handle: STTTaskHandle,
        configuration: STTExecutionConfiguration
    ) async throws -> TranscriptionResult {
        let chunker = chunkerFactory()
        var preparedChunks: [AudioChunk] = []

        do {
            handle.yield(.transcriptionStarted(taskId: handle.taskId))
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 0.02))

            preparedChunks = try await chunker.analyzeAndChunk(fileURL: handle.audioURL) { completed, total in
                let progress = total > 0 ? Double(completed) / Double(total) : 1
                handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: min(0.12, 0.12 * progress)))
                handle.yield(
                    .audioChunkProgress(
                        chunkIndex: max(0, completed - 1),
                        progress: progress
                    )
                )
            }

            defer {
                Task {
                    await chunker.cleanup(chunks: preparedChunks)
                }
            }

            var chunkResults: [TranscriptionResult] = []
            let totalChunks = max(preparedChunks.count, 1)

            for (index, chunk) in preparedChunks.enumerated() {
                try Task.checkCancellation()

                handle.yield(.audioChunkStarted(chunkIndex: chunk.index))

                let engine = STTBackendExecutor(
                    taskId: "\(handle.taskId)-chunk-\(chunk.index)",
                    configuration: configuration,
                    diarizationService: diarizationService
                )
                let result = try await engine.transcribe(
                    audioURL: chunk.url,
                    language: handle.language,
                    progress: { chunkProgress in
                        let overall = (Double(index) + chunkProgress) / Double(totalChunks)
                        handle.yield(.audioChunkProgress(chunkIndex: chunk.index, progress: chunkProgress))
                        handle.yield(
                            .transcriptionProgress(
                                taskId: handle.taskId,
                                progress: 0.12 + (0.78 * overall)
                            )
                        )
                    },
                    partialResult: { partialText in
                        handle.yield(.transcriptionPartialResult(taskId: handle.taskId, text: partialText))
                    }
                )

                chunkResults.append(result)
                handle.yield(.audioChunkCompleted(chunkIndex: chunk.index, result: result))
            }

            let mergedResult = merge(
                chunks: preparedChunks,
                results: chunkResults,
                preferredLanguage: handle.language
            )
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 1.0))
            handle.yield(.transcriptionCompleted(taskId: handle.taskId, result: mergedResult))
            handle.finish()
            return mergedResult
        } catch is CancellationError {
            handle.yield(.transcriptionCancelled(taskId: handle.taskId))
            handle.finish()
            throw CancellationError()
        } catch let coreError as CoreError {
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: coreError))
            handle.finish()
            throw coreError
        } catch {
            let mappedError = STTErrorMapper.mapToCoreError(error)
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: mappedError))
            handle.finish()
            throw mappedError
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
                    text: segment.text
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
        configurationLock.lock()
        let snapshot = configuration
        configurationLock.unlock()
        return snapshot
    }

    private func store(handle: STTTaskHandle) {
        stateLock.lock()
        activeTasks[handle.taskId] = handle
        stateLock.unlock()
    }

    private func removeTask(taskId: String) {
        stateLock.lock()
        activeTasks.removeValue(forKey: taskId)
        stateLock.unlock()
    }
}
