import Testing
import Foundation
@testable import Memora

// MARK: - STTService makeFingerprint Tests

struct STTServiceFingerprintTests {

    @Test("異なるファイルサイズで異なるfingerprintが生成される")
    func differentSizesProduceDifferentFingerprints() async throws {
        let tmpDir = FileManager.default.temporaryDirectory

        let url1 = tmpDir.appendingPathComponent("test_audio_1.m4a")
        let url2 = tmpDir.appendingPathComponent("test_audio_2.m4a")

        // Create files with different sizes
        let data1 = Data(repeating: 0x00, count: 1024)
        let data2 = Data(repeating: 0x00, count: 4096)
        try data1.write(to: url1)
        try data2.write(to: url2)
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        let sttService = STTService()
        let fp1 = await sttService.makeFingerprint(url: url1, chunkCount: 5)
        let fp2 = await sttService.makeFingerprint(url: url2, chunkCount: 5)

        #expect(fp1 != fp2, "異なるファイルサイズで異なるfingerprintになること")
    }

    @Test("異なるchunkCountで異なるfingerprintが生成される")
    func differentChunkCountsProduceDifferentFingerprints() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("test_audio_chunk.m4a")
        let data = Data(repeating: 0x00, count: 2048)
        try data.write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let sttService = STTService()
        let fp1 = await sttService.makeFingerprint(url: url, chunkCount: 3)
        let fp2 = await sttService.makeFingerprint(url: url, chunkCount: 7)

        #expect(fp1 != fp2, "異なるchunkCountで異なるfingerprintになること")
    }

    @Test("fingerprintに文字列補間のリテラル表記が含まれない（エスケープバグがない）")
    func fingerprintDoesNotContainLiteralInterpolationSyntax() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("test_audio_format.m4a")
        let data = Data(repeating: 0xFF, count: 512)
        try data.write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let sttService = STTService()
        let fp = await sttService.makeFingerprint(url: url, chunkCount: 10)

        // バグがあると "\\(size)-\\(duration)-\\(chunkCount)" というリテラル文字列になる
        #expect(!fp.contains("\\("), "fingerprintにエスケープされた文字列補間リテラルが含まれていないこと")
        #expect(!fp.contains("size"), "fingerprintに変数名 'size' が含まれていないこと")
        #expect(!fp.contains("duration"), "fingerprintに変数名 'duration' が含まれていないこと")
        #expect(!fp.contains("chunkCount"), "fingerprintに変数名 'chunkCount' が含まれていないこと")
    }

    @Test("fingerprintが数値とハイフンで構成される")
    func fingerprintConsistsOfNumbersAndHyphens() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("test_audio_numeric.m4a")
        let data = Data(repeating: 0xAA, count: 256)
        try data.write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let sttService = STTService()
        let fp = await sttService.makeFingerprint(url: url, chunkCount: 1)

        // フォーマット: "size-duration-chunkCount" (例: "256-0-1")
        let parts = fp.split(separator: "-")
        #expect(parts.count == 3, "fingerprintは3つの数値をハイフンで結合した形式であること")

        for part in parts {
            #expect(Int(part) != nil, "各部分 '\(part)' が整数であること")
        }
    }
}
