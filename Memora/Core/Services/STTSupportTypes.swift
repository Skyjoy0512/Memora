import Foundation
import SwiftUI

// Host-bound STT support types. Pure STT values and algorithms are in
// MemoraSharedCore; keep the existing AppStorage keys and diagnostics storage
// in the app target.

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

extension STTProgressThrottler {
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
}

extension STTFailureCategory {
    /// 直近の diagnostic entry がフォールバックを含む場合に分類を返す。
    static func classifyLastFailure() -> STTFailureCategory? {
        guard let last = STTDiagnosticsLog.shared.lastEntry,
              last.fallbackReason != nil else {
            return nil
        }
        return classify(from: last)
    }
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

    var recentEntries: [STTBackendDiagnosticEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(entries.suffix(10))
    }

    var lastEntry: STTBackendDiagnosticEntry? {
        lock.lock()
        defer { lock.unlock() }
        return entries.last
    }

    var persistedLastEntry: STTBackendDiagnosticEntry? {
        loadPersistedLastEntry()
    }

    var lastFallbackReason: String? {
        UserDefaults.standard.string(forKey: StorageKeys.lastFallbackReason)
    }

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
