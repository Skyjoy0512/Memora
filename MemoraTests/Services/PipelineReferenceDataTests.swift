import Foundation
import Testing
@testable import Memora

@MainActor
struct PipelineReferenceDataTests {

    @Test("通常録音は無関係な参照テキストを受け取らない")
    func recordingWithoutExplicitReferenceDoesNotReceiveReferenceData() {
        let recording = AudioFile(title: "通常録音", audioURL: "/tmp/ordinary-recording.m4a")

        #expect(PipelineCoordinator.referenceTranscript(for: recording) == nil)
        #expect(PipelineCoordinator.referenceSpeakerCount(for: recording) == nil)
    }

    @Test("明示的に注入したテスト参照データだけを使用する")
    func explicitlyInjectedReferenceDataIsUsed() throws {
        let fixtureURL = try #require(Bundle(for: BundleToken.self).url(
            forResource: "reference-transcript-fixture",
            withExtension: "txt"
        ))
        let fixture = try String(contentsOf: fixtureURL, encoding: .utf8)
        let importedFile = AudioFile(title: "テスト用インポート", audioURL: "/tmp/imported-recording.m4a")
        importedFile.referenceTranscript = fixture
        importedFile.referenceSpeakerCount = 2

        #expect(PipelineCoordinator.referenceTranscript(for: importedFile) == fixture)
        #expect(PipelineCoordinator.referenceSpeakerCount(for: importedFile) == 2)
    }
}

private final class BundleToken {}
