import Foundation
import MemoraSharedCore

// CL-A1: SpeechAnalyzer preflight checks.
// Runs BEFORE any transcription attempt to decide whether SpeechAnalyzer
// can be used safely. Produces structured diagnostics for logging and UI.

// MARK: - Preflight Runner

@available(iOS 26.0, *)
final class SpeechAnalyzerPreflight: SpeechAnalyzerPreflighting, Sendable {
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult {
        await MemoraSharedCore.SpeechAnalyzerPreflight(
            featureEnabled: SpeechAnalyzerFeatureFlag.isEnabled
        ).run(locale: locale)
    }

    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics {
        await MemoraSharedCore.SpeechAnalyzerPreflight(
            featureEnabled: SpeechAnalyzerFeatureFlag.isEnabled
        ).diagnostics(for: locale)
    }
}
