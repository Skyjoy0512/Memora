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
                text: $0.text
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
                    text: segment.text
                )
            }
        )
    }
}

struct STTExecutionConfiguration: Sendable {
    let apiKey: String
    let provider: AIProvider
    let transcriptionMode: TranscriptionMode

    static let localDefault = STTExecutionConfiguration(
        apiKey: "",
        provider: .openai,
        transcriptionMode: .local
    )
}

struct OnDeviceTranscriptionTimeoutError: LocalizedError, Equatable, Sendable {
    static let message = "文字起こしがタイムアウトしました。オンデバイス認識モデルがダウンロードされていない可能性があります。設定からオンデバイスモードをオフにするか、Wi-Fi環境でやり直してください。"

    var errorDescription: String? {
        Self.message
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
    private var entries: [STTBackendDiagnosticEntry] = []
    private let maxEntries = 50

    private init() {
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

        DebugLogger.shared.addLog(
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
