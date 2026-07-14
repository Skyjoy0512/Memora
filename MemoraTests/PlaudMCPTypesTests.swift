import Foundation
import Testing
@testable import Memora

@Suite("PLAUD MCP DTO")
struct PlaudMCPTypesTests {
    @Test("snake caseの録音詳細をMemoraのDTOへ変換する")
    func decodesRecordingDetail() throws {
        let data = """
        {
          "id": "remote-1",
          "name": "Weekly sync",
          "created_at": "2026-07-14T00:00:00Z",
          "duration": 125000,
          "presigned_url": "https://example.com/audio.m4a",
          "source_list": [{"start": 2.0, "text": "Hello", "speaker": "Speaker 1"}],
          "note_list": ["- Follow up"]
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(PlaudMCPFile.self, from: data)

        #expect(file.id == "remote-1")
        #expect(file.durationMilliseconds == 125000)
        #expect(file.presignedURL?.host == "example.com")
        #expect(file.sourceList.first?.formattedLine == "00:02 Speaker 1 Hello")
    }

    @Test("オブジェクト形式のノート本文を取り込む")
    func decodesObjectNotes() throws {
        let data = """
        {
          "id": "remote-2",
          "note_list": [{"content": "決定事項: 次週に確認"}]
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(PlaudMCPFile.self, from: data)

        #expect(file.noteList == ["決定事項: 次週に確認"])
    }
}
