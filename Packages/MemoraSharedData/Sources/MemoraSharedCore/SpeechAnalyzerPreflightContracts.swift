import Foundation

/// SpeechAnalyzer 実行前判定をホスト実装へ委譲する共有境界。
/// 判定の実装と feature flag の読み取りはホスト側に残す。
public protocol SpeechAnalyzerPreflighting: Sendable {
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult
    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics
}

public enum SpeechAnalyzerPreflightResult: Sendable {
    case ready(diagnostics: SpeechAnalyzerDiagnostics)
    case unavailable(reason: SpeechAnalyzerUnavailableReason, diagnostics: SpeechAnalyzerDiagnostics)
}

public enum SpeechAnalyzerUnavailableReason: Sendable, CustomStringConvertible {
    case featureFlagOff
    case notAvailable
    case localeNotSupported(requestedLocale: String)
    case assetsNotReady(statusDescription: String)
    case internalError(String)

    public var description: String {
        switch self {
        case .featureFlagOff:
            return "SpeechAnalyzer feature flag is OFF"
        case .notAvailable:
            return "SpeechTranscriber.isAvailable == false"
        case .localeNotSupported(let locale):
            return "Locale \(locale) is not supported by SpeechTranscriber"
        case .assetsNotReady(let status):
            return "Assets not ready: \(status)"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}

public struct SpeechAnalyzerDiagnostics: Sendable {
    public let isTranscriberAvailable: Bool
    public let featureFlagEnabled: Bool
    public let requestedLocale: String
    public let supportedLocale: Locale?
    public let assetStatus: String
    public let compatibleFormatsDescription: String
    public let unavailableReason: SpeechAnalyzerUnavailableReason?
    public let checkedAt: Date
    public let checkDurationMs: Double

    public init(
        isTranscriberAvailable: Bool,
        featureFlagEnabled: Bool,
        requestedLocale: String,
        supportedLocale: Locale?,
        assetStatus: String,
        compatibleFormatsDescription: String,
        unavailableReason: SpeechAnalyzerUnavailableReason?,
        checkedAt: Date,
        checkDurationMs: Double
    ) {
        self.isTranscriberAvailable = isTranscriberAvailable
        self.featureFlagEnabled = featureFlagEnabled
        self.requestedLocale = requestedLocale
        self.supportedLocale = supportedLocale
        self.assetStatus = assetStatus
        self.compatibleFormatsDescription = compatibleFormatsDescription
        self.unavailableReason = unavailableReason
        self.checkedAt = checkedAt
        self.checkDurationMs = checkDurationMs
    }

    public var summary: String {
        if let reason = unavailableReason {
            return "SpeechAnalyzer unavailable: \(reason.description)"
        }
        return "SpeechAnalyzer ready — locale: \(supportedLocale?.identifier ?? requestedLocale)"
    }
}
