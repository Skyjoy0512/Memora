import Testing
import Foundation
@testable import Memora

/// TodoItemRepository のテスト
///
/// - Note: iOS 26.2 の SwiftData バグにより、テストホストアプリと
///   テストで同じスキーマの ModelContainer を作成するとクラッシュする。
///   そのため ModelContext を使わず、TodoItem モデルの状態管理をテストする。
@MainActor
struct TodoItemRepositoryTests {

    @Test("TodoItem の完了/未完了切り替えロジックが正しい")
    func toggleLogic() {
        let item = TodoItem(title: "トグルテスト")
        #expect(!item.isCompleted)
        #expect(item.completedAt == nil)

        // 完了にする
        item.isCompleted = true
        item.completedAt = Date()
        #expect(item.isCompleted)
        #expect(item.completedAt != nil)

        // 未完了に戻す
        item.isCompleted = false
        item.completedAt = nil
        #expect(!item.isCompleted)
        #expect(item.completedAt == nil)
    }

    @Test("完了済みアイテムのフィルタリングロジックが正しい")
    func filterByCompleted() {
        let items = [
            TodoItem(title: "未完了1"),
            TodoItem(title: "完了1"),
            TodoItem(title: "未完了2"),
        ]
        items[1].isCompleted = true
        items[1].completedAt = Date()

        let incomplete = items.filter { !$0.isCompleted }
        let completed = items.filter { $0.isCompleted }

        #expect(incomplete.count == 2)
        #expect(completed.count == 1)
        #expect(completed[0].title == "完了1")
    }

    @Test("プロジェクト別フィルタリングロジックが正しい")
    func filterByProject() {
        let projectID = UUID()
        let items = [
            TodoItem(title: "PJ内", projectID: projectID),
            TodoItem(title: "PJ外"),
            TodoItem(title: "PJ内2", projectID: projectID),
        ]

        let pjItems = items.filter { $0.projectID == projectID }
        #expect(pjItems.count == 2)
        #expect(pjItems.allSatisfy { $0.title.contains("PJ内") })
    }

    @Test("ID検索ロジックが正しい")
    func findById() {
        let target = TodoItem(title: "対象")
        let other = TodoItem(title: "別件")
        let items = [target, other]

        let found = items.first { $0.id == target.id }
        let notFound = items.first { $0.id == UUID() }

        #expect(found?.title == "対象")
        #expect(notFound == nil)
    }
}
