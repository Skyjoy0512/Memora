import AVFoundation
import Foundation
import SwiftUI
import Speech

// UI 互換用の内部ラッパー。STT 境界の DTO は Core 契約の
// `TranscriptionResult` のみを使用する。

/// スピーカーセグメント（UI 表示用）
struct SpeakerSegment {
    let speakerLabel: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let isEstimatedTiming: Bool
}

struct TranscriptResult {
    let text: String
    let segments: [SpeakerSegment]
    let duration: TimeInterval

    init(text: String, segments: [SpeakerSegment], duration: TimeInterval) {
        self.text = text
        self.segments = segments
        self.duration = duration
    }

    init(coreResult: TranscriptionResult, duration: TimeInterval) {
        self.text = coreResult.fullText
        self.segments = coreResult.segments.map {
            SpeakerSegment(
                speakerLabel: $0.speakerLabel,
                startTime: $0.startSec,
                endTime: $0.endSec,
                text: $0.text,
                isEstimatedTiming: $0.isEstimatedTiming
            )
        }
        self.duration = duration
    }

    var coreResult: TranscriptionResult {
        TranscriptionResult(
            fullText: text,
            language: "ja",
            segments: segments.enumerated().map { index, segment in
                TranscriptionSegment(
                    id: "segment-\(index)",
                    speakerLabel: segment.speakerLabel,
                    startSec: segment.startTime,
                    endSec: segment.endTime,
                    text: segment.text,
                    isEstimatedTiming: segment.isEstimatedTiming
                )
            }
        )
    }
}

struct STTExecutionConfiguration: Sendable {
    let apiKey: String
    let provider: AIProvider
    let transcriptionMode: TranscriptionMode
    let allowsSpeechAnalyzer: Bool

    static let localDefault = STTExecutionConfiguration(
        apiKey: "",
        provider: .openai,
        transcriptionMode: .local,
        allowsSpeechAnalyzer: true
    )

    func withSpeechAnalyzerAllowed(_ isAllowed: Bool) -> STTExecutionConfiguration {
        STTExecutionConfiguration(
            apiKey: apiKey,
            provider: provider,
            transcriptionMode: transcriptionMode,
            allowsSpeechAnalyzer: isAllowed
        )
    }
}

struct OnDeviceTranscriptionTimeoutError: LocalizedError, Equatable, Sendable {
    static let message = "文字起こしがタイムアウトしました。オンデバイス認識モデルがダウンロードされていない可能性があります。設定からオンデバイスモードをオフにするか、Wi-Fi環境でやり直してください。"

    var errorDescription: String? {
        Self.message
    }
}

enum DurationFormatter {
    static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
    }
}

struct TranscriptPostProcessor {
    func process(_ result: TranscriptionResult) -> TranscriptionResult {
        let cleanedSegments = result.segments.map { segment in
            TranscriptionSegment(
                id: segment.id,
                speakerLabel: segment.speakerLabel,
                startSec: segment.startSec,
                endSec: segment.endSec,
                text: clean(segment.text),
                isEstimatedTiming: segment.isEstimatedTiming
            )
        }
        let cleanedFullText = clean(result.fullText)

        return TranscriptionResult(
            fullText: cleanedFullText,
            language: result.language,
            segments: cleanedSegments
        )
    }

    func clean(_ text: String) -> String {
        var value = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        value = collapseHorizontalWhitespace(value)
        value = normalizeLineBreaks(value)
        value = normalizeJapaneseSpacing(value)
        value = normalizePunctuation(value)
        value = removeStandaloneFillers(value)

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseHorizontalWhitespace(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"[ \t　]+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private func normalizeLineBreaks(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
    }

    private func normalizeJapaneseSpacing(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(
            of: #"([\p{Han}\p{Hiragana}\p{Katakana}]) ([\p{Han}\p{Hiragana}\p{Katakana}])"#,
            with: "$1$2",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #" ([、。！？])"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"([（「『]) "#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #" "([）」』])"#,
            with: "$1",
            options: .regularExpression
        )
        return value
    }

    private func normalizePunctuation(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(
            of: #"[、,]{2,}"#,
            with: "、",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[。\.]{2,}"#,
            with: "。",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[!！]{2,}"#,
            with: "！",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[?？]{2,}"#,
            with: "？",
            options: .regularExpression
        )
        return value
    }

    private func removeStandaloneFillers(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?m)^\s*(えー|ええと|えっと|あの|その|まあ|うーん)\s*[、。,.]?\s*$\n?"#,
            with: "",
            options: .regularExpression
        )
    }
}

enum STTLanguageNormalizer {
    static func baseLanguageCode(for rawLanguage: String) -> String {
        rawLanguage
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init)?
            .lowercased() ?? rawLanguage.lowercased()
    }
}

enum STTErrorMapper {
    static func mapToCoreError(_ error: Error) -> CoreError {
        if let coreError = error as? CoreError {
            return coreError
        }

        if let transcriptionError = error as? TranscriptionError {
            return .transcriptionError(transcriptionError)
        }

        if let chunkerError = error as? AudioChunkerError {
            return .pipelineError(.transcriptionFailed(chunkerError.localizedDescription))
        }

        if let aiError = error as? AIError {
            return .transcriptionError(.transcriptionFailed(aiError.localizedDescription))
        }

        if let openAIError = error as? OpenAIError {
            return .transcriptionError(.transcriptionFailed(openAIError.localizedDescription))
        }

        if let timeoutError = error as? OnDeviceTranscriptionTimeoutError {
            return .transcriptionError(.transcriptionFailed(timeoutError.localizedDescription))
        }

        return .transcriptionError(.transcriptionFailed(error.localizedDescription))
    }
}

// MARK: - Feature Flags

/// iOS 26 SpeechAnalyzer ベータ機能のフィーチャーフラグ。
/// デフォルト OFF（実機での EXC_BREAKPOINT クラッシュを回避）。
struct SpeechAnalyzerFeatureFlag {
    @AppStorage("speechAnalyzerEnabled") static var isEnabled: Bool = false
}

enum STTLocalProcessingSettings {
    @AppStorage("speakerDiarizationEnabled") static var isSpeakerDiarizationEnabled: Bool = false

    static let contextualVocabulary: [String] = [
        "決済", "決済サイクル", "解約", "請求", "入金", "未入金", "返金",
        "バンドル", "ローンチ", "集計基準", "月次", "当月", "翌月",
        "初月無料", "再契約", "店舗管理画面", "代理店", "契約書", "QRコード"
    ]
}

final class STTProgressThrottler: @unchecked Sendable {
    private let lock = NSLock()
    private let progressInterval: TimeInterval
    private let progressStep: Double
    private let partialInterval: TimeInterval
    private let liveActivityChunkStep: Int

    private var lastProgress = 0.0
    private var lastProgressDate = Date.distantPast
    private var lastPartialDate = Date.distantPast
    private var lastLiveActivityChunk = 0

    init(
        progressInterval: TimeInterval,
        progressStep: Double,
        partialInterval: TimeInterval,
        liveActivityChunkStep: Int
    ) {
        self.progressInterval = progressInterval
        self.progressStep = progressStep
        self.partialInterval = partialInterval
        self.liveActivityChunkStep = max(1, liveActivityChunkStep)
    }

    static func forTranscription(mode: TranscriptionMode, totalChunks: Int) -> STTProgressThrottler {
        if mode == .local, totalChunks >= 8 {
            return STTProgressThrottler(
                progressInterval: 2.0,
                progressStep: 0.02,
                partialInterval: 4.0,
                liveActivityChunkStep: max(1, totalChunks / 20)
            )
        }

        return STTProgressThrottler(
            progressInterval: 0.5,
            progressStep: 0.005,
            partialInterval: 1.0,
            liveActivityChunkStep: 1
        )
    }

    func shouldEmitProgress(_ progress: Double, force: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if force || progress >= 1 || progress - lastProgress >= progressStep || now.timeIntervalSince(lastProgressDate) >= progressInterval {
            lastProgress = progress
            lastProgressDate = now
            return true
        }
        return false
    }

    func shouldEmitPartial(force: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if force || now.timeIntervalSince(lastPartialDate) >= partialInterval {
            lastPartialDate = now
            return true
        }
        return false
    }

    func shouldUpdateLiveActivity(completedChunkCount: Int, totalChunks: Int, force: Bool = false) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if force || completedChunkCount >= totalChunks || completedChunkCount - lastLiveActivityChunk >= liveActivityChunkStep {
            lastLiveActivityChunk = completedChunkCount
            return true
        }
        return false
    }
}

// MARK: - STT Backend Diagnostics

/// 文字起こし失敗の分類と recovery action。
enum STTFailureCategory: String, CaseIterable {
    case localeUnsupported
    case assetNotInstalled
    case formatMismatch
    case timeout
    case permissionDenied
    case apiModeUnavailable
    case other

    var localizedTitle: String {
        switch self {
        case .localeUnsupported: return "言語が未対応"
        case .assetNotInstalled: return "音声認識モデル未ダウンロード"
        case .formatMismatch: return "音声フォーマット非互換"
        case .timeout: return "処理タイムアウト"
        case .permissionDenied: return "音声認識の権限がありません"
        case .apiModeUnavailable: return "API 文字起こしを利用できません"
        case .other: return "不明なエラー"
        }
    }

    var recoveryAction: String {
        switch self {
        case .localeUnsupported:
            return "設定で言語を変更するか、API モードを試してください。"
        case .assetNotInstalled:
            return "Wi-Fi 環境で再試行するとモデルが自動ダウンロードされます。"
        case .formatMismatch:
            return "別の音声形式（M4A / WAV）でインポートし直してください。"
        case .timeout:
            return "on-device モデルが未ダウンロードの可能性があります。Wi-Fi で再試行するか、API モードに切り替えてください。"
        case .permissionDenied:
            return "iOS 設定 → Memora → 音声認識を許可してください。"
        case .apiModeUnavailable:
            return "設定で API キーを入力するか、プロバイダーを OpenAI に変更してください。"
        case .other:
            return "再度お試しください。問題が続く場合は一時的に API モードをご利用ください。"
        }
    }

    /// 直近の diagnostic entry から分類を推定する。
    static func classify(from entry: STTBackendDiagnosticEntry?) -> STTFailureCategory {
        guard let entry, let reason = entry.fallbackReason, !reason.isEmpty else {
            return .other
        }
        let lower = reason.lowercased()
        if lower.contains("locale") || lower.contains("言語") || lower.contains("language") {
            return .localeUnsupported
        }
        if lower.contains("asset") || lower.contains("model") || lower.contains("installed") || lower.contains("install") {
            return .assetNotInstalled
        }
        if lower.contains("format") || lower.contains("互換") {
            return .formatMismatch
        }
        if lower.contains("timeout") || lower.contains("タイムアウト") {
            return .timeout
        }
        if lower.contains("permission") || lower.contains("denied") || lower.contains("権限") {
            return .permissionDenied
        }
        if lower.contains("api") || lower.contains("key") || lower.contains("provider") {
            return .apiModeUnavailable
        }
        return .other
    }

    /// 直近の diagnostic entry がフォールバックを含む場合に分類を返す。
    static func classifyLastFailure() -> STTFailureCategory? {
        guard let last = STTDiagnosticsLog.shared.lastEntry,
              last.fallbackReason != nil else {
            return nil
        }
        return classify(from: last)
    }
}

/// STT バックエンド選択結果の診断記録。
/// どのバックエンドが使われたか、fallback 理由、処理時間を記録する。
struct STTBackendDiagnosticEntry: Sendable, Codable, Identifiable {
    let taskId: String
    let backend: STTBackendType
    let locale: String
    let assetState: String?
    let audioFormat: String?
    let fallbackReason: String?
    let processingTimeMs: Double?
    let recordedAt: Date

    var id: String {
        "\(taskId)-\(recordedAt.timeIntervalSince1970)"
    }

    var summary: String {
        var parts = ["\(backend.rawValue) | locale=\(locale)"]
        if let asset = assetState { parts.append("asset=\(asset)") }
        if let fmt = audioFormat { parts.append("format=\(fmt)") }
        if let reason = fallbackReason { parts.append("fallback=\(reason)") }
        if let ms = processingTimeMs { parts.append("time=\(String(format: "%.1f", ms))ms") }
        return parts.joined(separator: " ")
    }
}

/// 使用された STT バックエンド種別
enum STTBackendType: String, Sendable, Codable {
    case speechAnalyzer = "SpeechAnalyzer"
    case sfSpeechRecognizer = "SFSpeechRecognizer"
    case cloudAPI = "CloudAPI"
}

/// STT 診断ログの集約ポイント。
/// 最後の N 件をメモリ保持し、DebugLogger にも出力する。
final class STTDiagnosticsLog: @unchecked Sendable {
    static let shared = STTDiagnosticsLog()

    private enum StorageKeys {
        static let lastEntry = "sttDiagnosticsLastEntry"
        static let lastFallbackReason = "sttDiagnosticsLastFallbackReason"
    }

    private let lock = NSLock()
    private let logger: any STTLogging
    private var entries: [STTBackendDiagnosticEntry] = []
    private let maxEntries = 50

    init(logger: any STTLogging = DebugLoggerSTTLogger()) {
        self.logger = logger
        if let persisted = loadPersistedLastEntry() {
            entries = [persisted]
        }
    }

    /// 直近の診断エントリを返す。
    var recentEntries: [STTBackendDiagnosticEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(entries.suffix(10))
    }

    /// 最後のエントリを返す。
    var lastEntry: STTBackendDiagnosticEntry? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last
    }

    /// 永続化された最後のエントリを返す。
    var persistedLastEntry: STTBackendDiagnosticEntry? {
        loadPersistedLastEntry()
    }

    /// 最後に記録されたフォールバック理由を返す。
    var lastFallbackReason: String? {
        UserDefaults.standard.string(forKey: StorageKeys.lastFallbackReason)
    }

    /// エントリを記録し、DebugLogger にも出力する。
    func record(_ entry: STTBackendDiagnosticEntry) {
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        persist(entry)

        logger.log(
            "STTDiagnostics",
            entry.summary,
            level: entry.fallbackReason != nil ? .warning : .info
        )
    }

    private func persist(_ entry: STTBackendDiagnosticEntry) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: StorageKeys.lastEntry)
        }

        if let fallbackReason = entry.fallbackReason, !fallbackReason.isEmpty {
            defaults.set(fallbackReason, forKey: StorageKeys.lastFallbackReason)
        }
    }

    private func loadPersistedLastEntry() -> STTBackendDiagnosticEntry? {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.lastEntry) else {
            return nil
        }
        return try? JSONDecoder().decode(STTBackendDiagnosticEntry.self, from: data)
    }
}

// MARK: - Streaming Transcript Merger (PR-B10)

/// チャンク結果を逐次受け取り、オフセット加算しながら
/// 全文とセグメントを積み上げる。全 TranscriptionResult を配列保持しない。
struct StreamingTranscriptMerger {
    private(set) var fullTextParts: [String] = []
    private(set) var segments: [TranscriptionSegment] = []
    private var detectedLanguage: String?

    mutating func append(chunk: AudioChunk, result: TranscriptionResult) {
        if detectedLanguage == nil, !result.language.isEmpty {
            detectedLanguage = result.language
        }
        let offset = chunk.startSec
        fullTextParts.append(result.fullText)
        for seg in result.segments {
            segments.append(TranscriptionSegment(
                id: seg.id,
                speakerLabel: seg.speakerLabel,
                startSec: seg.startSec + offset,
                endSec: seg.endSec + offset,
                text: seg.text,
                isEstimatedTiming: seg.isEstimatedTiming
            ))
        }
    }

    func finalize(preferredLanguage: String? = nil) -> TranscriptionResult {
        let language = preferredLanguage.map(STTLanguageNormalizer.baseLanguageCode(for:))
            ?? detectedLanguage
            ?? "ja"
        return TranscriptionResult(
            fullText: fullTextParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            language: language,
            segments: segments
        )
    }
}

// MARK: - Transcription Estimate (PR-B11)

/// 文字起こし開始前の事前見積もり情報。
/// plan() の総時間・チャンク数・概算処理時間を提供する。
struct TranscriptionEstimate: Sendable {
    let sourceURL: URL
    let totalDuration: TimeInterval
    let chunkCount: Int
    /// 概算処理時間（秒）。ローカルは 1chunk ≒ 90秒、API は並列 4 で 1chunk ≒ 30秒 で見積もる。
    let estimatedProcessingSeconds: TimeInterval
    /// 長時間（3時間超）かどうか。呼び出し元が確認ダイアログを出すかの判定に使う。
    var isVeryLong: Bool { totalDuration >= 60 * 60 * 3 }
    /// ユーザー表示用の確認メッセージ
    var alertMessage: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int(estimatedProcessingSeconds / 60)
        let minText = minutes > 0 ? "約\(minutes)分" : "1分未満"
        return "この録音は約\(hours)時間で、文字起こしに時間がかかります（推定\(minText)）。\nバックグラウンドでも継続しますが、端末の充電を推奨します。\n開始しますか？"
    }

    init(sourceURL: URL, totalDuration: TimeInterval, chunkCount: Int, isAPIMode: Bool) {
        self.sourceURL = sourceURL
        self.totalDuration = totalDuration
        self.chunkCount = chunkCount
        if isAPIMode && chunkCount > 1 {
            // API 並列（最大4並列）を考慮した概算
            self.estimatedProcessingSeconds = Double(chunkCount) * 30 / min(4, Double(chunkCount))
        } else {
            self.estimatedProcessingSeconds = Double(chunkCount) * 90
        }
    }
}

// MARK: - Tail Silence Probe (PR-B4)

enum AudioSilenceProbe {
    /// 指定区間の平均 RMS（0.0〜1.0 近似）を返す。読めない場合は nil。
    /// 長時間読込を避けるため最大 60 秒／4096 frame バッファで走査する。
    static func averageRMS(url: URL, startSec: Double, endSec: Double) -> Float? {
        guard endSec > startSec else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate
            let clampedEnd = min(endSec, startSec + 60)
            let startFrame = AVAudioFramePosition(startSec * sampleRate)
            let frameCount = AVAudioFrameCount((clampedEnd - startSec) * sampleRate)
            guard frameCount > 0, startFrame < file.length else { return nil }
            file.framePosition = min(startFrame, file.length - 1)

            var sumSquares: Double = 0
            var totalFrames: Double = 0
            let bufferSize: AVAudioFrameCount = 4096
            var remaining = min(frameCount, AVAudioFrameCount(file.length - file.framePosition))

            while remaining > 0 {
                let thisRead = min(bufferSize, remaining)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisRead) else { return nil }
                try file.read(into: buffer, frameCount: thisRead)
                guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }
                for i in 0..<Int(buffer.frameLength) {
                    let v = Double(channel[i])
                    sumSquares += v * v
                }
                totalFrames += Double(buffer.frameLength)
                remaining -= buffer.frameLength
            }
            guard totalFrames > 0 else { return nil }
            return Float((sumSquares / totalFrames).squareRoot())
        } catch {
            return nil
        }
    }
}

// MARK: - Checkpoint Hooks

/// STTService へのチェックポイント操作注入用コールバック。
/// 成功時に clear、失敗時は残す（次回再開のため）。
struct STTCheckpointHooks: Sendable {
    /// 完了済みチャンク結果を返す（fingerprint 不一致処理は hook 実装側の責務）。
    let load: @Sendable (_ fingerprint: String) async -> [Int: CheckpointChunkResult]
    /// チャンク完了ごとに呼ばれる。
    let save: @Sendable (_ fingerprint: String, _ totalChunks: Int, _ chunkIndex: Int, _ result: CheckpointChunkResult) async -> Void
    /// 全体成功時に呼ばれる。
    let clear: @Sendable () async -> Void
}
