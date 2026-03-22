import Foundation
import Speech

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
        lock.lock()
        let task = resultTask
        lock.unlock()

        guard let task else {
            throw CoreError.transcriptionError(.transcriptionFailed("Task result is unavailable"))
        }
        return try await task.value
    }

    func cancel() async {
        lock.lock()
        let task = resultTask
        running = false
        lock.unlock()
        task?.cancel()
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

final class STTService: STTServiceProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private let configurationLock = NSLock()

    private var activeTasks: [String: STTTaskHandle] = [:]
    private var configuration = STTExecutionConfiguration.localDefault

    private let readiness: STTReadinessProtocol
    private let chunkerFactory: @Sendable () -> AudioChunkerProtocol

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
    ) async throws -> (STTTaskHandleProtocol, AsyncStream<STTEvent>) {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CoreError.transcriptionError(.audioFileInvalid)
        }

        try await readiness.prepare()

        let supportedLanguages = await readiness.supportedLanguages
        if let language,
           !supportedLanguages.isEmpty,
           !supportedLanguages.contains(STTLanguageNormalizer.baseLanguageCode(for: language)) {
            throw CoreError.transcriptionError(.languageNotSupported(language))
        }

        let handle = STTTaskHandle(audioURL: audioURL, language: language)
        let configuration = configurationSnapshot()
        store(handle: handle)

        let task = Task(priority: .userInitiated) { [weak self] () throws -> TranscriptionResult in
            guard let self else {
                throw CoreError.dependencyNotSet("STTService")
            }
            return try await self.runTask(handle: handle, configuration: configuration)
        }

        handle.attach(task: task)

        Task { [weak self] in
            _ = try? await task.value
            self?.removeTask(taskId: handle.taskId)
        }

        return (handle, handle.events)
    }

    func getActiveTasks() -> [STTTaskHandleProtocol] {
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

                let engine = InternalTranscriptionEngine(configuration: configuration)
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

            let mergedResult = merge(results: chunkResults, preferredLanguage: handle.language)
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
        results: [TranscriptionResult],
        preferredLanguage: String?
    ) -> TranscriptionResult {
        let fullText = results
            .map(\.fullText)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let mergedSegments = results.flatMap(\.segments)
        let language = preferredLanguage.map(STTLanguageNormalizer.baseLanguageCode(for:))
            ?? results.first?.language
            ?? "ja"

        return TranscriptionResult(
            fullText: fullText,
            language: language,
            segments: mergedSegments
        )
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
