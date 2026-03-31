import Foundation
@preconcurrency import AVFoundation
import Speech

// Core transcription path. Do not modify without an explicit STT task.

@MainActor
private protocol TranscriptionEngineProtocol: Sendable {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func configure(
        apiKey: String,
        provider: AIProvider,
        transcriptionMode: TranscriptionMode
    ) async throws

    func transcribe(audioURL: URL) async throws -> TranscriptResult
    func transcribe(audioURL: URL, language: String?) async throws -> TranscriptResult
}

@MainActor
final class TranscriptionEngine: TranscriptionEngineProtocol, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private let sttService: STTServiceProtocol = STTService()
    private var provider: AIProvider = .openai
    private var transcriptionMode: TranscriptionMode = .local
    private var apiKey = ""
    private let diarizationService: SpeakerDiarizationProtocol = SpeakerDiarizationService()

    func configure(
        apiKey: String,
        provider: AIProvider = .openai,
        transcriptionMode: TranscriptionMode = .local
    ) async throws {
        if transcriptionMode == .api && apiKey.isEmpty {
            throw CoreError.transcriptionError(.transcriptionFailed("API key is missing"))
        }

        self.apiKey = apiKey
        self.provider = provider
        self.transcriptionMode = transcriptionMode
        (sttService as? STTService)?.updateConfiguration(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode
        )
    }

    func transcribe(audioURL: URL) async throws -> TranscriptResult {
        try await transcribe(audioURL: audioURL, language: nil)
    }

    func transcribe(audioURL: URL, language: String?) async throws -> TranscriptResult {
        isTranscribing = true
        progress = 0

        defer {
            isTranscribing = false
            progress = 0
        }

        let (_, events) = try await sttService.startTranscription(audioURL: audioURL, language: language)

        var finalResult: TranscriptionResult?

        for await event in events {
            switch event {
            case .transcriptionStarted:
                progress = max(progress, 0.02)
            case .transcriptionProgress(_, let value):
                progress = value
            case .transcriptionCompleted(_, let result):
                progress = 1.0
                finalResult = result
            case .transcriptionFailed(_, let error):
                throw error
            case .transcriptionCancelled:
                throw CancellationError()
            case .transcriptionPartialResult,
                 .audioChunkStarted,
                 .audioChunkProgress,
                 .audioChunkCompleted:
                continue
            }
        }

        guard let finalResult else {
            throw CoreError.transcriptionError(.transcriptionFailed("Transcription did not produce a result"))
        }

        return TranscriptResult(
            coreResult: finalResult,
            duration: await audioFileDuration(for: audioURL)
        )
    }

    private func audioFileDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }
}

final class InternalTranscriptionEngine {
    private let configuration: STTExecutionConfiguration
    private let stateLock = NSLock()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let diarizationService: SpeakerDiarizationProtocol

    init(configuration: STTExecutionConfiguration, diarizationService: SpeakerDiarizationProtocol) {
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
        let granted = await requestSpeechPermissionIfNeeded()
        guard granted else {
            throw CoreError.transcriptionError(.transcriptionFailed("Speech permission denied"))
        }

        let locale = localeForRecognition(language: language)
        print("[MemoraSTT] transcribeLocally — locale: \(locale.identifier), SpeechAnalyzer flag: \(SpeechAnalyzerFeatureFlag.isEnabled)")

        // SpeechAnalyzer は iOS 26 beta API。実機で EXC_BREAKPOINT が発生する場合があるため
        // フィーチャーフラグが明示的に ON の場合のみ試行する。
        #if !targetEnvironment(simulator)
        #if swift(>=6.2)
        if #available(iOS 26.0, *), SpeechAnalyzerFeatureFlag.isEnabled {
            print("[MemoraSTT] SpeechAnalyzer パスを試行中...")
            do {
                return try await transcribeWithSpeechAnalyzerWithTimeout(
                    audioURL: audioURL,
                    locale: locale,
                    progress: progress,
                    partialResult: partialResult
                )
            } catch {
                print("[MemoraSTT] SpeechAnalyzer fallback: \(error.localizedDescription)")
            }
        } else {
            if #available(iOS 26.0, *) {
                print("[MemoraSTT] SpeechAnalyzer スキップ — flag OFF またはシミュレータ")
            }
        }
        #endif
        #endif

        print("[MemoraSTT] SFSpeechRecognizer パスを使用")
        return try await transcribeWithSpeechRecognizer(
            audioURL: audioURL,
            locale: locale,
            progress: progress,
            partialResult: partialResult
        )
    }

    private func transcribeWithSpeechRecognizer(
        audioURL: URL,
        locale: Locale,
        progress: @escaping @Sendable (Double) -> Void,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptionResult {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            print("[MemoraSTT] SFSpeechRecognizer 利用不可 — locale: \(locale.identifier)")
            throw CoreError.transcriptionError(.engineNotAvailable)
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }

        print("[MemoraSTT] SFSpeechRecognizer 開始 — locale: \(locale.identifier), onDevice: true")
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

        // 基本セグメントを生成
        let baseSegments = recognitionResult.bestTranscription.segments.enumerated().map { index, segment in
            TranscriptionSegment(
                id: "segment-\(index)",
                speakerLabel: "Speaker 1", // 仮ラベル
                startSec: segment.timestamp,
                endSec: segment.timestamp + segment.duration,
                text: segment.substring
            )
        }

        // 話者分離を適用
        let segmentsWithSpeakers = await diarizationService.detectSpeakers(
            audioURL: audioURL,
            segments: baseSegments
        )

        return TranscriptionResult(
            fullText: recognitionResult.bestTranscription.formattedString,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: segmentsWithSpeakers
        )
    }

    // MARK: - SpeechAnalyzer (iOS 26+, gated by feature flag)

    #if swift(>=6.2)
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
                try await Task.sleep(nanoseconds: 120_000_000_000) // 120秒
                throw CancellationError()
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw CoreError.transcriptionError(.transcriptionFailed("SpeechAnalyzer produced no result"))
            }
            group.cancelAll()
            return result
        }
    }
    #endif

    #if swift(>=6.2)
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
        let segmentsWithSpeakers = await diarizationService.detectSpeakers(
            audioURL: audioURL,
            segments: baseSegments
        )

        return TranscriptionResult(
            fullText: text,
            language: STTLanguageNormalizer.baseLanguageCode(for: locale.identifier),
            segments: segmentsWithSpeakers
        )
    }
    #endif

    private func transcribeRemotely(
        audioURL: URL,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {
        guard !configuration.apiKey.isEmpty else {
            throw CoreError.transcriptionError(.transcriptionFailed("API key is missing"))
        }

        print("[MemoraSTT] API パス開始 — provider: \(configuration.provider.rawValue)")

        let service = AIService()
        service.setProvider(configuration.provider)
        service.setTranscriptionMode(.api)
        try await service.configure(apiKey: configuration.apiKey)

        progress(0.2)
        let text = try await service.transcribe(audioURL: audioURL)
        progress(0.92)

        print("[MemoraSTT] API パス完了 — text length: \(text.count)")

        let duration = await audioFileDuration(for: audioURL)

        // 基本セグメントを生成
        let baseSegments = makeFallbackSegments(from: text, duration: duration)

        // 話者分離を適用
        let segmentsWithSpeakers = await diarizationService.detectSpeakers(
            audioURL: audioURL,
            segments: baseSegments
        )

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
                speakerLabel: "Speaker 1", // 仮ラベル
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
