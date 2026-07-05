import Testing
import Foundation
@testable import Memora

/// テスト用の共通ヘルパー
///
/// - Note: iOS 26.2 Simulator において、テストホストアプリが既に ModelContainer を
///   作成している状態で同じスキーマの別 ModelContainer を作成すると
///   SwiftData が EXC_BREAKPOINT を起こすバグがある。
///   そのため ModelContext を使ったテストは不可。
///   @Model オブジェクトのプロパティテストのみ実行する。
enum TestModelContainer {
}

struct STTCoreTests {
    @Test("オンデバイス認識タイムアウトは専用メッセージを返す")
    func onDeviceTimeoutErrorMessage() {
        let error = OnDeviceTranscriptionTimeoutError()
        #expect(error.errorDescription == OnDeviceTranscriptionTimeoutError.message)
    }

    @Test("オンデバイス認識タイムアウトは CoreError へ変換される")
    func onDeviceTimeoutMapsToCoreError() {
        let mapped = STTErrorMapper.mapToCoreError(OnDeviceTranscriptionTimeoutError())

        #expect(
            mapped == .transcriptionError(
                .transcriptionFailed(OnDeviceTranscriptionTimeoutError.message)
            )
        )
    }
}

// MARK: - Test Audio Factory

/// テスト用のプログラム合成音声を生成する。
/// 外部バイナリファイル不要で、setUp で生成し tearDown で削除する運用を想定。
enum TestAudioFactory {
    /// 440Hz 正弦波の WAV を指定秒数分生成する。
    /// サンプル形式: Int16 PCM, 16kHz, 1ch, WAV コンテナ。
    static func makeSineWAV(seconds: Double, sampleRate: Double = 16_000) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_sine_\(UUID().uuidString).wav")
        let sampleCount = Int(seconds * sampleRate)
        var samples = [Int16](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            samples[i] = Int16(sin(2 * .pi * 440 * t) * 16000)
        }
        try writeWAV(url: url, samples: samples, sampleRate: Int32(sampleRate), channels: 1, bitsPerSample: 16)
        return url
    }

    /// 前半が音声（正弦波）、後半が無音の WAV を生成する。
    /// AudioSilenceProbe のテスト用。
    static func makeToneThenSilenceWAV(toneSeconds: Double, silenceSeconds: Double, sampleRate: Double = 16_000) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_tone_silence_\(UUID().uuidString).wav")
        let total = Int((toneSeconds + silenceSeconds) * sampleRate)
        var samples = [Int16](repeating: 0, count: total)
        let toneSamples = Int(toneSeconds * sampleRate)
        for i in 0..<min(toneSamples, total) {
            let t = Double(i) / sampleRate
            samples[i] = Int16(sin(2 * .pi * 440 * t) * 16000)
        }
        try writeWAV(url: url, samples: samples, sampleRate: Int32(sampleRate), channels: 1, bitsPerSample: 16)
        return url
    }

    private static func writeWAV(url: URL, samples: [Int16], sampleRate: Int32, channels: Int16, bitsPerSample: Int16) throws {
        let dataSize = Int32(samples.count * 2)
        let fileSize = 36 + dataSize
        var data = Data()

        func appendInt32(_ v: Int32) { var v = v; data.append(Data(bytes: &v, count: 4)) }
        func appendInt16(_ v: Int16) { var v = v; data.append(Data(bytes: &v, count: 2)) }
        func appendString(_ s: String) { data.append(s.data(using: .ascii)!) }

        // RIFF header
        appendString("RIFF")
        appendInt32(fileSize)
        appendString("WAVE")
        // fmt chunk
        appendString("fmt ")
        appendInt32(16)          // chunk size
        appendInt16(1)           // PCM
        appendInt16(channels)
        appendInt32(sampleRate)
        appendInt32(sampleRate * Int32(channels) * Int32(bitsPerSample / 8)) // byte rate
        appendInt16(channels * (bitsPerSample / 8))  // block align
        appendInt16(bitsPerSample)
        // data chunk
        appendString("data")
        appendInt32(dataSize)
        samples.withUnsafeBytes { buf in
            data.append(Data(buf))
        }

        try data.write(to: url)
    }
}

// MARK: - LockedBox (Concurrency Helper)

/// スレッドセーフな値の読み書きラッパー。
final class LockedBox<Value>: @unchecked Sendable {
    private var _value: Value
    private let lock = NSLock()
    init(_ value: Value) { self._value = value }
    func get() -> Value { lock.lock(); defer { lock.unlock() }; return _value }
    func set(_ value: Value) { lock.lock(); defer { lock.unlock() }; _value = value }
    func mutate(_ body: (inout Value) -> Void) { lock.lock(); defer { lock.unlock() }; body(&_value) }
}
