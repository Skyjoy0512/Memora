import Foundation
import Testing
@testable import MemoraSharedCore

@Suite("SpeechAnalyzer preflight")
struct SpeechAnalyzerPreflightTests {
    @Test("明示的に無効化した場合はモデル準備へ進まず featureFlagOff を返す")
    @available(macOS 26.0, iOS 26.0, *)
    func disabledFeatureReturnsUnavailable() async {
        let locale = Locale(identifier: "ja_JP")
        let result = await SpeechAnalyzerPreflight(featureEnabled: false).run(locale: locale)

        guard case let .unavailable(reason, diagnostics) = result else {
            Issue.record("無効化された SpeechAnalyzer が ready を返しました")
            return
        }

        guard case .featureFlagOff = reason else {
            Issue.record("無効化理由が featureFlagOff ではありません: \(reason)")
            return
        }

        #expect(diagnostics.featureFlagEnabled == false)
        #expect(diagnostics.requestedLocale == locale.identifier)
        #expect(diagnostics.unavailableReason?.description == reason.description)
    }
}
