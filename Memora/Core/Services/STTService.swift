import Foundation
@preconcurrency import AVFoundation
import Speech
import UIKit

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

    deinit {
        let stillRunning: Bool
        lock.lock()
        stillRunning = running
        lock.unlock()
        if stillRunning {
            STTConsoleLog("[MemoraSTT] STTTaskHandle.deinit — ⚠️ まだ running=true のまま解放: taskId=\(taskId), url=\(audioURL.lastPathComponent)")
        } else {
            STTConsoleLog("[MemoraSTT] STTTaskHandle.deinit — 正常解放: taskId=\(taskId)")
        }
    }

    init(audioURL: URL, language: String?) {
        self.id = UUID().uuidString
        self.audioURL = audioURL
        self.language = language

        var storedContinuation: AsyncStream<STTEvent>.Continuation?
        // .unbounded バッファリングでイベントドロップを防止
        self.streamStorage = AsyncStream(
            bufferingPolicy: .unbounded
        ) { continuation in
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

    init(
        taskId: String,
        configuration: STTExecutionConfiguration
    ) {
        self.taskId = taskId
        self.configuration = configuration
    }


    deinit {
        cancelRecognitionTask()
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
        DebugLogger.shared.addLog("STTBackend", "transcribeLocally 開始 — locale: \(locale.identifier), file: \(audioURL.lastPathComponent)", level: .info)

        // SpeechAnalyzer (iOS 26) を優先使用。
        // 高レベルAPI analyzeSequence(from:) で MP3/M4A を直接処理。
        // 失敗時は SFSpeechRecognizer にフォールバック。
        #if !targetEnvironment(simulator)
        if configuration.allowsSpeechAnalyzer {
            if #available(iOS 26.0, *) {
            let preflight = SpeechAnalyzerPreflight()
            let result = await preflight.run(locale: locale)

            switch result {
            case .ready(let diag):
                DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer preflight passed — \(diag.summary)", level: .info)
                do {
                    let transcription = try await transcribeWithSpeechAnalyzerWithTimeout(
                        audioURL: audioURL,
                        locale: locale,
                        progress: progress,
                        partialResult: partialResult
                    )
                    let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
                    let ms = DurationFormatter.milliseconds(elapsed)
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
                    DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer runtime fallback: \(error.localizedDescription)", level: .warning)
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
                DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer preflight failed — \(reason.description)", level: .warning)
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
        }
        #endif

        STTConsoleLog("[MemoraSTT] SFSpeechRecognizer パスを使用（on-device → server フォールバック付き）")
        DebugLogger.shared.addLog("STTBackend", "SFSpeechRecognizer パス開始 — on-device優先", level: .info)
        do {
            let transcription = try await transcribeWithSpeechRecognizerWithTimeout(
                audioURL: audioURL,
                locale: locale,
                progress: progress,
                partialResult: partialResult
            )

            // SFSpeechRecognizer は無音区間や低品質区間で早期に isFinal=true を
            // 返すことがあるため、セグメントカバレッジをチェックする。
            // カバレッジが 80% 未満なら server 認識にフォールバックする。
            let chunkDuration = await audioFileDuration(for: audioURL)
            let lastEnd = transcription.segments.last?.endSec ?? 0
            let coverage = chunkDuration > 1.0 ? lastEnd / chunkDuration : 1.0
            if coverage < 0.8 {
                // 未カバー区間が実質無音なら server 再試行しない（PR-B4）
                let tailRMS = AudioSilenceProbe.averageRMS(url: audioURL, startSec: lastEnd, endSec: chunkDuration)
                let silenceThreshold: Float = 0.008
                if let tailRMS, tailRMS < silenceThreshold {
                    DebugLogger.shared.addLog(
                        "STTBackend",
                        "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) だが末尾は無音 (RMS=\(String(format: "%.4f", tailRMS))) — server 再試行をスキップ",
                        level: .info
                    )
                } else {
                    DebugLogger.shared.addLog(
                        "STTBackend",
                        "低カバレッジ (\(String(format: "%.0f", coverage * 100))%) — server でリトライ (tailRMS=\(tailRMS.map { String(format: "%.4f", $0) } ?? "n/a"))",
                        level: .warning
                    )
                    throw OnDeviceTranscriptionTimeoutError()
                }
            }

            let elapsed = transcriptionStart.duration(to: ContinuousClock.now)
            let ms = DurationFormatter.milliseconds(elapsed)
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
        } catch {
            // on-device がタイムアウト・モデル未ダウンロード・その他エラーのいずれでも
            // server recognition にフォールバックする
            DebugLogger.shared.addLog("STTBackend", "on-device 認識失敗 — server recognition でリトライ: \(error.localizedDescription)", level: .warning)
            STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
                taskId: taskId,
                backend: .sfSpeechRecognizer,
                locale: locale.identifier,
                assetState: nil,
                audioFormat: nil,
                fallbackReason: "on-device failed (\(error.localizedDescription)), retrying with server",
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
            let ms = DurationFormatter.milliseconds(elapsed)
            STTDiagnosticsLog.shared.record(STTBackendDiagnosticEntry(
                taskId: taskId,
                backend: .sfSpeechRecognizer,
                locale: locale.identifier,
                assetState: nil,
                audioFormat: nil,
                fallbackReason: "server recognition (on-device failed)",
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
            STTConsoleLog("[MemoraSTT] SFSpeechRecognizer 利用不可 — locale: \(locale.identifier)")
            throw CoreError.transcriptionError(.engineNotAvailable)
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = forceOnDevice
        request.contextualStrings = STTLocalProcessingSettings.contextualVocabulary
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        STTConsoleLog("[MemoraSTT] SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: \(forceOnDevice)")
        DebugLogger.shared.addLog("STTBackend", "SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: \(forceOnDevice)", level: .info)
        progress(0.2)

        // DispatchWorkItem ベースのタイムアウト: withCheckedThrowingContinuation は
        // Task キャンセルに対応しないため、タイマーで直接 continuation を resume する
        let timeoutSeconds: TimeInterval = forceOnDevice ? 30 : 60

        let recognitionResult = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            let callbackLock = NSLock()
            var didResume = false

            // タイムアウトタイマー: 指定秒数内に結果が来なければ continuation を resume
            let timeoutWorkItem = DispatchWorkItem(qos: .userInitiated) { [weak self] in
                callbackLock.lock()
                let shouldResume = !didResume
                didResume = true
                callbackLock.unlock()
                guard shouldResume else { return }
                STTConsoleLog("[MemoraSTT] SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: \(forceOnDevice)")
                DebugLogger.shared.addLog("STTBackend", "SFSpeechRecognizer タイムアウト (\(timeoutSeconds)s) — onDevice: \(forceOnDevice)", level: .warning)
                self?.cancelRecognitionTask()
                continuation.resume(throwing: OnDeviceTranscriptionTimeoutError())
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + timeoutSeconds,
                execute: timeoutWorkItem
            )

            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                // 成功またはエラー時はタイマーをキャンセル
                timeoutWorkItem.cancel()
                
                // タイムアウト/キャンセル確定後のコールバックは partial を含め一切処理しない
                callbackLock.lock()
                let alreadyResumed = didResume
                callbackLock.unlock()
                if alreadyResumed { return }
                

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

                guard let result else { return }

                // volatile（中間結果）
                if !result.isFinal {
                    partialResult(result.bestTranscription.formattedString)
                    return
                }

                // final（確定結果）
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

        progress(0.92)
        DebugLogger.shared.addLog("STTBackend", "SFSpeechRecognizer 認識完了 — \(recognitionResult.bestTranscription.segments.count)セグメント", level: .info)

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
        partialResult: @escaping @Sendable (String) -> Void,
        forceOnDevice: Bool = true
    ) async throws -> TranscriptionResult {
        // タイムアウトは transcribeWithSpeechRecognizer 内の DispatchWorkItem で処理
        try await transcribeWithSpeechRecognizer(
            audioURL: audioURL,
            locale: locale,
            progress: progress,
            partialResult: partialResult,
            forceOnDevice: forceOnDevice
        )
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzerWithTimeout(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        // continuation + DispatchWorkItem でタイムアウトを実装。
        // withThrowingTaskGroup は全子タスク完了を待つため、
        // detectSpeakers が非協力的だとタイムアウトが効かない。
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<TranscriptionResult, Error>) in
            let callbackLock = NSLock()
            var didResume = false

            let transcriptionTask = Task {
                try await self.transcribeWithSpeechAnalyzer(
                    audioURL: audioURL,
                    locale: locale,
                    progress: progress,
                    partialResult: partialResult
                )
            }

            // 60秒タイムアウト
            let timeoutWorkItem = DispatchWorkItem(qos: .userInitiated) {
                callbackLock.lock()
                let shouldResume = !didResume
                didResume = true
                callbackLock.unlock()
                if shouldResume {
                    transcriptionTask.cancel()
                    DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer 60秒タイムアウト", level: .warning)
                    continuation.resume(throwing: OnDeviceTranscriptionTimeoutError())
                }
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + 60,
                execute: timeoutWorkItem
            )

            Task {
                do {
                    let result = try await transcriptionTask.value
                    timeoutWorkItem.cancel()
                    callbackLock.lock()
                    let shouldResume = !didResume
                    didResume = true
                    callbackLock.unlock()
                    if shouldResume {
                        continuation.resume(returning: result)
                    }
                } catch {
                    timeoutWorkItem.cancel()
                    callbackLock.lock()
                    let shouldResume = !didResume
                    didResume = true
                    callbackLock.unlock()
                    if shouldResume {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    @available(iOS 26.0, *)
    private func transcribeWithSpeechAnalyzer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        STTConsoleLog("[MemoraSTT] transcribeWithSpeechAnalyzer 開始")
        DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer transcribe 開始 — \(audioURL.lastPathComponent)", level: .info)
        let service = SpeechAnalyzerService26(locale: locale)

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        STTConsoleLog("[MemoraSTT] transcribeWithSpeechAnalyzer: SpeechAnalyzerService26 完了 — \(text.count)文字")
        DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer transcribe 完了 — \(text.count)文字", level: .info)
        partialResult(text)
        progress(0.92)

        let duration = await audioFileDuration(for: audioURL)
        STTConsoleLog("[MemoraSTT] transcribeWithSpeechAnalyzer: duration=\(duration)s")
        DebugLogger.shared.addLog("STTBackend", "SpeechAnalyzer duration=\(String(format: "%.1f", duration))s, セグメント生成完了", level: .info)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)

        let result = TranscriptionResult(
            fullText: text,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: baseSegments
        )
        STTConsoleLog("[MemoraSTT] transcribeWithSpeechAnalyzer: TranscriptionResult 生成完了")
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

        STTConsoleLog("[MemoraSTT] API パス開始 — provider: \(configuration.provider.rawValue)")
        DebugLogger.shared.addLog("STTBackend", "API パス開始 — provider: \(configuration.provider.rawValue)", level: .info)
        let remoteStart = ContinuousClock.now

        let service = AIService()
        service.setProvider(configuration.provider)
        service.setTranscriptionMode(.api)
        try await service.configure(apiKey: configuration.apiKey)

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        progress(0.92)

        STTConsoleLog("[MemoraSTT] API パス完了 — text length: \(text.count)")
        DebugLogger.shared.addLog("STTBackend", "API パス完了 — \(text.count)文字", level: .info)

        let duration = await audioFileDuration(for: audioURL)
        let baseSegments = makeFallbackSegments(from: text, duration: duration)

        let elapsed = remoteStart.duration(to: ContinuousClock.now)
        let ms = DurationFormatter.milliseconds(elapsed)
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
}

final class STTService: STTServiceProtocol, @unchecked Sendable {
    private let stateLock = NSLock()
    private let configurationLock = NSLock()

    private let postProcessor = TranscriptPostProcessor()
    private var activeTasks: [String: STTTaskHandle] = [:]
    private var configuration = STTExecutionConfiguration.localDefault
    private var backgroundTaskIdentifiers: [String: UIBackgroundTaskIdentifier] = [:]
    /// Plaud 等の参照データから抽出した話者数ヒント。
    /// 文字起こし時の話者分離で numSpeakers として使用。
    var referenceSpeakerCount: Int?
    /// メモリ警告時に API 並列度を 4→1 に下げるフラグ（PR-B11）
    private var underMemoryPressure = false


    /// isIdleTimerDisabled の参照カウント。複数タスク同時実行時に
    /// 先に終わったタスクが画面ロック抑止を解除してしまう問題を防ぐ。
    private var idleTimerHoldCount = 0
    private let readiness: STTReadinessProtocol
    private let chunkerFactory: @Sendable () -> AudioChunkerProtocol
    private let diarizationService: SpeakerDiarizationProtocol = {
        if #available(macOS 14.0, iOS 17.0, *) {
            return FluidAudioDiarizationService()
        } else {
            return SpeakerDiarizationService()
        }
    }()

    init(
        readiness: STTReadinessProtocol = STTReadiness(),
        chunkerFactory: @escaping @Sendable () -> AudioChunkerProtocol = { AudioChunker() }
    ) {
        self.readiness = readiness
        self.chunkerFactory = chunkerFactory

        // メモリ警告時の observer を登録（PR-B11: 並列度を自動で下げる）
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.underMemoryPressure = true
            DebugLogger.shared.addLog("STTService", "メモリ警告受信 — 並列度を下げます", level: .warning)
        }
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
            transcriptionMode: transcriptionMode,
            allowsSpeechAnalyzer: SpeechAnalyzerFeatureFlag.isEnabled
        )
        configurationLock.unlock()
    }


    /// 文字起こし開始前の事前見積もり（PR-B11）。
    /// plan() から総時間・チャンク数・概算処理時間を返す。
    /// 長時間ファイルの確認ダイアログ表示に使う。
    func estimateTranscription(
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

    @MainActor
    private func acquireIdleTimerHold() {
        idleTimerHoldCount += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    @MainActor
    private func releaseIdleTimerHold() {
        idleTimerHoldCount = max(0, idleTimerHoldCount - 1)
        if idleTimerHoldCount == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
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
        DebugLogger.shared.addLog("STTService", "startTranscription — handle 作成: \(handle.taskId), mode: \(configuration.transcriptionMode.rawValue)", level: .info)

        // バックグラウンドタスクを登録: アプリがバックグラウンドに移行しても文字起こしを継続
        // 画面自動ロックを防止: 文字起こし中は画面を点灯したままにする
        await MainActor.run { self.acquireIdleTimerHold() }
        let bgId = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(
                withName: "MemoraSTT-\(handle.taskId)"
            ) { [weak self, weak handle] in
                DebugLogger.shared.addLog("STTService", "backgroundTask 期限切れ — タスクをキャンセル: \(handle?.taskId ?? "?")", level: .warning)
                Task { [weak self, weak handle] in
                    await handle?.cancel()
                    await self?.endBackgroundTaskOnMain(taskId: handle?.taskId)
                }
            }
        }
        if bgId != .invalid {
            stateLock.lock()
            backgroundTaskIdentifiers[handle.taskId] = bgId
            stateLock.unlock()
            DebugLogger.shared.addLog("STTService", "beginBackgroundTask 登録: \(handle.taskId)", level: .info)
        }

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
                STTConsoleLog("[MemoraSTT] バックグラウンドタスクエラー: \(error.localizedDescription)")
            }
            self?.removeTask(taskId: handle.taskId)
            await self?.endBackgroundTaskOnMain(taskId: handle.taskId)
            await MainActor.run { self?.releaseIdleTimerHold() }
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

        STTConsoleLog("[MemoraSTT] runTask 開始 — taskId: \(handle.taskId), url: \(handle.audioURL.lastPathComponent)")
        DebugLogger.shared.addLog("STTService", "runTask 開始 — taskId: \(handle.taskId), url: \(handle.audioURL.lastPathComponent)", level: .info)

        do {
            STTConsoleLog("[MemoraSTT] runTask: .transcriptionStarted を yield")
            DebugLogger.shared.addLog("STTService", "yield .transcriptionStarted", level: .info)
            handle.yield(.transcriptionStarted(taskId: handle.taskId))
            STTConsoleLog("[MemoraSTT] runTask: .transcriptionProgress(0.02) を yield")
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 0.02))

            // plan: ファイル書き出しなしでチャンク境界を計算（軽量）
            let plan = try await chunker.plan(fileURL: handle.audioURL)
            let totalChunks = max(plan.count, 1)

            STTConsoleLog("[MemoraSTT] runTask: チャンク計画 \(plan.count)（遅延生成）")
            DebugLogger.shared.addLog("STTService", "チャンク計画: \(plan.count)（遅延生成）", level: .info)

            let processingConfiguration = configuration
            let progressThrottler = STTProgressThrottler.forTranscription(
                mode: processingConfiguration.transcriptionMode,
                totalChunks: totalChunks
            )

            // Live Activity 開始（Dynamic Island / ロック画面に進捗表示）
            await MainActor.run {
                TranscriptionLiveActivity.start(
                    fileName: handle.audioURL.lastPathComponent,
                    totalChunks: totalChunks
                )
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
                    totalChunks: totalChunks
                )
            } else {
                // 直列経路: 1チャンクずつ export → transcribe → append → cleanup
                for slice in plan.slices {
                    try Task.checkCancellation()

                    DebugLogger.shared.addLog("STTService", "chunk \(slice.index)/\(plan.count) 開始", level: .info)
                    handle.yield(.audioChunkStarted(chunkIndex: slice.index))

                    let chunk = try await chunker.exportSlice(slice, from: plan)

                    let engine = STTBackendExecutor(
                        taskId: "\(handle.taskId)-chunk-\(slice.index)",
                        configuration: processingConfiguration
                    )
                    let result = try await engine.transcribe(
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

                    merger.append(chunk: chunk, result: result)
                    // 処理済みチャンクの一時ファイルを即削除（メモリ&ディスク解放）
                    await chunker.cleanupChunk(chunk)

                    STTConsoleLog("[MemoraSTT] runTask: chunk \(slice.index) 完了 — text: \(result.fullText.prefix(40))")
                    DebugLogger.shared.addLog("STTService", "chunk \(slice.index) 完了 — \(result.fullText.count)文字", level: .info)
                    handle.yield(.audioChunkCompleted(chunkIndex: slice.index, result: result))

                    // Live Activity 進捗更新
                    let overallProgress = 0.12 + (0.78 * Double(slice.index + 1) / Double(totalChunks))
                    if progressThrottler.shouldUpdateLiveActivity(completedChunkCount: slice.index + 1, totalChunks: totalChunks) {
                        await MainActor.run {
                            TranscriptionLiveActivity.update(
                                progress: overallProgress,
                                currentChunk: slice.index + 1,
                                totalChunks: totalChunks
                            )
                        }
                    }
                }
            }

            let mergedResult = postProcessor.process(merger.finalize(preferredLanguage: handle.language))
            STTConsoleLog("[MemoraSTT] runTask: merge 完了 — \(mergedResult.fullText.count)文字, \(mergedResult.segments.count)セグメント")
            DebugLogger.shared.addLog("STTService", "merge 完了 — \(mergedResult.fullText.count)文字, \(mergedResult.segments.count)セグメント", level: .info)

            // 話者分離は有料/API モードで明示的に有効化された場合だけ実行する。
            // ローカル処理では常にスキップし、文字起こし完了までの時間と電池消費を抑える。
            handle.yield(.transcriptionProgress(taskId: handle.taskId, progress: 0.92))
            let shouldRunSpeakerDiarization = processingConfiguration.transcriptionMode == .api
                && STTLocalProcessingSettings.isSpeakerDiarizationEnabled
            let finalSegments: [TranscriptionSegment]
            if shouldRunSpeakerDiarization {
                finalSegments = await detectSpeakersWithTimeout(
                    audioURL: handle.audioURL,
                    segments: mergedResult.segments,
                    numSpeakers: referenceSpeakerCount
                )
            } else {
                DebugLogger.shared.addLog(
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
            STTConsoleLog("[MemoraSTT] runTask: .transcriptionCompleted を yield — \(finalResult.fullText.count)文字")
            handle.yield(.transcriptionCompleted(taskId: handle.taskId, result: finalResult))
            STTConsoleLog("[MemoraSTT] runTask: .transcriptionCompleted yield 完了")
            DebugLogger.shared.addLog("STTService", "yield .transcriptionCompleted — finish() 呼び出し", level: .info)
            handle.finish()
            // Live Activity 終了（成功）
            await MainActor.run {
                TranscriptionLiveActivity.finish(
                    success: true,
                    characterCount: finalResult.fullText.count
                )
            }
            STTConsoleLog("[MemoraSTT] runTask: finish() 完了")
            return finalResult
        } catch is CancellationError {
            DebugLogger.shared.addLog("STTService", "runTask cancelled — taskId: \(handle.taskId)", level: .warning)
            handle.yield(.transcriptionCancelled(taskId: handle.taskId))
            handle.finish()
            await MainActor.run { TranscriptionLiveActivity.finish(success: false, characterCount: 0) }
            throw CancellationError()
        } catch let coreError as CoreError {
            DebugLogger.shared.addLog("STTService", "runTask CoreError — taskId: \(handle.taskId): \(coreError.localizedDescription)", level: .error)
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: coreError))
            handle.finish()
            await MainActor.run { TranscriptionLiveActivity.finish(success: false, characterCount: 0) }
            throw coreError
        } catch {
            let mappedError = STTErrorMapper.mapToCoreError(error)
            DebugLogger.shared.addLog("STTService", "runTask error — taskId: \(handle.taskId): \(error.localizedDescription)", level: .error)
            handle.yield(.transcriptionFailed(taskId: handle.taskId, error: mappedError))
            handle.finish()
            await MainActor.run { TranscriptionLiveActivity.finish(success: false, characterCount: 0) }
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
        totalChunks: Int
    ) async throws {
        DebugLogger.shared.addLog("STTService", "並列チャンク処理開始 — \(plan.count)チャンク（ストリーミング）", level: .info)

        let maxConcurrentChunks = underMemoryPressure ? 1 : min(4, max(1, plan.count))
        let sliceBatches = plan.slices.chunked(into: maxConcurrentChunks)
        var completedCount = 0

        for batch in sliceBatches {
            // 1. バッチ分のチャンクを export（遅延生成）
            let chunks: [(Int, AudioChunk)] = try await withThrowingTaskGroup(
                of: (Int, AudioChunk).self
            ) { group in
                for slice in batch {
                    group.addTask {
                        let chunk = try await chunker.exportSlice(slice, from: plan)
                        return (slice.index, chunk)
                    }
                }
                var acc: [(Int, AudioChunk)] = []
                for try await r in group { acc.append(r) }
                return acc.sorted { $0.0 < $1.0 }
            }

            // 2. 並列で文字起こし
            let results: [(Int, TranscriptionResult)] = try await withThrowingTaskGroup(
                of: (Int, TranscriptionResult).self
            ) { group in
                for (index, chunk) in chunks {
                    group.addTask {
                        let engine = STTBackendExecutor(
                            taskId: "\(handle.taskId)-chunk-\(index)",
                            configuration: configuration
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
                var acc: [(Int, TranscriptionResult)] = []
                for try await r in group { acc.append(r) }
                return acc.sorted { $0.0 < $1.0 }
            }

            // 3. 結果を merger に逐次追加 + 進捗更新 + cleanup
            for (i, (index, result)) in results.enumerated() {
                let chunk = chunks.first(where: { $0.0 == index })!.1
                merger.append(chunk: chunk, result: result)
                completedCount += 1
                let overall = 0.12 + (0.78 * Double(completedCount) / Double(totalChunks))
                handle.yield(.transcriptionProgress(
                    taskId: handle.taskId,
                    progress: overall
                ))
                handle.yield(.audioChunkCompleted(
                    chunkIndex: index,
                    result: result
                ))
                await MainActor.run {
                    TranscriptionLiveActivity.update(
                        progress: overall,
                        currentChunk: completedCount,
                        totalChunks: totalChunks
                    )
                }
                DebugLogger.shared.addLog(
                    "STTService",
                    "並列 chunk \(index) 完了 — \(result.fullText.count)文字",
                    level: .info
                )
            }

            // 4. バッチ分の一時ファイルを削除
            for (_, chunk) in chunks {
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

    private func removingSpeakerLabels(from segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
        segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                speakerLabel: "",
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: segment.text
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

    private func endBackgroundTaskOnMain(taskId: String?) async {
        guard let taskId else { return }
        let bgId: UIBackgroundTaskIdentifier? = {
            stateLock.lock()
            defer { stateLock.unlock() }
            return backgroundTaskIdentifiers.removeValue(forKey: taskId)
        }()
        guard let bgId, bgId != .invalid else { return }
        await MainActor.run {
            UIApplication.shared.endBackgroundTask(bgId)
        }
        DebugLogger.shared.addLog("STTService", "endBackgroundTask: \(taskId)", level: .info)
    }

    /// FluidAudio（CoreML / ANE）による全体ファイル話者分離。
    /// 指定秒数でタイムアウトし、フォールバックとして元セグメントを返す。
    private func detectSpeakersWithTimeout(
        audioURL: URL,
        segments: [TranscriptionSegment],
        numSpeakers: Int? = nil,
        timeout: TimeInterval = 300
    ) async -> [TranscriptionSegment] {
        DebugLogger.shared.addLog("STTService", "全体ファイル話者分離開始 — \(segments.count)セグメント, numSpeakers: \(numSpeakers?.description ?? "auto"), timeout: \(timeout)s", level: .info)
        let result = await withTimeout(seconds: timeout) {
            await self.diarizationService.detectSpeakers(audioURL: audioURL, segments: segments, numSpeakers: numSpeakers)
        }
        switch result {
        case .success(let speakers):
            DebugLogger.shared.addLog("STTService", "全体ファイル話者分離完了 — \(speakers.count)セグメント", level: .info)
            return speakers
        case .timedOut:
            DebugLogger.shared.addLog("STTService", "全体ファイル話者分離タイムアウト (\(timeout)s)", level: .warning)
            return segments
        }
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async -> T
    ) async -> TimeoutResult<T> {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var completed = false

            let task = Task {
                let result = await operation()
                lock.lock()
                guard !completed else {
                    lock.unlock()
                    return
                }
                completed = true
                lock.unlock()
                continuation.resume(returning: .success(result))
            }

            _ = Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                lock.lock()
                guard !completed else {
                    lock.unlock()
                    return
                }
                completed = true
                lock.unlock()
                task.cancel()
                continuation.resume(returning: .timedOut)
            }
        }
    }

    private enum TimeoutResult<T> {
        case success(T)
        case timedOut
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
