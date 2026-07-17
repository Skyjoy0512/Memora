// 手動実行専用（CIには含めない）:
// 1. Xcodeで Packages/MemoraSharedData/Package.swift を開き、iOS Simulatorを選ぶ。
// 2. テストSchemeの環境変数 MEMORA_RUN_STT_CER=1 を設定する。
// 3. JapaneseSTTFixtureCERTests を実行する。
// 音声認識の言語資産・認可状態に依存するため、STTコア変更PRでは上記手順の結果をPRへ記録する。

#if targetEnvironment(simulator)
import Foundation
import Speech
import Testing

@Suite("Japanese STT fixture CER", .enabled(if: ProcessInfo.processInfo.environment["MEMORA_RUN_STT_CER"] == "1"))
struct JapaneseSTTFixtureCERTests {
    @Test("固定日本語短尺フィクスチャのCERが35%以下", .timeLimit(.minutes(1)))
    func fixtureCharacterErrorRateIsWithinThreshold() async throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP")),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            try Test.cancel("ja_JPのオンデバイスSFSpeechRecognizerがSimulatorで利用できません")
        }

        let audioURL = fixtureURL(named: "stt_japanese_short.aiff")
        let expected = try String(contentsOf: fixtureURL(named: "stt_japanese_short.expected.txt"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        if #available(iOS 16.0, *) { request.addsPunctuation = true }

        let actual = try await recognize(request: request, recognizer: recognizer)
        #expect(characterErrorRate(actual: actual, expected: expected) <= 0.35)
    }
}

private func fixtureURL(named name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent(name)
}

private func recognize(request: SFSpeechURLRecognitionRequest, recognizer: SFSpeechRecognizer) async throws -> String {
    let gate = RecognitionContinuationGate()
    return try await withCheckedThrowingContinuation { continuation in
        gate.install(continuation)
        let task = recognizer.recognitionTask(with: request) { result, error in
            if let error { gate.fail(error) }
            if let result, result.isFinal { gate.succeed(result.bestTranscription.formattedString) }
        }
        gate.installCancellation { task.cancel() }
    }
}

private func characterErrorRate(actual: String, expected: String) -> Double {
    let actualCharacters = Array(normalize(actual))
    let expectedCharacters = Array(normalize(expected))
    guard !expectedCharacters.isEmpty else { return actualCharacters.isEmpty ? 0 : 1 }

    var previous = Array(0...expectedCharacters.count)
    for (actualIndex, actualCharacter) in actualCharacters.enumerated() {
        var current = [actualIndex + 1]
        for (expectedIndex, expectedCharacter) in expectedCharacters.enumerated() {
            let substitutionCost = actualCharacter == expectedCharacter ? 0 : 1
            current.append(min(
                previous[expectedIndex + 1] + 1,
                current[expectedIndex] + 1,
                previous[expectedIndex] + substitutionCost
            ))
        }
        previous = current
    }
    return Double(previous[expectedCharacters.count]) / Double(expectedCharacters.count)
}

private func normalize(_ text: String) -> String {
    text.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
}

private final class RecognitionContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var cancellation: (() -> Void)?
    private var isFinished = false

    func install(_ continuation: CheckedContinuation<String, Error>) {
        lock.withLock { self.continuation = continuation }
    }

    func installCancellation(_ cancellation: @escaping () -> Void) {
        let shouldCancel = lock.withLock { () -> Bool in
            guard !isFinished else { return true }
            self.cancellation = cancellation
            return false
        }
        if shouldCancel { cancellation() }
    }

    func succeed(_ value: String) { finish(.success(value)) }
    func fail(_ error: Error) { finish(.failure(error)) }

    private func finish(_ result: Result<String, Error>) {
        let completion = lock.withLock { () -> (CheckedContinuation<String, Error>?, (() -> Void)?) in
            guard !isFinished else { return (nil, nil) }
            isFinished = true
            let continuation = self.continuation
            let cancellation = self.cancellation
            self.continuation = nil
            self.cancellation = nil
            return (continuation, cancellation)
        }
        completion.1?()
        completion.0?.resume(with: result)
    }
}
#endif
