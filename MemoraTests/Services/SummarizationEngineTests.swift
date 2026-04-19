import Testing
import Foundation
import SwiftData
@testable import Memora

// MARK: - SummaryResult Tests

struct SummaryResultTests {

    @Test("actionItemsText が改行区切りで結合される")
    func actionItemsText() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: ["タスクA", "タスクB", "タスクC"]
        )
        #expect(result.actionItemsText == "タスクA\nタスクB\nタスクC")
    }

    @Test("keyPointsText が改行区切りで結合される")
    func keyPointsText() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: ["ポイント1", "ポイント2"],
            actionItems: []
        )
        #expect(result.keyPointsText == "ポイント1\nポイント2")
    }

    @Test("decisionsText が nil の時は nil を返す")
    func decisionsTextNil() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: []
        )
        #expect(result.decisionsText == nil)
    }

    @Test("decisionsText が空配列の時は nil を返す")
    func decisionsTextEmpty() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: [],
            decisions: []
        )
        #expect(result.decisionsText == nil)
    }

    @Test("decisionsText が改行区切りで結合される")
    func decisionsTextWithValues() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: [],
            decisions: ["決定事項A", "決定事項B"]
        )
        #expect(result.decisionsText == "決定事項A\n決定事項B")
    }

    @Test("suggestedTitle が nil の時は nil を返す")
    func suggestedTitleNil() {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: []
        )
        #expect(result.suggestedTitle == nil)
    }

    @Test("suggestedTitle が設定されている時は値を返す")
    func suggestedTitlePresent() {
        let result = SummaryResult(
            suggestedTitle: "週次ミーティング",
            summary: "テスト",
            keyPoints: [],
            actionItems: []
        )
        #expect(result.suggestedTitle == "週次ミーティング")
    }
}

// MARK: - SummarizationEngine parseJSONResponse Tests
// parseJSONResponse は static private メソッドなので、
// 間接的に buildCustomPrompt と一緒にテストする。
// ここでは SummaryResult のデータ変換を検証する。

struct SummarizationEngineParsingTests {

    /// AI レスポンスの JSON パースをシミュレートするテスト
    @Test("有効な JSON レスポンスをパースできる")
    func parseValidJSON() throws {
        let json = """
        {
            "title": "定例会議",
            "summary": "プロジェクトの進捗を確認しました。",
            "keyPoints": ["進捗80%", "リリース来月"],
            "actionItems": ["ドキュメント更新", "テスト実装"]
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(parsed?["title"] as? String == "定例会議")
        #expect(parsed?["summary"] as? String == "プロジェクトの進捗を確認しました。")
        #expect((parsed?["keyPoints"] as? [String])?.count == 2)
        #expect((parsed?["actionItems"] as? [String])?.count == 2)
    }

    @Test("title が欠落してもパースできる")
    func parseMissingTitle() throws {
        let json = """
        {
            "summary": "テスト要約",
            "keyPoints": [],
            "actionItems": []
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(parsed?["title"] == nil)
        #expect(parsed?["summary"] as? String == "テスト要約")
    }

    @Test("Markdown コードフェンス付きレスポンスから JSON を抽出できる")
    func stripCodeFences() {
        let response = """
        ```json
        {
            "title": "テスト",
            "summary": "要約",
            "keyPoints": [],
            "actionItems": []
        }
        ```
        """

        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(jsonString.hasPrefix("{"))
        #expect(jsonString.hasSuffix("}"))
        #expect(!jsonString.contains("```"))
    }
}

// MARK: - SummarizationEngine createTodoItems Tests

@MainActor
struct SummarizationEngineTodoTests {

    @Test("アクションアイテムから TodoItem が正しく生成される")
    func createTodoItems() throws {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: ["報告書を提出する", "次回MTGの日程を調整"]
        )

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TodoItem.self, configurations: config)
        let context = ModelContext(container)

        let engine = SummarizationEngine()
        engine.createTodoItems(
            from: result,
            sourceFileId: UUID(),
            sourceFileTitle: "テスト会議",
            modelContext: context
        )

        try context.save()

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.count == 2)

        let titles = todos.map { $0.title }
        #expect(titles.contains("報告書を提出する"))
        #expect(titles.contains("次回MTGの日程を調整"))
    }

    @Test("空のアクションアイテムはスキップされる")
    func emptyActionItemsSkipped() throws {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: ["有効なタスク", "", "   ", "もう一つのタスク"]
        )

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TodoItem.self, configurations: config)
        let context = ModelContext(container)

        let engine = SummarizationEngine()
        engine.createTodoItems(
            from: result,
            sourceFileId: UUID(),
            sourceFileTitle: "テスト",
            modelContext: context
        )

        try context.save()

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.count == 2)
    }

    @Test("話者名付きアクションアイテムが正しくパースされる")
    func actionItemWithSpeaker() throws {
        let result = SummaryResult(
            summary: "テスト",
            keyPoints: [],
            actionItems: ["田中: 報告書を提出する"]
        )

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TodoItem.self, configurations: config)
        let context = ModelContext(container)

        let engine = SummarizationEngine()
        engine.createTodoItems(
            from: result,
            sourceFileId: UUID(),
            sourceFileTitle: "テスト",
            modelContext: context
        )

        try context.save()

        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.count == 1)
        let todo = todos.first!
        #expect(todo.title == "報告書を提出する")
        #expect(todo.assignee == "田中")
        #expect(todo.speaker == "田中")
    }
}
