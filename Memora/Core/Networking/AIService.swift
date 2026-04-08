import Foundation
import Speech

// Core transcription/API boundary. Keep backend selection changes intentional and isolated.

// MARK: - Local Transcription Protocol

protocol LocalTranscriptionService {
    var isTranscribing: Bool { get }
    var progress: Double { get }

    func transcribe(audioURL: URL) async throws -> String
}

// MARK: - Local Transcription Services

// iOS 26.0+ SpeechAnalyzer API 実装
@available(iOS 26.0, *)
final class SpeechAnalyzerService26: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var formatConverter: AVAudioConverter?
    private var compatibleFormats: [AVAudioFormat] = []
    private let locale: Locale

    init(locale: Locale = Locale(identifier: "ja_JP")) {
        self.locale = locale
    }

    private func setup() async throws {
        let installedLocales = await SpeechTranscriber.installedLocales
        print("インストール済みロケール: \(installedLocales)")

        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            print("ロケール \(locale.identifier) が利用可能ではありません")
            throw LocalTranscriptionError.localeNotSupported
        }

        let transcriptionPreset = SpeechTranscriber.Preset.transcription
        let createdTranscriber = SpeechTranscriber(locale: supportedLocale, preset: transcriptionPreset)
        try await ensureAssetsInstalled(for: createdTranscriber, locale: supportedLocale)
        transcriber = createdTranscriber
        print("使用ロケール: \(supportedLocale)")

        let formats = await createdTranscriber.availableCompatibleAudioFormats
        compatibleFormats = formats
        print("[MemoraSTT] SpeechAnalyzer compatible formats: \(formats.map { String(describing: $0) }.joined(separator: ", "))")

        let options = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .whileInUse
        )
        analyzer = SpeechAnalyzer(modules: [createdTranscriber], options: options)
    }

    private func ensureAssetsInstalled(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let initialStatus = await AssetInventory.status(forModules: [transcriber])
        print("SpeechAnalyzer asset status[\(locale.identifier)]: \(String(describing: initialStatus))")

        if initialStatus == .installed {
            return
        }

        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            let latestStatus = await AssetInventory.status(forModules: [transcriber])
            if latestStatus == .installed {
                return
            }
            throw LocalTranscriptionError.assetInstallationFailed(
                "SpeechAnalyzer 用モデルの取得要求を作成できませんでした"
            )
        }

        print("SpeechAnalyzer 用モデルを自動ダウンロードします: \(locale.identifier)")
        progress = 0.05

        do {
            try await request.downloadAndInstall()
        } catch {
            throw LocalTranscriptionError.assetInstallationFailed(error.localizedDescription)
        }

        let finalStatus = await AssetInventory.status(forModules: [transcriber])
        print("SpeechAnalyzer asset status after install[\(locale.identifier)]: \(String(describing: finalStatus))")

        guard finalStatus == .installed else {
            throw LocalTranscriptionError.assetInstallationFailed(
                "SpeechAnalyzer 用モデルのインストール完了を確認できませんでした"
            )
        }

        progress = 0.15
    }

    deinit {
        formatConverter = nil
    }

    /// ソースフォーマットと SpeechAnalyzer 互換フォーマットを比較し、
    /// 直接互換ならそのまま、非互換なら変換先フォーマットとコンバータを返す。
    private func resolveTargetFormat(sourceFormat: AVAudioFormat) throws -> (AVAudioFormat, AVAudioConverter?) {
        // 完全一致チェック（sampleRate / channelCount / commonFormat）
        if compatibleFormats.contains(where: { fmt in
            fmt.sampleRate == sourceFormat.sampleRate &&
            fmt.channelCount == sourceFormat.channelCount &&
            fmt.commonFormat == sourceFormat.commonFormat
        }) {
            return (sourceFormat, nil)
        }

        // 同じサンプルレートを優先、なければ最初の互換フォーマットを選択
        let bestMatch = compatibleFormats.first { fmt in
            fmt.sampleRate == sourceFormat.sampleRate
        } ?? compatibleFormats.first

        guard let targetFormat = bestMatch else {
            print("[MemoraSTT] No compatible format available for source: \(sourceFormat)")
            throw LocalTranscriptionError.notSupported
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            print("[MemoraSTT] Cannot create AVAudioConverter: \(sourceFormat) → \(targetFormat)")
            throw LocalTranscriptionError.transcriptionFailed(
                NSError(domain: "MemoraSTT", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Cannot convert audio format for SpeechAnalyzer"
                ])
            )
        }

        return (targetFormat, converter)
    }

    func transcribe(audioURL: URL) async throws -> String {
        isTranscribing = true
        progress = 0.0

        do {
            try await setup()
            guard let analyzer = analyzer else {
                throw LocalTranscriptionError.notSupported
            }

            // 音声ファイルをロード
            let audioFile = try AVAudioFile(forReading: audioURL)
            let sourceFormat = audioFile.processingFormat

            // フォーマット互換性チェック
            let (targetFormat, converter) = try resolveTargetFormat(sourceFormat: sourceFormat)
            formatConverter = converter

            if converter != nil {
                print("[MemoraSTT] Audio format conversion needed: \(sourceFormat) → \(targetFormat)")
            } else {
                print("[MemoraSTT] Audio format directly compatible: \(sourceFormat)")
            }

            // 準備（互換フォーマットで呼び出し）
            try await analyzer.prepareToAnalyze(in: targetFormat)

            progress = 0.3

            // TaskGroup を使用して並列実行
            return try await withThrowingTaskGroup(of: (analysisDone: Bool, transcript: String).self) { group in
                // 結果収集タスク
                group.addTask { [weak self] in
                    guard let self = self else { throw LocalTranscriptionError.notSupported }
                    guard let transcriber = self.transcriber else { throw LocalTranscriptionError.notSupported }
                    var parts: [String] = []
                    for try await result in transcriber.results {
                        let text = result.text.description
                        if !text.isEmpty {
                            parts.append(text)
                        }
                    }
                    return (false, parts.joined(separator: "\n"))
                }

                // 分析実行タスク
                group.addTask {
                    let audioSequence = AudioFileAsyncSequence(audioFile: audioFile, targetFormat: targetFormat, converter: converter)
                    try await analyzer.start(inputSequence: audioSequence)
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    return (true, "")
                }

                // セーフティタイムアウト: 結果収集がハングした場合の保護
                group.addTask {
                    try await Task.sleep(nanoseconds: 45_000_000_000) // 45秒
                    print("[MemoraSTT] SpeechAnalyzer 結果収集セーフティタイムアウト")
                    return (true, "") // 分析完了シグナルとして扱い、ループを脱出
                }

                // 分析の完了を待つ
                var analysisDone = false
                var transcriptParts: [String] = []
                var analysisDoneReceived = 0

                for try await result in group {
                    if result.analysisDone {
                        analysisDoneReceived += 1
                        if analysisDoneReceived > 1 {
                            // 2回目の analysisDone = セーフティタイムアウトまたは重複
                            if transcriptParts.isEmpty {
                                print("[MemoraSTT] SpeechAnalyzer: 分析完了後も結果なし — 終了")
                            }
                            group.cancelAll()
                            break
                        }
                        analysisDone = true
                    } else {
                        transcriptParts.append(result.transcript)
                    }

                    // 分析完了かつ結果がある場合は完了
                    if analysisDone && !transcriptParts.isEmpty {
                        group.cancelAll()
                        break
                    }
                }

                await MainActor.run {
                    progress = 1.0
                    isTranscribing = false
                }

                let transcript = transcriptParts.joined(separator: "\n")
                return transcript.isEmpty ? "文字起こしの結果がありません" : transcript
            }
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw LocalTranscriptionError.transcriptionFailed(error)
        }
    }
}

// iOS 26.0+: AudioFile から AnalyzerInput の AsyncSequence を作成するヘルパー
@available(iOS 26.0, *)
struct AudioFileAsyncSequence: AsyncSequence {
    typealias Element = AnalyzerInput

    let audioFile: AVAudioFile
    let targetFormat: AVAudioFormat?
    let converter: AVAudioConverter?

    init(audioFile: AVAudioFile, targetFormat: AVAudioFormat? = nil, converter: AVAudioConverter? = nil) {
        self.audioFile = audioFile
        self.targetFormat = targetFormat
        self.converter = converter
    }

    func makeAsyncIterator() -> AsyncStream<AnalyzerInput>.Iterator {
        let sourceFormat = audioFile.processingFormat
        let tgtFormat = targetFormat
        let conv = converter

        print("[MemoraSTT] AudioFileAsyncSequence source format: \(sourceFormat)")

        return AsyncStream { continuation in
            Task {
                let frameCount: AVAudioFrameCount = 4096

                while true {
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
                        break
                    }

                    do {
                        try audioFile.read(into: buffer)
                    } catch {
                        print("[MemoraSTT] File read error: \(error)")
                        break
                    }

                    if buffer.frameLength == 0 {
                        break
                    }

                    let outputBuffer: AVAudioPCMBuffer
                    if let conv, let tgtFormat {
                        let ratio = tgtFormat.sampleRate / sourceFormat.sampleRate
                        let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
                        guard let converted = AVAudioPCMBuffer(pcmFormat: tgtFormat, frameCapacity: outputFrames) else {
                            print("[MemoraSTT] Failed to allocate conversion buffer")
                            break
                        }
                        var error: NSError?
                        let status = conv.convert(to: converted, error: &error) { inNumPackets, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        if status == .error {
                            print("[MemoraSTT] Format conversion error: \(error?.localizedDescription ?? "unknown")")
                            break
                        }
                        outputBuffer = converted
                    } else {
                        outputBuffer = buffer
                    }

                    let input = AnalyzerInput(buffer: outputBuffer)
                    continuation.yield(input)
                }

                continuation.finish()
            }
        }.makeAsyncIterator()
    }
}

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
                    self?.isTranscribing = false
                    self?.progressTimer?.invalidate()
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

            _ = recognizer.recognitionTask(with: request) { result, error in
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
                    self?.isTranscribing = false
                    self?.progressTimer?.invalidate()
                    self?.recognitionTask?.cancel()
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
    case local = "Local"

    var id: String { rawValue }

    var supportsTranscription: Bool {
        switch self {
        case .openai: return true
        case .gemini: return false
        case .deepseek: return false
        case .local: return false
        }
    }

    var transcriptionProvider: AIProvider? {
        switch self {
        case .openai: return .openai
        case .gemini: return nil
        case .deepseek: return nil
        case .local: return nil
        }
    }

    /// API キーが必要なプロバイダーか
    var requiresAPIKey: Bool {
        switch self {
        case .openai, .gemini, .deepseek: return true
        case .local: return false
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
            if #available(iOS 26.0, *) {
                return SpeechAnalyzerFeatureFlag.isEnabled
                    ? "iOS 26ネイティブ（SpeechAnalyzer・ベータ）"
                    : "ローカルモデル（SpeechRecognizer）"
            } else if #available(iOS 10.0, *) {
                return "ローカルモデル（SpeechRecognizer）"
            } else {
                return "非対応"
            }
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
    func generate(_ prompt: String) async throws -> String
}

// MARK: - Unified Service

final class AIService: AIServiceProtocol, ObservableObject {
    private var provider: AIProvider = .openai
    private var transcriptionMode: TranscriptionMode = .local
    private var openAIService: OpenAIService?
    private var geminiService: GeminiService?
    private var deepSeekService: DeepSeekService?
    private var localTranscriptionService: LocalTranscriptionService?

    /// LLMProvider 経由のプロバイダー（C2 追加）
    private var llmProvider: (any LLMProvider)?

    var currentProvider: AIProvider { provider }
    var currentTranscriptionMode: TranscriptionMode { transcriptionMode }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
    }

    func setTranscriptionMode(_ mode: TranscriptionMode) {
        self.transcriptionMode = mode
    }

    /// 外部から LLMProvider を注入する（C3/C4 で local provider を差し込む用）
    func setLLMProvider(_ provider: any LLMProvider) {
        self.llmProvider = provider
    }

    /// Gemma 4 実験プロファイルを有効化する。
    /// stable path (LocalLLMProvider) を上書きせず、独立スロットに注入する。
    func enableGemma4Experimental() {
        guard Gemma4ExperimentalProvider.isReady else { return }
        self.llmProvider = Gemma4ExperimentalProvider()
    }

    func configure(apiKey: String) async throws {
        switch provider {
        case .local:
            // Gemma 4 実験プロファイルが有効ならそちらを優先
            if Gemma4ExperimentalProvider.isReady {
                llmProvider = Gemma4ExperimentalProvider()
            } else {
                guard LocalLLMProvider.isAvailable else {
                    throw AIError.notConfigured
                }
                let localProvider = LocalLLMProvider()
                llmProvider = localProvider
            }
        case .openai:
            let service = OpenAIService(apiKey: apiKey)
            openAIService = service
            llmProvider = service
        case .gemini:
            let service = GeminiService(apiKey: apiKey)
            geminiService = service
            llmProvider = service
        case .deepseek:
            let service = DeepSeekService(apiKey: apiKey)
            deepSeekService = service
            llmProvider = service
        }

        // ローカル文字起こしの初期化
        if transcriptionMode == .local {
            if #available(iOS 26.0, *), SpeechAnalyzerFeatureFlag.isEnabled {
                localTranscriptionService = SpeechAnalyzerService26()
            } else if #available(iOS 10.0, *) {
                localTranscriptionService = SpeechAnalyzerService()
            }
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
        // LLMProvider 経由の統一路線（外部注入された provider があればそちらを優先）
        if let llmProvider {
            let result = try await llmProvider.summarize(transcript: transcript)
            return (result.summary, result.keyPoints, result.actionItems)
        }

        // フォールバック: 従来のサービス直呼び出し
        switch provider {
        case .local:
            throw AIError.notConfigured
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

    /// LLMProvider 経由でテキスト生成（AskAI などで使用）
    func generate(_ prompt: String) async throws -> String {
        guard let llmProvider else {
            throw AIError.notConfigured
        }
        return try await llmProvider.generate(prompt)
    }
}

// MARK: - OpenAI Service

final class OpenAIService: LLMProvider {
    let displayName = "OpenAI"
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
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
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw LLMProviderError.decodingError
        }
        return content
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
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

        return LLMProviderSummary(summary: summary, keyPoints: keyPoints, actionItems: actionItems)
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

final class GeminiService: LLMProvider {
    let displayName = "Gemini"
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
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
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = result.candidates.first?.content.parts.first?.text else {
            throw LLMProviderError.decodingError
        }
        return content
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {

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

final class DeepSeekService: LLMProvider {
    let displayName = "DeepSeek"
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private let session: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProvider

    func generate(_ prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
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
            throw LLMProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMProviderError.apiError(httpResponse.statusCode, errorString)
        }

        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        guard let content = result.choices.first?.message.content else {
            throw LLMProviderError.decodingError
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
    case assetInstallationFailed(String)

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
        case .assetInstallationFailed(let message):
            return "SpeechAnalyzer 用モデルの準備に失敗しました: \(message)"
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
