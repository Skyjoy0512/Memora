import Foundation

// 読み取り専用のホスト依存を STT 実行系へ注入する境界。
// live 値は既存の DebugLogger / @AppStorage ラッパーをそのまま使う。
protocol STTLogging: Sendable {
    func log(_ category: String, _ message: String, level: LogLevel)
}

struct DebugLoggerSTTLogger: STTLogging {
    func log(_ category: String, _ message: String, level: LogLevel) {
        DebugLogger.shared.addLog(category, message, level: level)
    }
}

protocol STTSettingsProviding: Sendable {
    var isSpeechAnalyzerEnabled: Bool { get }
    var isSpeakerDiarizationEnabled: Bool { get }
    var contextualVocabulary: [String] { get }
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

struct STTReadOnlyHostDependencies: Sendable {
    let logger: any STTLogging
    let settings: any STTSettingsProviding

    static let live = STTReadOnlyHostDependencies(
        logger: DebugLoggerSTTLogger(),
        settings: AppStorageSTTSettingsProvider()
    )
}
