import Foundation

// 読み取り専用のホスト依存を STT 実行系へ注入する境界。
// live 値は既存の DebugLogger / @AppStorage ラッパーをそのまま使う。
struct DebugLoggerSTTLogger: STTLogging {
    func log(_ category: String, _ message: String, level: STTLogLevel) {
        let mapped: LogLevel = switch level {
        case .debug: .debug
        case .info: .info
        case .warning: .warning
        case .error: .error
        }
        DebugLogger.shared.addLog(category, message, level: mapped)
    }
}

struct DebugLoggerSTTConsoleLogger: STTConsoleLogging {
    func logDetailed(_ message: @autoclosure () -> String) {
        guard DebugLogger.isDetailedSTTLoggingEnabled else { return }
        print(message())
    }
}

struct AppStorageSTTSettingsProvider: STTSettingsProviding {
    var isSpeechAnalyzerEnabled: Bool {
        SpeechAnalyzerFeatureFlag.isEnabled
    }

    var isSpeakerDiarizationEnabled: Bool {
        STTLocalProcessingSettings.isSpeakerDiarizationEnabled
    }

    var contextualVocabulary: [String] {
        STTLocalProcessingSettings.contextualVocabulary
    }
}

struct LiveSTTDiagnosticsRecorder: STTDiagnosticsRecording {
    func record(_ entry: STTBackendDiagnosticEntry) {
        STTDiagnosticsLog.shared.record(entry)
    }
}

extension STTReadOnlyHostDependencies {
    static let live = STTReadOnlyHostDependencies(
        logger: DebugLoggerSTTLogger(),
        consoleLogger: DebugLoggerSTTConsoleLogger(),
        settings: AppStorageSTTSettingsProvider(),
        diagnostics: LiveSTTDiagnosticsRecorder()
    )
}
