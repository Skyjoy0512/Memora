import Foundation
import Testing
@testable import Memora

struct ImportRouterTests {
    @Test("同名の音声とJSONをPLA​​UDエクスポートとして分類する")
    func routesAudioAndJSONAsPlaudExport() {
        let routes = ImportRouter.route([url("meeting.m4a"), url("meeting.json")])

        #expect(routes.count == 1)
        guard case let .plaudExport(audio, json) = routes.first else {
            Issue.record("Expected plaudExport route")
            return
        }
        #expect(audio.lastPathComponent == "meeting.m4a")
        #expect(json.lastPathComponent == "meeting.json")
    }

    @Test("同名の音声とTXTを参照文字起こしとして分類する")
    func routesAudioAndTextAsPlaudTranscript() {
        let routes = ImportRouter.route([url("interview.wav"), url("interview.txt")])

        #expect(routes.count == 1)
        guard case let .plaudTranscript(audio, text) = routes.first else {
            Issue.record("Expected plaudTranscript route")
            return
        }
        #expect(audio.lastPathComponent == "interview.wav")
        #expect(text.lastPathComponent == "interview.txt")
    }

    @Test("音声のみとテキストのみをそれぞれ保持して分類する")
    func routesStandaloneFilesWithoutDroppingThem() {
        let routes = ImportRouter.route([url("recorder.caf"), url("notes.txt"), url("export.json")])

        #expect(routes.count == 3)
        #expect(routes.contains { if case .audioOnly(let file) = $0 { file.lastPathComponent == "recorder.caf" } else { false } })
        #expect(routes.contains { if case .textOnly(let file) = $0 { file.lastPathComponent == "notes.txt" } else { false } })
        #expect(routes.contains { if case .textOnly(let file) = $0 { file.lastPathComponent == "export.json" } else { false } })
    }

    @Test("JSONを優先し、余った同名TXTはテキストのみとして残す")
    func preservesUnusedSameBasenameText() {
        let routes = ImportRouter.route([url("memo.mp3"), url("memo.json"), url("memo.txt")])

        #expect(routes.count == 2)
        #expect(routes.contains { if case .plaudExport = $0 { true } else { false } })
        #expect(routes.contains { if case .textOnly(let file) = $0 { file.lastPathComponent == "memo.txt" } else { false } })
    }

    private func url(_ filename: String) -> URL {
        URL(fileURLWithPath: "/tmp/ImportRouterTests/\(filename)")
    }
}
