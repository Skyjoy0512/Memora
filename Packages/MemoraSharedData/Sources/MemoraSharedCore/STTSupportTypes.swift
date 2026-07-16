import Foundation
@preconcurrency import AVFoundation

/// スピーカーセグメント（UI 表示用）
public struct SpeakerSegment: Sendable {
    public let speakerLabel: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let isEstimatedTiming: Bool

    public init(
        speakerLabel: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        isEstimatedTiming: Bool = false
    ) {
        self.speakerLabel = speakerLabel
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.isEstimatedTiming = isEstimatedTiming
    }
}

public struct TranscriptResult: Sendable {
    public let text: String
    public let segments: [SpeakerSegment]
    public let duration: TimeInterval

    public init(text: String, segments: [SpeakerSegment], duration: TimeInterval) {
        self.text = text
        self.segments = segments
        self.duration = duration
    }

    public init(coreResult: TranscriptionResult, duration: TimeInterval) {
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

    public var coreResult: TranscriptionResult {
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

public struct OnDeviceTranscriptionTimeoutError: LocalizedError, Equatable, Sendable {
    public static let message = "文字起こしがタイムアウトしました。オンデバイス認識モデルがダウンロードされていない可能性があります。設定からオンデバイスモードをオフにするか、Wi-Fi環境でやり直してください。"

    public init() {}

    public var errorDescription: String? { Self.message }
}

public enum DurationFormatter {
    public static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000.0
    }
}

public struct TranscriptPostProcessor {
    public init() {}

    public func process(_ result: TranscriptionResult) -> TranscriptionResult {
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

    public func clean(_ text: String) -> String {
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
        text.replacingOccurrences(of: #"[ \t　]+"#, with: " ", options: .regularExpression)
    }

    private func normalizeLineBreaks(_ text: String) -> String {
        text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    private func normalizeJapaneseSpacing(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(of: #"([\p{Han}\p{Hiragana}\p{Katakana}]) ([\p{Han}\p{Hiragana}\p{Katakana}])"#, with: "$1$2", options: .regularExpression)
        value = value.replacingOccurrences(of: #" ([、。！？])"#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #"([（「『]) "#, with: "$1", options: .regularExpression)
        value = value.replacingOccurrences(of: #" "([）」』])"#, with: "$1", options: .regularExpression)
        return value
    }

    private func normalizePunctuation(_ text: String) -> String {
        var value = text
        value = value.replacingOccurrences(of: #"[、,]{2,}"#, with: "、", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[。\.]{2,}"#, with: "。", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[!！]{2,}"#, with: "！", options: .regularExpression)
        value = value.replacingOccurrences(of: #"[?？]{2,}"#, with: "？", options: .regularExpression)
        return value
    }

    private func removeStandaloneFillers(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?m)^\s*(えー|ええと|えっと|あの|その|まあ|うーん)\s*[、。,.]?\s*$\n?"#, with: "", options: .regularExpression)
    }
}

public enum STTLanguageNormalizer {
    public static func baseLanguageCode(for rawLanguage: String) -> String {
        rawLanguage.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init)?.lowercased() ?? rawLanguage.lowercased()
    }
}

public final class STTProgressThrottler: @unchecked Sendable {
    private let lock = NSLock()
    private let progressInterval: TimeInterval
    private let progressStep: Double
    private let partialInterval: TimeInterval
    private let liveActivityChunkStep: Int
    private var lastProgress = 0.0
    private var lastProgressDate = Date.distantPast
    private var lastPartialDate = Date.distantPast
    private var lastLiveActivityChunk = 0

    public init(progressInterval: TimeInterval, progressStep: Double, partialInterval: TimeInterval, liveActivityChunkStep: Int) {
        self.progressInterval = progressInterval
        self.progressStep = progressStep
        self.partialInterval = partialInterval
        self.liveActivityChunkStep = max(1, liveActivityChunkStep)
    }

    public func shouldEmitProgress(_ progress: Double, force: Bool = false) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        if force || progress >= 1 || progress - lastProgress >= progressStep || now.timeIntervalSince(lastProgressDate) >= progressInterval {
            lastProgress = progress; lastProgressDate = now; return true
        }
        return false
    }

    public func shouldEmitPartial(force: Bool = false) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        if force || now.timeIntervalSince(lastPartialDate) >= partialInterval {
            lastPartialDate = now; return true
        }
        return false
    }

    public func shouldUpdateLiveActivity(completedChunkCount: Int, totalChunks: Int, force: Bool = false) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if force || completedChunkCount >= totalChunks || completedChunkCount - lastLiveActivityChunk >= liveActivityChunkStep {
            lastLiveActivityChunk = completedChunkCount; return true
        }
        return false
    }

    public static func forTranscription(mode: TranscriptionMode, totalChunks: Int) -> STTProgressThrottler {
        if mode == .local, totalChunks >= 8 {
            return STTProgressThrottler(progressInterval: 2.0, progressStep: 0.02, partialInterval: 4.0, liveActivityChunkStep: max(1, totalChunks / 20))
        }
        return STTProgressThrottler(progressInterval: 0.5, progressStep: 0.005, partialInterval: 1.0, liveActivityChunkStep: 1)
    }
}

public enum STTFailureCategory: String, CaseIterable, Sendable {
    case localeUnsupported, assetNotInstalled, formatMismatch, timeout, permissionDenied, apiModeUnavailable, other

    public var localizedTitle: String {
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

    public var recoveryAction: String {
        switch self {
        case .localeUnsupported: return "設定で言語を変更するか、API モードを試してください。"
        case .assetNotInstalled: return "Wi-Fi 環境で再試行するとモデルが自動ダウンロードされます。"
        case .formatMismatch: return "別の音声形式（M4A / WAV）でインポートし直してください。"
        case .timeout: return "on-device モデルが未ダウンロードの可能性があります。Wi-Fi で再試行するか、API モードに切り替えてください。"
        case .permissionDenied: return "iOS 設定 → Memora → 音声認識を許可してください。"
        case .apiModeUnavailable: return "設定で API キーを入力するか、プロバイダーを OpenAI に変更してください。"
        case .other: return "再度お試しください。問題が続く場合は一時的に API モードをご利用ください。"
        }
    }

    public static func classify(from entry: STTBackendDiagnosticEntry?) -> STTFailureCategory {
        guard let entry, let reason = entry.fallbackReason, !reason.isEmpty else { return .other }
        let lower = reason.lowercased()
        if lower.contains("locale") || lower.contains("言語") || lower.contains("language") { return .localeUnsupported }
        if lower.contains("asset") || lower.contains("model") || lower.contains("installed") || lower.contains("install") { return .assetNotInstalled }
        if lower.contains("format") || lower.contains("互換") { return .formatMismatch }
        if lower.contains("timeout") || lower.contains("タイムアウト") { return .timeout }
        if lower.contains("permission") || lower.contains("denied") || lower.contains("権限") { return .permissionDenied }
        if lower.contains("api") || lower.contains("key") || lower.contains("provider") { return .apiModeUnavailable }
        return .other
    }
}

public struct STTBackendDiagnosticEntry: Sendable, Codable, Identifiable {
    public let taskId: String
    public let backend: STTBackendType
    public let locale: String
    public let assetState: String?
    public let audioFormat: String?
    public let fallbackReason: String?
    public let processingTimeMs: Double?
    public let recordedAt: Date

    public init(taskId: String, backend: STTBackendType, locale: String, assetState: String?, audioFormat: String?, fallbackReason: String?, processingTimeMs: Double?, recordedAt: Date) {
        self.taskId = taskId; self.backend = backend; self.locale = locale; self.assetState = assetState
        self.audioFormat = audioFormat; self.fallbackReason = fallbackReason; self.processingTimeMs = processingTimeMs; self.recordedAt = recordedAt
    }

    public var id: String { "\(taskId)-\(recordedAt.timeIntervalSince1970)" }

    public var summary: String {
        var parts = ["\(backend.rawValue) | locale=\(locale)"]
        if let asset = assetState { parts.append("asset=\(asset)") }
        if let fmt = audioFormat { parts.append("format=\(fmt)") }
        if let reason = fallbackReason { parts.append("fallback=\(reason)") }
        if let ms = processingTimeMs { parts.append("time=\(String(format: "%.1f", ms))ms") }
        return parts.joined(separator: " ")
    }
}

public enum STTBackendType: String, Sendable, Codable {
    case speechAnalyzer = "SpeechAnalyzer"
    case sfSpeechRecognizer = "SFSpeechRecognizer"
    case cloudAPI = "CloudAPI"
}

public struct StreamingTranscriptMerger: Sendable {
    public private(set) var fullTextParts: [String] = []
    public private(set) var segments: [TranscriptionSegment] = []
    private var detectedLanguage: String?

    public init() {}

    public mutating func append(chunk: AudioChunk, result: TranscriptionResult) {
        if detectedLanguage == nil, !result.language.isEmpty { detectedLanguage = result.language }
        let offset = chunk.startSec
        fullTextParts.append(result.fullText)
        for seg in result.segments {
            segments.append(TranscriptionSegment(id: seg.id, speakerLabel: seg.speakerLabel, startSec: seg.startSec + offset, endSec: seg.endSec + offset, text: seg.text, isEstimatedTiming: seg.isEstimatedTiming))
        }
    }

    public func finalize(preferredLanguage: String? = nil) -> TranscriptionResult {
        let language = preferredLanguage.map(STTLanguageNormalizer.baseLanguageCode(for:)) ?? detectedLanguage ?? "ja"
        return TranscriptionResult(fullText: fullTextParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), language: language, segments: segments)
    }
}

public struct TranscriptionEstimate: Sendable {
    public let sourceURL: URL
    public let totalDuration: TimeInterval
    public let chunkCount: Int
    public let estimatedProcessingSeconds: TimeInterval
    public var isVeryLong: Bool { totalDuration >= 60 * 60 * 3 }
    public var alertMessage: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int(estimatedProcessingSeconds / 60)
        let minText = minutes > 0 ? "約\(minutes)分" : "1分未満"
        return "この録音は約\(hours)時間で、文字起こしに時間がかかります（推定\(minText)）。\nバックグラウンドでも継続しますが、端末の充電を推奨します。\n開始しますか？"
    }

    public init(sourceURL: URL, totalDuration: TimeInterval, chunkCount: Int, isAPIMode: Bool) {
        self.sourceURL = sourceURL; self.totalDuration = totalDuration; self.chunkCount = chunkCount
        self.estimatedProcessingSeconds = isAPIMode && chunkCount > 1 ? Double(chunkCount) * 30 / min(4, Double(chunkCount)) : Double(chunkCount) * 90
    }
}

public enum AudioSilenceProbe {
    public static func averageRMS(url: URL, startSec: Double, endSec: Double) -> Float? {
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
            var sumSquares: Double = 0; var totalFrames: Double = 0
            let bufferSize: AVAudioFrameCount = 4096
            var remaining = min(frameCount, AVAudioFrameCount(file.length - file.framePosition))
            while remaining > 0 {
                let thisRead = min(bufferSize, remaining)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisRead) else { return nil }
                try file.read(into: buffer, frameCount: thisRead)
                guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }
                for i in 0..<Int(buffer.frameLength) { let value = Double(channel[i]); sumSquares += value * value }
                totalFrames += Double(buffer.frameLength); remaining -= buffer.frameLength
            }
            guard totalFrames > 0 else { return nil }
            return Float((sumSquares / totalFrames).squareRoot())
        } catch { return nil }
    }
}

public struct CheckpointChunkResult: Codable, Sendable {
    public struct Segment: Codable, Sendable {
        public let id: String
        public let speakerLabel: String
        public let startSec: Double
        public let endSec: Double
        public let text: String
        public let isEstimatedTiming: Bool

        public init(id: String, speakerLabel: String, startSec: Double, endSec: Double, text: String, isEstimatedTiming: Bool) {
            self.id = id; self.speakerLabel = speakerLabel; self.startSec = startSec; self.endSec = endSec; self.text = text; self.isEstimatedTiming = isEstimatedTiming
        }
    }

    public let fullText: String
    public let language: String
    public let segments: [Segment]

    public init(from result: TranscriptionResult) {
        fullText = result.fullText; language = result.language
        segments = result.segments.map { Segment(id: $0.id, speakerLabel: $0.speakerLabel, startSec: $0.startSec, endSec: $0.endSec, text: $0.text, isEstimatedTiming: $0.isEstimatedTiming) }
    }

    public func toTranscriptionResult() -> TranscriptionResult {
        TranscriptionResult(fullText: fullText, language: language, segments: segments.map { TranscriptionSegment(id: $0.id, speakerLabel: $0.speakerLabel, startSec: $0.startSec, endSec: $0.endSec, text: $0.text, isEstimatedTiming: $0.isEstimatedTiming) })
    }
}

public struct STTCheckpointHooks: Sendable {
    public let load: @Sendable (_ fingerprint: String) async -> [Int: CheckpointChunkResult]
    public let save: @Sendable (_ fingerprint: String, _ totalChunks: Int, _ chunkIndex: Int, _ result: CheckpointChunkResult) async -> Void
    public let clear: @Sendable () async -> Void

    public init(load: @escaping @Sendable (_ fingerprint: String) async -> [Int: CheckpointChunkResult], save: @escaping @Sendable (_ fingerprint: String, _ totalChunks: Int, _ chunkIndex: Int, _ result: CheckpointChunkResult) async -> Void, clear: @escaping @Sendable () async -> Void) {
        self.load = load; self.save = save; self.clear = clear
    }
}
