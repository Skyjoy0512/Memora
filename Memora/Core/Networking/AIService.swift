import Foundation
@preconcurrency import AVFoundation
import Speech

// Core transcription/API boundary. Keep backend selection changes intentional and isolated.

// MARK: - Local Transcription Protocol

protocol LocalTranscriptionService {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func transcribe(audioURL: URL) async throws -> String
}

// MARK: - Local Transcription Services

// iOS 26.0+ SpeechAnalyzer API 実装（Xcode 26 / Swift 6.2+ でのみコンパイル）
#if swift(>=6.2)
@available(iOS 26.0, *)
struct SpeechAnalyzerTimeIndexedSegment: Sendable, Equatable {
    let id: String
    let startSec: Double
    let endSec: Double
    let text: String
}

@available(iOS 26.0, *)
struct SpeechAnalyzerTranscriptionOutput: Sendable, Equatable {
    let fullText: String
    let segments: [SpeechAnalyzerTimeIndexedSegment]
}

@available(iOS 26.0, *)
enum SpeechAnalyzerError: LocalizedError {
    case localeUnavailable
    case assetUnavailable
    case prepareFailed(String)
    case runtimeFailure(String)

    var fallbackReason: SpeechAnalyzerFallbackReason {
        switch self {
        case .localeUnavailable:
            return .localeUnavailable
        case .assetUnavailable:
            return .assetUnavailable
        case .prepareFailed:
            return .prepareFailed
        case .runtimeFailure:
            return .runtimeFailure
        }
    }

    var errorDescription: String? {
        switch self {
        case .localeUnavailable:
            return "SpeechAnalyzer がこのロケールに対応していません"
        case .assetUnavailable:
            return "SpeechAnalyzer の必要な音声アセットが未導入です"
        case .prepareFailed(let message):
            return "SpeechAnalyzer の準備に失敗しました: \(message)"
        case .runtimeFailure(let message):
            return "SpeechAnalyzer の実行に失敗しました: \(message)"
        }
    }
}

@available(iOS 26.0, *)
private struct PreparedSpeechAnalyzerContext {
    let locale: Locale
    let analyzer: SpeechAnalyzer
    let transcriber: SpeechTranscriber
    let analyzerFormat: AVAudioFormat
}

@available(iOS 26.0, *)
final class SpeechAnalyzerService26: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    static func supportStatus(for locale: Locale) async -> SpeechAnalyzerSupportStatus {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return .localeUnavailable
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .timeIndexedProgressiveTranscription
        )
        let assetStatus = await AssetInventory.status(forModules: [transcriber])
        return assetStatus == .installed ? .available : .assetUnavailable
    }

    func transcribe(audioURL: URL) async throws -> String {
        let output = try await transcribe(
            audioURL: audioURL,
            locale: Locale(identifier: "ja_JP")
        )
        return output.fullText
    }

    func transcribe(
        audioURL: URL,
        locale: Locale,
        progress progressHandler: @escaping @Sendable (Double) -> Void = { _ in },
        partialResult: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> SpeechAnalyzerTranscriptionOutput {
        isTranscribing = true
        progress = 0.0

        do {
            let context = try await prepareContext(locale: locale, audioURL: audioURL)
            let audioFile = try AVAudioFile(forReading: audioURL)

            do {
                try await context.analyzer.prepareToAnalyze(in: context.analyzerFormat)
            } catch {
                throw SpeechAnalyzerError.prepareFailed(error.localizedDescription)
            }
            updateProgress(0.12, progressHandler: progressHandler)

            let resultsTask = Task {
                try await self.collectResults(
                    from: context.transcriber,
                    partialResult: partialResult
                )
            }

            let audioSequence = AudioFileAsyncSequence(
                audioFile: audioFile,
                targetFormat: context.analyzerFormat,
                onProgress: { sequenceProgress in
                    let normalizedProgress = 0.12 + (0.78 * sequenceProgress)
                    self.updateProgress(normalizedProgress, progressHandler: progressHandler)
                }
            )

            do {
                try await context.analyzer.start(inputSequence: audioSequence)
                try await context.analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                resultsTask.cancel()
                throw SpeechAnalyzerError.runtimeFailure(error.localizedDescription)
            }

            let output = try await resultsTask.value
            updateProgress(1.0, progressHandler: progressHandler)
            isTranscribing = false
            return output
        } catch let error as SpeechAnalyzerError {
            isTranscribing = false
            throw error
        } catch {
            isTranscribing = false
            throw SpeechAnalyzerError.runtimeFailure(error.localizedDescription)
        }
    }

    private func prepareContext(
        locale: Locale,
        audioURL: URL
    ) async throws -> PreparedSpeechAnalyzerContext {
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechAnalyzerError.localeUnavailable
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .timeIndexedProgressiveTranscription
        )

        let assetStatus = await AssetInventory.status(forModules: [transcriber])
        guard assetStatus == .installed else {
            throw SpeechAnalyzerError.assetUnavailable
        }

        let audioFile = try AVAudioFile(forReading: audioURL)
        let sourceFormat = audioFile.processingFormat
        let compatibleFormats = await transcriber.availableCompatibleAudioFormats
        let analyzerFormat = bestCompatibleAudioFormat(
            sourceFormat: sourceFormat,
            compatibleFormats: compatibleFormats
        )

        let options = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .whileInUse
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)

        return PreparedSpeechAnalyzerContext(
            locale: supportedLocale,
            analyzer: analyzer,
            transcriber: transcriber,
            analyzerFormat: analyzerFormat
        )
    }

    private func collectResults(
        from transcriber: SpeechTranscriber,
        partialResult: @escaping @Sendable (String) -> Void
    ) async throws -> SpeechAnalyzerTranscriptionOutput {
        var finalizedSegments: [SpeechAnalyzerTimeIndexedSegment] = []

        do {
            for try await result in transcriber.results {
                let text = normalizedText(result.text)
                guard !text.isEmpty else { continue }

                if result.isFinal {
                    let startSec = max(CMTimeGetSeconds(result.range.start), 0)
                    let endSec = max(CMTimeGetSeconds(CMTimeRangeGetEnd(result.range)), startSec)
                    finalizedSegments.append(
                        SpeechAnalyzerTimeIndexedSegment(
                            id: "speech-analyzer-\(finalizedSegments.count)",
                            startSec: startSec,
                            endSec: endSec,
                            text: text
                        )
                    )
                } else {
                    partialResult(text)
                }
            }
        } catch {
            throw SpeechAnalyzerError.runtimeFailure(error.localizedDescription)
        }

        let orderedSegments = finalizedSegments.sorted { lhs, rhs in
            if lhs.startSec == rhs.startSec {
                return lhs.endSec < rhs.endSec
            }
            return lhs.startSec < rhs.startSec
        }
        let fullText = orderedSegments
            .map(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fullText.isEmpty else {
            throw SpeechAnalyzerError.runtimeFailure("SpeechAnalyzer produced no final result")
        }

        return SpeechAnalyzerTranscriptionOutput(
            fullText: fullText,
            segments: orderedSegments
        )
    }

    private func bestCompatibleAudioFormat(
        sourceFormat: AVAudioFormat,
        compatibleFormats: [AVAudioFormat]
    ) -> AVAudioFormat {
        if let exactMatch = compatibleFormats.first(where: { format in
            isCompatible(sourceFormat: sourceFormat, targetFormat: format)
        }) {
            return exactMatch
        }

        return compatibleFormats.first ?? sourceFormat
    }

    private func isCompatible(
        sourceFormat: AVAudioFormat,
        targetFormat: AVAudioFormat
    ) -> Bool {
        sourceFormat.sampleRate == targetFormat.sampleRate &&
        sourceFormat.channelCount == targetFormat.channelCount &&
        sourceFormat.commonFormat == targetFormat.commonFormat &&
        sourceFormat.isInterleaved == targetFormat.isInterleaved
    }

    private func normalizedText(_ text: AttributedString) -> String {
        String(text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateProgress(
        _ value: Double,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) {
        let clamped = min(max(value, 0), 1)
        progress = clamped
        progressHandler(clamped)
    }
}

// iOS 26.0+: AudioFile から AnalyzerInput の AsyncSequence を作成するヘルパー
@available(iOS 26.0, *)
struct AudioFileAsyncSequence: AsyncSequence {
    typealias Element = AnalyzerInput

    let audioFile: AVAudioFile
    let targetFormat: AVAudioFormat
    let onProgress: (@Sendable (Double) -> Void)?

    func makeAsyncIterator() -> AsyncStream<AnalyzerInput>.Iterator {
        let sourceFormat = audioFile.processingFormat

        return AsyncStream { continuation in
            Task {
                do {
                    let frameCount: AVAudioFrameCount = 4096
                    let totalFrames = max(Double(audioFile.length), 1)
                    let needsConversion = !isCompatible(
                        sourceFormat: sourceFormat,
                        targetFormat: targetFormat
                    )
                    let converter = needsConversion
                        ? AVAudioConverter(from: sourceFormat, to: targetFormat)
                        : nil
                    var processedFrames: Int64 = 0

                    while true {
                        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
                            break
                        }

                        try audioFile.read(into: buffer)
                        let framesRead = buffer.frameLength

                        if framesRead == 0 {
                            break
                        }

                        processedFrames += Int64(framesRead)

                        let outputBuffer: AVAudioPCMBuffer
                        if let converter {
                            outputBuffer = try Self.convert(
                                buffer: buffer,
                                to: targetFormat,
                                using: converter
                            )
                        } else {
                            outputBuffer = buffer
                        }

                        let input = AnalyzerInput(buffer: outputBuffer)
                        continuation.yield(input)
                        onProgress?(min(Double(processedFrames) / totalFrames, 1))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }.makeAsyncIterator()
    }

    private func isCompatible(
        sourceFormat: AVAudioFormat,
        targetFormat: AVAudioFormat
    ) -> Bool {
        sourceFormat.sampleRate == targetFormat.sampleRate &&
        sourceFormat.channelCount == targetFormat.channelCount &&
        sourceFormat.commonFormat == targetFormat.commonFormat &&
        sourceFormat.isInterleaved == targetFormat.isInterleaved
    }

    private static func convert(
        buffer: AVAudioPCMBuffer,
        to targetFormat: AVAudioFormat,
        using converter: AVAudioConverter
    ) throws -> AVAudioPCMBuffer {
        let sampleRateRatio = targetFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCapacity = max(
            AVAudioFrameCount((Double(buffer.frameLength) * sampleRateRatio).rounded(.up)) + 32,
            1
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetFrameCapacity
        ) else {
            throw SpeechAnalyzerError.runtimeFailure("Failed to allocate converted audio buffer")
        }

        var conversionError: NSError?
        var consumedInput = false
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if consumedInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            consumedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            throw SpeechAnalyzerError.runtimeFailure(conversionError.localizedDescription)
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return convertedBuffer
        case .error:
            throw SpeechAnalyzerError.runtimeFailure("Audio conversion failed")
        @unknown default:
            throw SpeechAnalyzerError.runtimeFailure("Audio conversion returned an unknown status")
        }
    }
}
#endif

// iOS 10-25 用 SpeechRecognizer 実装
@available(iOS 10.0, *)
final class SpeechAnalyzerService: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))
    private var progressTimer: Timer?

    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = recognizer else {
            throw LocalTranscriptionError.notSupported
        }

        isTranscribing = true
        progress = 0.0

        startProgressMonitoring()

        do {
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true

            return try await withTaskCancellationHandler(
                operation: {
                    try await performTranscription(recognizer: recognizer, request: request)
                },
                onCancel: { [weak self] in
                    isTranscribing = false
                    progressTimer?.invalidate()
                }
            )
        } catch {
            isTranscribing = false
            progressTimer?.invalidate()
            throw LocalTranscriptionError.transcriptionFailed(error)
        }
    }

    private func performTranscription(recognizer: SFSpeechRecognizer, request: SFSpeechURLRecognitionRequest) async throws -> String {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            var finalResult: String = ""
            var lastProgress: Int = 0

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else { return }

                let currentLength = result.bestTranscription.formattedString.count
                let progressValue = min(Double(currentLength) / 100.0, 0.9)

                if currentLength > lastProgress {
                    self?.progress = progressValue
                    lastProgress = currentLength
                }

                if result.isFinal {
                    finalResult = result.bestTranscription.formattedString
                    continuation.resume(returning: finalResult)
                }
            }
        }
    }

    private func startProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing else { return }
            if self.progress < 0.9 {
                self.progress = min(self.progress + 0.01, 0.9)
            }
        }
    }
}

@available(iOS 10.0, *)
final class SpeechRecognizerService: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var progressTimer: Timer?
    private let locale = Locale(identifier: "ja_JP")

    init() {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    deinit {
        progressTimer?.invalidate()
        recognitionTask?.cancel()
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = recognizer else {
            throw LocalTranscriptionError.notSupported
        }

        isTranscribing = true
        progress = 0.0

        startProgressMonitoring()

        do {
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true

            return try await withTaskCancellationHandler(
                operation: {
                    try await performTranscription(recognizer: recognizer, request: request)
                },
                onCancel: { [weak self] in
                    isTranscribing = false
                    progressTimer?.invalidate()
                    recognitionTask?.cancel()
                }
            )
        } catch {
            isTranscribing = false
            progressTimer?.invalidate()
            throw LocalTranscriptionError.transcriptionFailed(error)
        }
    }

    private func performTranscription(recognizer: SFSpeechRecognizer, request: SFSpeechURLRecognitionRequest) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var lastProgress: Int = 0

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else { return }

                let currentLength = result.bestTranscription.formattedString.count
                let progressValue = min(Double(currentLength) / 100.0, 0.9)

                if currentLength > lastProgress {
                    self.progress = progressValue
                    lastProgress = currentLength
                }

                if result.isFinal {
                    let finalResult = result.bestTranscription.formattedString
                    continuation.resume(returning: finalResult)
                }
            }
        }
    }

    private func startProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isTranscribing else { return }
            if self.progress < 0.9 {
                self.progress = min(self.progress + 0.01, 0.9)
            }
        }
    }
}

// MARK: - Provider Types

enum AIProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case deepseek = "DeepSeek"

    var id: String { rawValue }

    var supportsTranscription: Bool {
        switch self {
        case .openai: return true
        case .gemini: return false
        case .deepseek: return false
        }
    }

    var transcriptionProvider: AIProvider? {
        switch self {
        case .openai: return .openai
        case .gemini: return nil
        case .deepseek: return nil
        }
    }
}

// MARK: - Transcription Mode

enum TranscriptionMode: String, CaseIterable, Identifiable {
    case local = "ローカル"
    case api = "API"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .local:
            #if swift(>=6.2)
            if #available(iOS 26.0, *) {
                return "iOS 26ネイティブ（SpeechAnalyzer 優先 / 自動フォールバック）"
            } else if #available(iOS 10.0, *) {
                return "ローカルモデル（SpeechRecognizer）"
            } else {
                return "非対応"
            }
            #else
            if #available(iOS 10.0, *) {
                return "ローカルモデル（SpeechRecognizer）"
            } else {
                return "非対応"
            }
            #endif
        case .api:
            return "クラウドAPI（選択したプロバイダー）"
        }
    }
}

// MARK: - Protocols

protocol AIServiceProtocol {
    func configure(apiKey: String) async throws
    func transcribe(audioURL: URL) async throws -> String
    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String])
}

// MARK: - Unified Service

final class AIService: AIServiceProtocol, ObservableObject {
    private var provider: AIProvider = .openai
    private var transcriptionMode: TranscriptionMode = .local
    private var openAIService: OpenAIService?
    private var geminiService: GeminiService?
    private var deepSeekService: DeepSeekService?
    private var localTranscriptionService: LocalTranscriptionService?

    var currentProvider: AIProvider { provider }
    var currentTranscriptionMode: TranscriptionMode { transcriptionMode }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    func setTranscriptionMode(_ mode: TranscriptionMode) {
        self.transcriptionMode = mode
    }

    func configure(apiKey: String) async throws {
        switch provider {
        case .openai:
            openAIService = OpenAIService(apiKey: apiKey)
        case .gemini:
            geminiService = GeminiService(apiKey: apiKey)
        case .deepseek:
            deepSeekService = DeepSeekService(apiKey: apiKey)
        }

        // ローカル文字起こしの初期化
        if transcriptionMode == .local {
            #if swift(>=6.2)
            if #available(iOS 26.0, *) {
                localTranscriptionService = SpeechAnalyzerService26()
            } else if #available(iOS 10.0, *) {
                localTranscriptionService = SpeechAnalyzerService()
            }
            #else
            if #available(iOS 10.0, *) {
                localTranscriptionService = SpeechAnalyzerService()
            }
            #endif
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        switch transcriptionMode {
        case .local:
            guard let service = localTranscriptionService else {
                throw AIError.notConfigured
            }
            return try await service.transcribe(audioURL: audioURL)

        case .api:
            guard let provider = provider.transcriptionProvider else {
                throw AIError.transcriptionNotSupported
            }

            switch provider {
            case .openai:
                guard let service = openAIService else { throw AIError.notConfigured }
                return try await service.transcribe(audioURL: audioURL)
            case .gemini:
                guard let service = geminiService else { throw AIError.notConfigured }
                return try await service.transcribe(audioURL: audioURL)
            case .deepseek:
                throw AIError.transcriptionNotSupported
            }
        }
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        switch provider {
        case .openai:
            guard let service = openAIService else { throw AIError.notConfigured }
            return try await service.summarize(transcript: transcript)
        case .gemini:
            guard let service = geminiService else { throw AIError.notConfigured }
            return try await service.summarize(transcript: transcript)
        case .deepseek:
            guard let service = deepSeekService else { throw AIError.notConfigured }
            return try await service.summarize(transcript: transcript)
        }
    }
}

// MARK: - OpenAI Service

final class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: "\(baseURL)/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add file parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw OpenAIError.apiError(httpResponse.statusCode, errorString)
            }
            throw OpenAIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        let prompt = """
        以下の会議 transcript から、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw OpenAIError.apiError(httpResponse.statusCode, errorString)
            }
            throw OpenAIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw OpenAIError.decodingError
        }

        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw OpenAIError.decodingError
        }

        return (summary, keyPoints, actionItems)
    }
}

// MARK: - Gemini Service

final class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    func transcribe(audioURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        let prompt = "この音声を文字起こししてください。会議の内容であれば、発言をそのままテキストとして出力してください。"

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        ["inline_data": [
                            "mime_type": "audio/mp4a",
                            "data": audioData.base64EncodedString()
                        ]]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "topK": 1,
                "topP": 1
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.decodingError
        }

        return content
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        let prompt = """
        以下の会議 transcript から、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "あなたは会議の文字起こしから要約を作成するアシスタントです。\n\n\(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 1,
                "topP": 1
            ]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw AIError.decodingError
        }

        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw AIError.decodingError
        }

        return (summary, keyPoints, actionItems)
    }
}

// MARK: - DeepSeek Service

final class DeepSeekService {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        let prompt = """
        以下の会議 transcript から、要約、重要ポイント、アクションアイテムを抽出してください。
        出力は以下のJSON形式で返してください：

        {
          "summary": "会議の要約",
          "keyPoints": ["重要ポイント1", "重要ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "あなたは会議の文字起こしから要約を作成するアシスタントです。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 2048
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                throw AIError.apiError(httpResponse.statusCode, errorString)
            }
            throw AIError.apiError(httpResponse.statusCode, "Unknown error")
        }

        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)

        guard let content = result.choices.first?.message.content else {
            throw AIError.decodingError
        }

        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let summaryData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = summaryData["summary"] as? String,
              let keyPoints = summaryData["keyPoints"] as? [String],
              let actionItems = summaryData["actionItems"] as? [String] else {
            throw AIError.decodingError
        }

        return (summary, keyPoints, actionItems)
    }
}

// MARK: - Error Types

enum LocalTranscriptionError: LocalizedError {
    case notSupported
    case transcriptionFailed(Error)
    case localeNotSupported
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "ローカル文字起こしはサポートされていません"
        case .transcriptionFailed(let error):
            return "文字起こしに失敗しました: \(error.localizedDescription)"
        case .localeNotSupported:
            return "この言語はサポートされていません"
        case .permissionDenied:
            return "音声認識の権限が許可されていません"
        }
    }
}

enum AIError: LocalizedError {
    case notConfigured
    case transcriptionNotSupported
    case apiKeyMissing
    case invalidResponse
    case decodingError
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AIサービスが設定されていません"
        case .transcriptionNotSupported:
            return "選択されたプロバイダーは文字起こしをサポートしていません"
        case .apiKeyMissing:
            return "APIキーが設定されていません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .decodingError:
            return "レスポンスの解析に失敗しました"
        case .apiError(let code, let message):
            return "APIエラー (\(code)): \(message)"
        }
    }
}

enum OpenAIError: LocalizedError {
    case invalidResponse
    case decodingError
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無効なレスポンスです"
        case .decodingError:
            return "レスポンスの解析に失敗しました"
        case .apiError(let code, let message):
            return "APIエラー (\(code)): \(message)"
        }
    }
}

// MARK: - Response Models

private struct TranscriptionResponse: Codable {
    let text: String
}

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct GeminiResponse: Codable {
    let candidates: [Candidate]

    struct Candidate: Codable {
        let content: Content
    }

    struct Content: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String?
    }
}

private struct DeepSeekResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
