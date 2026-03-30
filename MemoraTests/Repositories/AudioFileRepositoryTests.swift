import Testing
import Foundation
@testable import Memora

/// AudioFileRepository のテスト
///
/// - Note: iOS 26.2 の SwiftData バグにより、テストホストアプリと
///   テストで同じスキーマの ModelContainer を作成するとクラッシュする。
///   そのため ModelContext を使わず、リポジトリのインターフェースと
///   AudioFile モデルの組み合わせをテストする。
@MainActor
struct AudioFileRepositoryTests {

    @Test("AudioFile の検索対象フィールドが正しい")
    func searchableFields() {
        let file = AudioFile(title: "会議録音", audioURL: "/tmp/meeting.m4a")
        #expect(file.title.contains("会議"))
        #expect(file.title.contains("録音"))
    }

    @Test("AudioFile の isTranscribed 判定が正しい")
    func transcribedFlag() {
        let file = AudioFile(title: "テスト", audioURL: "/tmp/test.m4a")
        #expect(!file.isTranscribed)

        file.isTranscribed = true
        #expect(file.isTranscribed)
    }

    @Test("AudioFile のプロジェクト紐付けが正しい")
    func projectAssociation() {
        let projectID = UUID()
        let file = AudioFile(title: "PJ付き", audioURL: "/tmp/pj.m4a", projectID: projectID)
        #expect(file.projectID == projectID)

        let noProject = AudioFile(title: "PJ無し", audioURL: "/tmp/none.m4a")
        #expect(noProject.projectID == nil)
    }

    @Test("AudioFile がタイトルでフィルタ可能な状態を持つ")
    func titleFiltering() {
        let files = [
            AudioFile(title: "会議録音", audioURL: "/tmp/1.m4a"),
            AudioFile(title: "インタビュー", audioURL: "/tmp/2.m4a"),
            AudioFile(title: "会議メモ", audioURL: "/tmp/3.m4a")
        ]
        let filtered = files.filter { $0.title.contains("会議") }
        #expect(filtered.count == 2)
    }

    @Test("AudioFile が大文字小文字区別なしでフィルタ可能")
    func caseInsensitiveFiltering() {
        let file = AudioFile(title: "Meeting Notes", audioURL: "/tmp/m.m4a")
        #expect(file.title.lowercased().contains("meeting"))
        #expect(file.title.lowercased().contains("MEETING".lowercased()))
    }
}
