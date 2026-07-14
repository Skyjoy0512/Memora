import Foundation
import Testing
@testable import Memora

@MainActor
struct GenericFileSourceTests {
    @Test("GenericFileSource は Tier3 の CaptureSource として振る舞う")
    func genericFileSourceAttributes() {
        let source: any CaptureSource = GenericFileSource()

        #expect(source.sourceType == .genericDevice)
        #expect(source.tier == .fileImport)
        #expect(source.captureDevices.isEmpty)
        #expect(source.captureConnectionState == .idle)
    }

    @Test("importFile は対応音声ファイルを sink に渡して genericDevice として返す")
    func importSupportedFile() async throws {
        let source = GenericFileSource()
        let urlBox = LockedBox<URL?>(nil)
        let titleBox = LockedBox<String?>(nil)
        let audioURL = try TestAudioFactory.makeSineWAV(seconds: 0.1)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        source.configure { url, title in
            urlBox.set(url)
            titleBox.set(title)
            return AudioFile(title: title ?? "Imported Audio", audioURL: url.path)
        }

        let audioFile = try await source.importFile(at: audioURL)

        #expect(urlBox.get() == audioURL)
        #expect(titleBox.get() == audioURL.deletingPathExtension().lastPathComponent)
        #expect(audioFile.audioURL == audioURL.path)
        #expect(audioFile.sourceType == .genericDevice)
    }

    @Test("importFile は大文字拡張子も対応音声形式として扱う")
    func importUppercaseExtension() async throws {
        let source = GenericFileSource()
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("generic_uppercase_\(UUID().uuidString).MP3")
        try Data("dummy".utf8).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        source.configure { url, title in
            AudioFile(title: title ?? "Imported Audio", audioURL: url.path)
        }

        let audioFile = try await source.importFile(at: audioURL)

        #expect(audioFile.sourceType == .genericDevice)
        #expect(audioFile.title == audioURL.deletingPathExtension().lastPathComponent)
    }

    @Test("importFile は非対応拡張子で unsupportedFormat を投げる")
    func importUnsupportedFileThrows() async {
        let source = GenericFileSource()
        let url = URL(fileURLWithPath: "/tmp/memora-note.txt")

        await #expect(throws: CaptureError.unsupportedFormat("txt")) {
            try await source.importFile(at: url)
        }
    }

    @Test("importFile は sink 未設定なら importSinkNotConfigured を投げる")
    func importWithoutSinkThrows() async {
        let source = GenericFileSource()
        let url = URL(fileURLWithPath: "/tmp/memora-audio.wav")

        await #expect(throws: CaptureError.importSinkNotConfigured) {
            try await source.importFile(at: url)
        }
    }
}
