import Foundation
import SwiftUI
import Speech

// CL-A1: SpeechAnalyzer preflight checks.
// Runs BEFORE any transcription attempt to decide whether SpeechAnalyzer
// can be used safely. Produces structured diagnostics for logging and UI.

// MARK: - Preflight Result

@available(iOS 26.0, *)
enum SpeechAnalyzerPreflightResult: Sendable {
    case ready(diagnostics: SpeechAnalyzerDiagnostics)
    case unavailable(reason: SpeechAnalyzerUnavailableReason, diagnostics: SpeechAnalyzerDiagnostics)
}

// MARK: - Unavailable Reasons

@available(iOS 26.0, *)
enum SpeechAnalyzerUnavailableReason: Sendable, CustomStringConvertible {
    case featureFlagOff
    case notAvailable
    case localeNotSupported(requestedLocale: String)
    case assetsNotReady(statusDescription: String)
    case internalError(String)

    var description: String {
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

// MARK: - Diagnostics

@available(iOS 26.0, *)
struct SpeechAnalyzerDiagnostics: Sendable {
    let isTranscriberAvailable: Bool
    let featureFlagEnabled: Bool
    let requestedLocale: String
    let supportedLocale: Locale?
    let assetStatus: String
    let compatibleFormatsDescription: String
    let unavailableReason: SpeechAnalyzerUnavailableReason?
    let checkedAt: Date
    let checkDurationMs: Double

    var summary: String {
        if let reason = unavailableReason {
            return "SpeechAnalyzer unavailable: \(reason.description)"
        }
        return "SpeechAnalyzer ready — locale: \(supportedLocale?.identifier ?? requestedLocale)"
    }
}

// MARK: - Preflight Runner

@available(iOS 26.0, *)
final class SpeechAnalyzerPreflight: Sendable {

    /// Run all preflight checks for the given locale.
    /// Returns `.ready` if SpeechAnalyzer can be used, `.unavailable` with a reason otherwise.
    func run(locale: Locale) async -> SpeechAnalyzerPreflightResult {
        let start = ContinuousClock.now

        let isAvailable = SpeechTranscriber.isAvailable
        let featureEnabled = SpeechAnalyzerFeatureFlag.isEnabled
        var supportedLocale: Locale? = nil
        var assetStatusDescription = "unknown"
        var compatibleFormats = "not checked"
        var unavailableReason: SpeechAnalyzerUnavailableReason? = nil

        // Step 1: Feature flag
        guard featureEnabled else {
            let reason = SpeechAnalyzerUnavailableReason.featureFlagOff
            unavailableReason = reason
            let diag = makeDiagnostics(
                isAvailable: isAvailable,
                featureEnabled: featureEnabled,
                locale: locale,
                supportedLocale: nil,
                assetStatus: assetStatusDescription,
                formats: compatibleFormats,
                reason: reason,
                start: start
            )
            return .unavailable(reason: reason, diagnostics: diag)
        }

        // Step 2: Availability
        guard isAvailable else {
            let reason = SpeechAnalyzerUnavailableReason.notAvailable
            unavailableReason = reason
            let diag = makeDiagnostics(
                isAvailable: isAvailable,
                featureEnabled: featureEnabled,
                locale: locale,
                supportedLocale: nil,
                assetStatus: assetStatusDescription,
                formats: compatibleFormats,
                reason: reason,
                start: start
            )
            return .unavailable(reason: reason, diagnostics: diag)
        }

        // Step 3: Locale equivalence
        let resolvedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        supportedLocale = resolvedLocale
        guard let resolvedLocale else {
            let reason = SpeechAnalyzerUnavailableReason.localeNotSupported(requestedLocale: locale.identifier)
            unavailableReason = reason
            let diag = makeDiagnostics(
                isAvailable: isAvailable,
                featureEnabled: featureEnabled,
                locale: locale,
                supportedLocale: nil,
                assetStatus: assetStatusDescription,
                formats: compatibleFormats,
                reason: reason,
                start: start
            )
            return .unavailable(reason: reason, diagnostics: diag)
        }

        // Step 4: Asset status
        let preset = SpeechTranscriber.Preset.transcription
        let transcriber = SpeechTranscriber(locale: resolvedLocale, preset: preset)
        let assetStatus = await AssetInventory.status(forModules: [transcriber])
        assetStatusDescription = String(describing: assetStatus)

        if assetStatus != .installed {
            // Try to install assets
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                    let finalStatus = await AssetInventory.status(forModules: [transcriber])
                    assetStatusDescription = String(describing: finalStatus)

                    if finalStatus != .installed {
                        let reason = SpeechAnalyzerUnavailableReason.assetsNotReady(statusDescription: assetStatusDescription)
                        unavailableReason = reason
                        let diag = makeDiagnostics(
                            isAvailable: isAvailable,
                            featureEnabled: featureEnabled,
                            locale: locale,
                            supportedLocale: resolvedLocale,
                            assetStatus: assetStatusDescription,
                            formats: compatibleFormats,
                            reason: reason,
                            start: start
                        )
                        return .unavailable(reason: reason, diagnostics: diag)
                    }
                }
            } catch {
                let reason = SpeechAnalyzerUnavailableReason.assetsNotReady(statusDescription: error.localizedDescription)
                unavailableReason = reason
                let diag = makeDiagnostics(
                    isAvailable: isAvailable,
                    featureEnabled: featureEnabled,
                    locale: locale,
                    supportedLocale: resolvedLocale,
                    assetStatus: assetStatusDescription,
                    formats: compatibleFormats,
                    reason: reason,
                    start: start
                )
                return .unavailable(reason: reason, diagnostics: diag)
            }
        }

        // Step 5: Compatible audio formats
        let formats = await transcriber.availableCompatibleAudioFormats
        compatibleFormats = formats.map { String(describing: $0) }.joined(separator: ", ")

        let diag = makeDiagnostics(
            isAvailable: isAvailable,
            featureEnabled: featureEnabled,
            locale: locale,
            supportedLocale: resolvedLocale,
            assetStatus: assetStatusDescription,
            formats: compatibleFormats,
            reason: nil,
            start: start
        )

        return .ready(diagnostics: diag)
    }

    /// Convenience: returns diagnostics without running full install flow.
    func diagnostics(for locale: Locale) async -> SpeechAnalyzerDiagnostics {
        let result = await run(locale: locale)
        switch result {
        case .ready(let diag), .unavailable(_, let diag):
            return diag
        }
    }

    private func makeDiagnostics(
        isAvailable: Bool,
        featureEnabled: Bool,
        locale: Locale,
        supportedLocale: Locale?,
        assetStatus: String,
        formats: String,
        reason: SpeechAnalyzerUnavailableReason?,
        start: ContinuousClock.Instant
    ) -> SpeechAnalyzerDiagnostics {
        let duration = start.duration(to: ContinuousClock.now)
        let ms = Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1_000_000_000_000.0

        return SpeechAnalyzerDiagnostics(
            isTranscriberAvailable: isAvailable,
            featureFlagEnabled: featureEnabled,
            requestedLocale: locale.identifier,
            supportedLocale: supportedLocale,
            assetStatus: assetStatus,
            compatibleFormatsDescription: formats,
            unavailableReason: reason,
            checkedAt: Date(),
            checkDurationMs: ms
        )
    }
}
