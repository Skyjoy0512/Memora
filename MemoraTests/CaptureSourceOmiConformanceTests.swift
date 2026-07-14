import Foundation
import Testing
@testable import Memora

@MainActor
struct CaptureSourceOmiConformanceTests {
    @Test("OmiAdapter が CaptureSource として基本属性を返す")
    func omiAdapterCaptureSourceAttributes() {
        let source: any CaptureSource = OmiAdapter()

        #expect(source.sourceType == .omi)
        #expect(source.tier == .bleDirect)
    }

    @Test("configure(sink:) 経由の Omi 取込結果を OmiImportedAudio に変換する")
    func configureSinkImportsOmiAudio() async throws {
        let adapter = OmiAdapter()
        let importedID = UUID()

        adapter.configure { _, title in
            let audioFile = AudioFile(title: title ?? "Omi Import", audioURL: "/tmp/omi.m4a")
            audioFile.id = importedID
            return audioFile
        }

        let result = try await adapter.testImportAudioForCaptureSource(
            audioURL: URL(fileURLWithPath: "/tmp/omi.m4a"),
            title: "Omi 会議"
        )

        #expect(result.audioFileID == importedID)
        #expect(result.title == "Omi 会議")
    }
}
