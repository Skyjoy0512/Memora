import Foundation

// MARK: - DTOs

struct PlannedTask: Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let assignee: String?
    let priority: TodoPriority
    let relativeDueDate: RelativeDueDate?
    let citation: String?
    let subtasks: [PlannedSubtask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        assignee: String? = nil,
        priority: TodoPriority = .medium,
        relativeDueDate: RelativeDueDate? = nil,
        citation: String? = nil,
        subtasks: [PlannedSubtask] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.assignee = assignee
        self.priority = priority
        self.relativeDueDate = relativeDueDate
        self.citation = citation
        self.subtasks = subtasks
    }
}

struct PlannedSubtask: Identifiable {
    let id: UUID
    let title: String
    let citation: String?

    init(id: UUID = UUID(), title: String, citation: String? = nil) {
        self.id = id
        self.title = title
        self.citation = citation
    }
}

// MARK: - Service

@MainActor
final class TaskPlannerService {

    private var aiService: AIService?

    func configure(apiKey: String, provider: AIProvider) async throws {
        let service = AIService()
        service.setProvider(provider)
        try await service.configure(apiKey: apiKey)
        self.aiService = service
    }

    /// transcript + summary から構造化タスクを抽出する。
    /// AI が返す keyPoints をパイプ区切りでパースし、PlannedTask 配列に変換する。
    /// actionItems はサブタスクとして親タスクに紐付ける。
    func planTasks(
        transcript: String,
        summary: String?
    ) async throws -> [PlannedTask] {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        let combinedText = buildPlanningInput(transcript: transcript, summary: summary)
        guard !combinedText.isEmpty else { return [] }

        let (_, keyPoints, actionItems) = try await service.summarize(transcript: combinedText)

        var tasks = parseTasks(from: keyPoints)
        attachSubtasks(from: actionItems, to: &tasks)

        return tasks
    }

    /// 単一タスクをサブタスクに分解する（UI の「AIで分解」ボタン用）。
    func decomposeTask(
        taskTitle: String,
        taskNotes: String?,
        context: String
    ) async throws -> [PlannedSubtask] {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        let input = """
        以下のタスクを2〜4個の具体的なサブタスクに分解してください。
        各サブタスクは実行可能な単位にしてください。

        タスク: \(taskTitle)
        \(taskNotes != nil ? "メモ: \(taskNotes!)" : "")

        関連コンテキスト:
        \(String(context.prefix(2000)))

        出力形式:
        summary: "分解結果"
        keyPoints: ["サブタスク1", "サブタスク2", "サブタスク3"]
        actionItems: []
        """

        let (_, keyPoints, _) = try await service.summarize(transcript: input)

        return keyPoints.enumerated().map { index, point in
            PlannedSubtask(
                id: UUID(),
                title: point.trimmingCharacters(in: .whitespacesAndNewlines),
                citation: nil
            )
        }
    }

    // MARK: - Private

    private func buildPlanningInput(transcript: String, summary: String?) -> String {
        var parts: [String] = []

        parts.append("""
        以下の会議内容から、実行可能なタスクを抽出してください。
        各タスクについて以下を推定し、"|" 区切りで出力:
        タイトル | 優先度(high/medium/low) | 担当者 | 期限(明日/来週/来月/ASAP/なし) | 根拠となる発言

        さらに、大きなタスクはサブタスクに分解してください。
        サブタスクは以下の形式で出力:
        サブタスクタイトル | 親タスクのタイトル | 根拠

        出力形式:
        summary: "タスク抽出の概要"
        keyPoints: ["タスクタイトル | 優先度 | 担当者 | 期限 | 根拠発言"]
        actionItems: ["サブタスクタイトル | 親タスクタイトル | 根拠"]
        """)

        if let summary, !summary.isEmpty {
            parts.append("要約:\n\(summary)")
        }

        let transcriptExcerpt = String(transcript.prefix(4000))
        parts.append("文字起こし:\n\(transcriptExcerpt)")

        return parts.joined(separator: "\n\n")
    }

    /// "タスクタイトル | high | 田中 | 来週 | 発言引用" → PlannedTask
    private func parseTasks(from keyPoints: [String]) -> [PlannedTask] {
        keyPoints.compactMap { point in
            let components = point.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard components.count >= 1 else { return nil }

            let title = components[0]
            guard !title.isEmpty else { return nil }

            let priority = parsePriority(components.count > 1 ? components[1] : "")
            let assignee = components.count > 2 && !components[2].isEmpty ? components[2] : nil
            let dueDate = parseRelativeDueDate(components.count > 3 ? components[3] : "")
            let citation = components.count > 4 && !components[4].isEmpty ? components[4] : nil

            return PlannedTask(
                title: title,
                assignee: assignee,
                priority: priority,
                relativeDueDate: dueDate,
                citation: citation,
                subtasks: []
            )
        }
    }

    /// "サブタスク | 親タスクタイトル | 根拠" → 親 PlannedTask の subtasks に追加
    private func attachSubtasks(from actionItems: [String], to tasks: inout [PlannedTask]) {
        for item in actionItems {
            let components = item.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard components.count >= 2 else { continue }

            let subtaskTitle = components[0]
            let parentTitle = components[1]
            let citation = components.count > 2 && !components[2].isEmpty ? components[2] : nil

            guard !subtaskTitle.isEmpty, !parentTitle.isEmpty else { continue }

            let subtask = PlannedSubtask(title: subtaskTitle, citation: citation)

            if let index = tasks.firstIndex(where: {
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare(parentTitle) == .orderedSame
            }) {
                tasks[index] = PlannedTask(
                    id: tasks[index].id,
                    title: tasks[index].title,
                    notes: tasks[index].notes,
                    assignee: tasks[index].assignee,
                    priority: tasks[index].priority,
                    relativeDueDate: tasks[index].relativeDueDate,
                    citation: tasks[index].citation,
                    subtasks: tasks[index].subtasks + [subtask]
                )
            }
        }
    }

    private func parsePriority(_ raw: String) -> TodoPriority {
        let lowered = raw.lowercased()
        if lowered.contains("high") || lowered.contains("高") { return .high }
        if lowered.contains("low") || lowered.contains("低") { return .low }
        return .medium
    }

    private func parseRelativeDueDate(_ raw: String) -> RelativeDueDate? {
        let lowered = raw.lowercased()
        if lowered.contains("明日") || lowered.contains("tomorrow") { return .tomorrow }
        if lowered.contains("来週") || lowered.contains("next week") { return .nextWeek }
        if lowered.contains("来月") || lowered.contains("next month") { return .nextMonth }
        if lowered.contains("asap") || lowered.contains("緊急") || lowered.contains("すぐ") { return .asap }
        if lowered.contains("なし") || lowered.contains("none") || lowered.isEmpty { return nil }
        return nil
    }
}
