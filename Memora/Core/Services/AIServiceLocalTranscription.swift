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
    private let locale: Locale

    init(locale: Locale = Locale(identifier: "ja_JP")) {
        self.locale = locale
    }

    private func setup() async throws {
        let installedLocales = await SpeechTranscriber.installedLocales
        STTConsoleLog("インストール済みロケール: \(installedLocales)")

        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            STTConsoleLog("ロケール \(locale.identifier) が利用可能ではありません")
            throw LocalTranscriptionError.localeNotSupported
        }

        // offlineTranscription: ファイル一括処理用（公式推奨）
        let createdTranscriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .transcription
        )
        try await ensureAssetsInstalled(for: createdTranscriber, locale: supportedLocale)
        transcriber = createdTranscriber
        STTConsoleLog("使用ロケール: \(supportedLocale)")

        let options = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .whileInUse
        )
        analyzer = SpeechAnalyzer(modules: [createdTranscriber], options: options)

        // 事前準備: 互換フォーマットを取得し prepareToAnalyze を呼ぶ
        let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [createdTranscriber])
        if let bestFormat {
            STTConsoleLog("[MemoraSTT] bestAvailableAudioFormat: \(bestFormat)")
            try await analyzer?.prepareToAnalyze(in: bestFormat)
        } else {
            STTConsoleLog("[MemoraSTT] bestAvailableAudioFormat returned nil")
        }
    }

    private func ensureAssetsInstalled(
        for transcriber: SpeechTranscriber,
        locale: Locale
    ) async throws {
        let initialStatus = await AssetInventory.status(forModules: [transcriber])
        STTConsoleLog("SpeechAnalyzer asset status[\(locale.identifier)]: \(String(describing: initialStatus))")

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

        STTConsoleLog("SpeechAnalyzer 用モデルを自動ダウンロードします: \(locale.identifier)")
        progress = 0.05

        do {
            try await request.downloadAndInstall()
        } catch {
            throw LocalTranscriptionError.assetInstallationFailed(error.localizedDescription)
        }

        let finalStatus = await AssetInventory.status(forModules: [transcriber])
        STTConsoleLog("SpeechAnalyzer asset status after install[\(locale.identifier)]: \(String(describing: finalStatus))")

        guard finalStatus == .installed else {
            throw LocalTranscriptionError.assetInstallationFailed(
                "SpeechAnalyzer 用モデルのインストール完了を確認できませんでした"
            )
        }

        progress = 0.15
    }

    func transcribe(audioURL: URL) async throws -> String {
        isTranscribing = true
        progress = 0.0

        do {
            try await setup()
            guard let analyzer, let transcriber else {
                throw LocalTranscriptionError.notSupported
            }

            // 音声ファイルをロード
            let audioFile = try AVAudioFile(forReading: audioURL)
            STTConsoleLog("[MemoraSTT] Audio file loaded: \(audioFile.length) frames, format: \(audioFile.processingFormat)")

            guard audioFile.length > 0 else {
                throw LocalTranscriptionError.transcriptionFailed(
                    NSError(domain: "MemoraSTT", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "Audio file has no audio data"
                    ])
                )
            }

            progress = 0.2
            STTConsoleLog("[MemoraSTT] SpeechAnalyzer: analyzeSequence(from:) 開始 (offlineTranscription)")

            // ★ 結果を並行で消費（これがないと結果が失われる）
            let resultsTask = Task<[String], Error> {
                var parts: [String] = []
                for try await result in transcriber.results {
                    // result.text は AttributedString 型。
                    // .description は属性辞書のデバッグ表現 "{}" を付けるため、
                    // .characters からプレーンテキストを抽出する。
                    let text = String(result.text.characters)
                    if !text.isEmpty {
                        parts.append(text)
                    }
                }
                return parts
            }

            // 音声投入（高レベルAPI: MP3 を直接渡す）
            do {
                if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                    STTConsoleLog("[MemoraSTT] analyzeSequence 完了 — finalizing through lastSample")
                    try await analyzer.finalizeAndFinish(through: lastSample)
                } else {
                    STTConsoleLog("[MemoraSTT] analyzeSequence returned nil — canceling")
                    await analyzer.cancelAndFinishNow()
                }
            } catch {
                STTConsoleLog("[MemoraSTT] analyzeSequence error: \(error)")
                resultsTask.cancel()
                throw LocalTranscriptionError.transcriptionFailed(error)
            }

            // 結果取得
            let transcriptParts = try await resultsTask.value
            let transcript = transcriptParts.joined(separator: "\n")

            await MainActor.run {
                progress = 1.0
                isTranscribing = false
            }

            if transcript.isEmpty {
                STTConsoleLog("[MemoraSTT] SpeechAnalyzer: 結果が空 — フォールバックへ")
                throw LocalTranscriptionError.transcriptionFailed(
                    NSError(domain: "MemoraSTT", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "SpeechAnalyzer produced no transcript"
                    ])
                )
            }

            STTConsoleLog("[MemoraSTT] SpeechAnalyzer: 文字起こし成功 (\(transcript.count)文字)")
            return transcript
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw LocalTranscriptionError.transcriptionFailed(error)
        }
    }
}

// iOS 26.0+: AudioFile から AnalyzerInput の AsyncSequence を作成するヘルパー
// 圧縮フォーマット（MP3, AAC/M4A）で AVAudioFile.read の2回目が nilError になる
// iOS 26 beta のバグを回避するため、ファイル全体を1回の read で取り込む。
@available(iOS 26.0, *)
struct AudioFileAsyncSequence: AsyncSequence {
    typealias Element = AnalyzerInput

    let audioFile: AVAudioFile
    let totalFrames: AVAudioFrameCount
    let targetFormat: AVAudioFormat?
    let converter: AVAudioConverter?

    init(audioFile: AVAudioFile, totalFrames: AVAudioFrameCount, targetFormat: AVAudioFormat? = nil, converter: AVAudioConverter? = nil) {
        self.audioFile = audioFile
        self.totalFrames = totalFrames
        self.targetFormat = targetFormat
        self.converter = converter
    }

    func makeAsyncIterator() -> AsyncStream<AnalyzerInput>.Iterator {
        let sourceFormat = audioFile.processingFormat
        let frames = totalFrames
        let tgtFormat = targetFormat
        let conv = converter

        STTConsoleLog("[MemoraSTT] AudioFileAsyncSequence source format: \(sourceFormat), totalFrames: \(frames)")

        return AsyncStream { continuation in
            Task {
                // ファイル全体を1回の read で取り込む（2回目以降の nilError を回避）
                guard frames > 0,
                      let fullBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames) else {
                    STTConsoleLog("[MemoraSTT] AudioFileAsyncSequence: buffer allocation failed for \(frames) frames")
                    continuation.finish()
                    return
                }

                do {
                    try audioFile.read(into: fullBuffer)
                } catch {
                    STTConsoleLog("[MemoraSTT] File read error (single-pass): \(error)")
                    continuation.finish()
                    return
                }

                guard fullBuffer.frameLength > 0 else {
                    STTConsoleLog("[MemoraSTT] AudioFileAsyncSequence: read returned 0 frames")
                    continuation.finish()
                    return
                }

                STTConsoleLog("[MemoraSTT] AudioFileAsyncSequence: read \(fullBuffer.frameLength) frames in single pass")

                // フォーマット変換（必要な場合）
                let outputBuffer: AVAudioPCMBuffer
                if let conv, let tgtFormat {
                    let ratio = tgtFormat.sampleRate / sourceFormat.sampleRate
                    let outputFrames = AVAudioFrameCount(Double(fullBuffer.frameLength) * ratio) + 1
                    guard let converted = AVAudioPCMBuffer(pcmFormat: tgtFormat, frameCapacity: outputFrames) else {
                        STTConsoleLog("[MemoraSTT] Failed to allocate conversion buffer")
                        continuation.finish()
                        return
                    }
                    var error: NSError?
                    let status = conv.convert(to: converted, error: &error) { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return fullBuffer
                    }
                    if status == .error {
                        STTConsoleLog("[MemoraSTT] Format conversion error: \(error?.localizedDescription ?? "unknown")")
                        continuation.finish()
                        return
                    }
                    outputBuffer = converted
                    STTConsoleLog("[MemoraSTT] Converted: \(fullBuffer.frameLength) → \(converted.frameLength) frames")
                } else {
                    outputBuffer = fullBuffer
                }

                // SpeechAnalyzer 向けに小さく分割して yield（1バッファだと処理が進まない）
                let chunkSize: AVAudioFrameCount = 4096
                var offset: AVAudioFrameCount = 0
                let totalOutputFrames = outputBuffer.frameLength

                while offset < totalOutputFrames {
                    let remaining = totalOutputFrames - offset
                    let count = Swift.min(chunkSize, remaining)
                    guard let chunk = AVAudioPCMBuffer(pcmFormat: outputBuffer.format, frameCapacity: count) else {
                        break
                    }

                    // PCM データをコピー
                    for ch in 0..<Int(outputBuffer.format.channelCount) {
                        guard let src = outputBuffer.floatChannelData?[ch],
                              let dst = chunk.floatChannelData?[ch] else { continue }
                        dst.initialize(from: src.advanced(by: Int(offset)), count: Int(count))
                    }
                    chunk.frameLength = count

                    continuation.yield(AnalyzerInput(buffer: chunk))
                    offset += count
                }

                STTConsoleLog("[MemoraSTT] AudioFileAsyncSequence: yielded \(offset)/\(totalOutputFrames) frames in \(Int(totalOutputFrames)/Int(chunkSize) + 1) chunks")
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

// MARK: - Host transcription presentation

extension TranscriptionMode {
    var description: String {
        switch self {
        case .local:
            if #available(iOS 26.0, *) {
                return STTReadOnlyHostDependencies.live.settings.isSpeechAnalyzerEnabled
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

/// AIService から物理分離した、STTのホスト側選択アダプタ。
/// 既存の SpeechAnalyzer → SFSpeech → API の選択責務はここに留める。
final class AIServiceTranscriptionService {
    private let dependencies: STTReadOnlyHostDependencies
    private let aiService = AIServiceHostService()
    private var provider: AIProvider = .openai
    private var transcriptionMode: TranscriptionMode = .local
    private var localTranscriptionService: LocalTranscriptionService?

    init(dependencies: STTReadOnlyHostDependencies = .live) {
        self.dependencies = dependencies
    }

    func setProvider(_ provider: AIProvider) {
        self.provider = provider
        aiService.setProvider(provider)
    }

    func setTranscriptionMode(_ mode: TranscriptionMode) {
        transcriptionMode = mode
    }

    func configure(apiKey: String) async throws {
        try await aiService.configure(apiKey: apiKey)

        if transcriptionMode == .local {
            if #available(iOS 26.0, *), dependencies.settings.isSpeechAnalyzerEnabled {
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
            return try await aiService.transcribeRemote(audioURL: audioURL)
        }
    }
}
