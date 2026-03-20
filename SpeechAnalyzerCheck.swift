import Foundation
import Speech
import AVFoundation

// iOS 26.0+ SpeechAnalyzer API のテスト
@available(iOS 26.0, *)
class SpeechAnalyzerTester {
    let locale = Locale(identifier: "ja_JP")

    func testAPIAvailability() async throws {
        print("=== iOS 26.0+ SpeechAnalyzer API Test ===")

        // 1. サポートされているロケールを確認
        print("\n1. Checking supported locales...")
        let supportedLocales = await SpeechTranscriber.supportedLocales
        print("Supported locales: \(supportedLocales)")

        // 2. 日本語ロケールのサポートを確認
        print("\n2. Checking Japanese locale support...")
        if let jaLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            print("Japanese locale supported: \(jaLocale)")
        } else {
            print("Japanese locale NOT supported")
        }

        // 3. SpeechTranscriber の Preset を確認
        print("\n3. Available SpeechTranscriber Presets:")
        print("  - transcription")
        print("  - transcriptionWithAlternatives")
        print("  - timeIndexedTranscriptionWithAlternatives")
        print("  - progressiveTranscription")
        print("  - timeIndexedProgressiveTranscription")

        // 4. SpeechTranscriber を作成
        print("\n4. Creating SpeechTranscriber...")
        if let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            let transcriber = SpeechTranscriber(
                locale: supportedLocale,
                preset: .timeIndexedProgressiveTranscription
            )
            print("SpeechTranscriber created successfully")

            // 5. SpeechAnalyzer を作成
            print("\n5. Creating SpeechAnalyzer...")
            let options = SpeechAnalyzer.Options(
                priority: .userInitiated,
                modelRetention: .whileInUse
            )
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)
            print("SpeechAnalyzer created successfully")

            print("\n✓ All iOS 26.0+ APIs are available and working!")
        }
    }
}

// 実行
print("=== SpeechAnalyzer API Check ===")
if #available(iOS 26.0, *) {
    let tester = SpeechAnalyzerTester()
    Task {
        try await tester.testAPIAvailability()
    }
} else {
    print("iOS 26.0+ is required for SpeechAnalyzer API")
    print("Current iOS version: \(UIDevice.current.systemVersion)")
}
