import Testing
import Foundation
@testable import Memora

struct TaskPlannerServiceTests {

    // MARK: - PlannedTask

    @Test("PlannedTask の初期値が正しい")
    func plannedTaskDefaults() {
        let task = PlannedTask(title: "デザインレビュー")
        #expect(task.title == "デザインレビュー")
        #expect(task.notes == nil)
        #expect(task.assignee == nil)
        #expect(task.priority == .medium)
        #expect(task.relativeDueDate == nil)
        #expect(task.citation == nil)
        #expect(task.subtasks.isEmpty)
    }

    @Test("PlannedTask の全パラメータが正しく設定される")
    func plannedTaskAllParams() {
        let subtask = PlannedSubtask(title: "資料作成", citation: "田中が担当")
        let task = PlannedTask(
            title: "Sprint Review",
            notes: "今週の成果を共有",
            assignee: "佐藤",
            priority: .high,
            relativeDueDate: .nextWeek,
            citation: "次回のレビューは来週",
            subtasks: [subtask]
        )
        #expect(task.title == "Sprint Review")
        #expect(task.notes == "今週の成果を共有")
        #expect(task.assignee == "佐藤")
        #expect(task.priority == .high)
        #expect(task.relativeDueDate == .nextWeek)
        #expect(task.citation == "次回のレビューは来週")
        #expect(task.subtasks.count == 1)
        #expect(task.subtasks[0].title == "資料作成")
    }

    @Test("PlannedTask の ID が自動生成される")
    func plannedTaskID() {
        let task1 = PlannedTask(title: "A")
        let task2 = PlannedTask(title: "A")
        #expect(task1.id != task2.id)
    }

    // MARK: - PlannedSubtask

    @Test("PlannedSubtask の初期値が正しい")
    func plannedSubtaskDefaults() {
        let sub = PlannedSubtask(title: "テスト実行")
        #expect(sub.title == "テスト実行")
        #expect(sub.citation == nil)
    }

    @Test("PlannedSubtask の citation が設定される")
    func plannedSubtaskWithCitation() {
        let sub = PlannedSubtask(title: "バグ修正", citation: "3ページ目に記載")
        #expect(sub.title == "バグ修正")
        #expect(sub.citation == "3ページ目に記載")
    }

    // MARK: - TodoPriority

    @Test("TodoPriority の rawValue が正しい")
    func todoPriorityRawValues() {
        #expect(TodoPriority.high.rawValue == "high")
        #expect(TodoPriority.medium.rawValue == "medium")
        #expect(TodoPriority.low.rawValue == "low")
        #expect(TodoPriority.allCases.count == 3)
    }

    @Test("TodoPriority が String から初期化できる")
    func todoPriorityFromString() {
        #expect(TodoPriority(rawValue: "high") == .high)
        #expect(TodoPriority(rawValue: "medium") == .medium)
        #expect(TodoPriority(rawValue: "low") == .low)
        #expect(TodoPriority(rawValue: "unknown") == nil)
    }

    // MARK: - RelativeDueDate

    @Test("RelativeDueDate の rawValue が正しい")
    func relativeDueDateRawValues() {
        #expect(RelativeDueDate.tomorrow.rawValue == "tomorrow")
        #expect(RelativeDueDate.nextWeek.rawValue == "next_week")
        #expect(RelativeDueDate.nextMonth.rawValue == "next_month")
        #expect(RelativeDueDate.asap.rawValue == "asap")
        #expect(RelativeDueDate.allCases.count == 4)
    }

    @Test("RelativeDueDate が String から初期化できる")
    func relativeDueDateFromString() {
        #expect(RelativeDueDate(rawValue: "tomorrow") == .tomorrow)
        #expect(RelativeDueDate(rawValue: "next_week") == .nextWeek)
        #expect(RelativeDueDate(rawValue: "next_month") == .nextMonth)
        #expect(RelativeDueDate(rawValue: "asap") == .asap)
        #expect(RelativeDueDate(rawValue: "never") == nil)
    }

    // MARK: - PlannedTask with nested subtasks

    @Test("PlannedTask に複数 subtasks を含められる")
    func plannedTaskMultipleSubtasks() {
        let subs = [
            PlannedSubtask(title: "要件定義"),
            PlannedSubtask(title: "設計", citation: "議事録2ページ"),
            PlannedSubtask(title: "実装")
        ]
        let task = PlannedTask(title: "機能開発", subtasks: subs)
        #expect(task.subtasks.count == 3)
        #expect(task.subtasks[0].title == "要件定義")
        #expect(task.subtasks[1].citation == "議事録2ページ")
        #expect(task.subtasks[2].title == "実装")
    }

    @Test("PlannedTask の priority バリエーション")
    func plannedTaskPriorityVariations() {
        let high = PlannedTask(title: "高", priority: .high)
        let medium = PlannedTask(title: "中", priority: .medium)
        let low = PlannedTask(title: "低", priority: .low)
        #expect(high.priority == .high)
        #expect(medium.priority == .medium)
        #expect(low.priority == .low)
    }

    @Test("PlannedTask の relativeDueDate バリエーション")
    func plannedTaskDueDateVariations() {
        let tomorrow = PlannedTask(title: "A", relativeDueDate: .tomorrow)
        let nextWeek = PlannedTask(title: "B", relativeDueDate: .nextWeek)
        let nextMonth = PlannedTask(title: "C", relativeDueDate: .nextMonth)
        let asap = PlannedTask(title: "D", relativeDueDate: .asap)
        #expect(tomorrow.relativeDueDate == .tomorrow)
        #expect(nextWeek.relativeDueDate == .nextWeek)
        #expect(nextMonth.relativeDueDate == .nextMonth)
        #expect(asap.relativeDueDate == .asap)
    }
}
