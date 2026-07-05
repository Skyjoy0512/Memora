import Testing
import Foundation
import AVFoundation
@testable import Memora

// MARK: - AudioSilenceProbe Tests

struct AudioSilenceProbeTests {

    @Test("無音区間の RMS はほぼゼロ")
    func silenceRegionHasNearZeroRMS() throws {
        let url = try TestAudioFactory.makeToneThenSilenceWAV(toneSeconds: 2, silenceSeconds: 3)
        defer { try? FileManager.default.removeItem(at: url) }

        let rms = AudioSilenceProbe.averageRMS(url: url, startSec: 2.2, endSec: 5.0)
        #expect(rms != nil)
        #expect(rms! < 0.008)
    }

    @Test("音声区間の RMS は可聴レベル")
    func toneRegionHasAudibleRMS() throws {
        let url = try TestAudioFactory.makeToneThenSilenceWAV(toneSeconds: 2, silenceSeconds: 3)
        defer { try? FileManager.default.removeItem(at: url) }

        let rms = AudioSilenceProbe.averageRMS(url: url, startSec: 0.2, endSec: 1.8)
        #expect(rms != nil)
        #expect(rms! > 0.05)
    }

    @Test("無効な範囲（開始 > 終了）は nil を返す")
    func invalidRangeReturnsNil() throws {
        let url = try TestAudioFactory.makeSineWAV(seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(AudioSilenceProbe.averageRMS(url: url, startSec: 3, endSec: 2) == nil)
    }

    @Test("短い正弦波ファイルの RMS が計算できる")
    func shortSineWaveRMS() throws {
        let url = try TestAudioFactory.makeSineWAV(seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let rms = AudioSilenceProbe.averageRMS(url: url, startSec: 0.1, endSec: 0.9)
        #expect(rms != nil)
        #expect(rms! > 0)
    }
}
