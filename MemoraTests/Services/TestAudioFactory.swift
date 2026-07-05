import Foundation
import AVFoundation

// MARK: - Test Audio Factory (PR-E1)

enum TestAudioFactory {
    /// 指定秒数の 440Hz 正弦波 WAV を一時ディレクトリに生成
    static func makeSineWAV(
        seconds: Double,
        sampleRate: Double = 16_000
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_sine_\(UUID().uuidString).wav")
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let frameCount = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "TestAudioFactory", code: -1)
        }
        buffer.frameLength = frameCount
        let frequency: Float = 440
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Float(i) / Float(sampleRate)
                channel[i] = sin(2 * .pi * frequency * t) * 0.3
            }
        }
        let file = try AVAudioFile(
            forWriting: tmp,
            settings: format.settings
        )
        try file.write(from: buffer)
        return tmp
    }

    /// 前半 tone（正弦波）+ 後半無音の WAV
    static func makeToneThenSilenceWAV(
        toneSeconds: Double,
        silenceSeconds: Double,
        sampleRate: Double = 16_000
    ) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_tone_silence_\(UUID().uuidString).wav")
        let totalSeconds = toneSeconds + silenceSeconds
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let frameCount = AVAudioFrameCount(totalSeconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "TestAudioFactory", code: -1)
        }
        buffer.frameLength = frameCount
        let frequency: Float = 440
        let toneFrames = Int(toneSeconds * sampleRate)
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                if i < toneFrames {
                    let t = Float(i) / Float(sampleRate)
                    channel[i] = sin(2 * .pi * frequency * t) * 0.3
                } else {
                    channel[i] = 0
                }
            }
        }
        let file = try AVAudioFile(
            forWriting: tmp,
            settings: format.settings
        )
        try file.write(from: buffer)
        return tmp
    }
}
