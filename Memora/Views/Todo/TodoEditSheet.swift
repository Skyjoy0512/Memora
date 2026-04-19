import SwiftUI
import SwiftData

// MARK: - Todo Edit Sheet

struct TodoEditSheet: View {
    enum Mode {
        case create
        case edit(TodoItem)

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    @State private var title = ""
    @State private var notes = ""
    @State private var assignee = ""
    @State private var speaker = ""
    @State private var projectID: UUID?
    @State private var priority = "medium"
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @State private var showBreakdownSheet = false
    @State private var acceptedBreakdown: TaskBreakdownApplyResult?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)

                    TextField("担当者", text: $assignee)

                    TextField("発言者", text: $speaker)
                }

                Section {
                    Picker("優先度", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            HStack {
                                Text(p.label)
                            }.tag(p.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: Binding(
                        get: { dueDate != nil },
                        set: { if !$0 { dueDate = nil; showDatePicker = false } else { dueDate = Date().addingTimeInterval(86400) } }
                    )) {
                        Text("期限を設定")
                    }

                    if !projects.isEmpty {
                        Picker("プロジェクト", selection: $projectID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(projects) { project in
                                Text(project.title)
                                    .tag(Optional(project.id))
                            }
                        }
                    }

                    if dueDate != nil {
                        DatePicker(
                            "期限",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("詳細")
                }

                Section {
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("メモ")
                }

                Section {
                    Button {
                        showBreakdownSheet = true
                    } label: {
                        HStack(spacing: MemoraSpacing.sm) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(MemoraColor.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AIで分解")
                                    .font(MemoraTypography.subheadline)
                                    .foregroundStyle(.primary)
                                Text("親タスクを subtasks の下書きに分けます")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("AI")
                }

                if let acceptedBreakdown {
                    Section {
                        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                            HStack {
                                Label("親タスク", systemImage: "square.stack.3d.up")
                                    .font(MemoraTypography.caption1)
                                    .foregroundStyle(MemoraColor.textSecondary)
                                Spacer()
                                Text("\(acceptedBreakdown.acceptedDrafts.count)件")
                                    .font(MemoraTypography.caption2)
                                    .foregroundStyle(MemoraColor.accentBlue)
                            }

                            Text(acceptedBreakdown.parentTitle)
                                .font(MemoraTypography.subheadline)

                            ForEach(acceptedBreakdown.acceptedDrafts) { draft in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .top) {
                                        Image(systemName: "arrow.turn.down.right")
                                            .foregroundStyle(MemoraColor.accentBlue)
                                        Text(draft.title)
                                            .font(MemoraTypography.caption1)
                                            .foregroundStyle(.primary)
                                    }

                                    if let rationale = draft.rationale, !rationale.isEmpty {
                                        Text(rationale)
                                            .font(MemoraTypography.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, MemoraSpacing.xxxs)
                    } header: {
                        Text("採用予定の Breakdown")
                    }
                }
            }
            .navigationTitle(mode.isEdit ? "ToDoを編集" : "新規ToDo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadIfEditing() }
            .sheet(isPresented: $showBreakdownSheet) {
                TaskBreakdownSheet(
                    parentTitle: title,
                    parentNotes: notes,
                    initialProjectID: projectID,
                    initialAssignee: assignee,
                    initialDueDate: dueDate,
                    onAccept: applyBreakdown
                )
            }
        }
    }

    // MARK: - Actions

    private func loadIfEditing() {
        guard case .edit(let todo) = mode else { return }
        title = todo.title
        notes = todo.notes ?? ""
        assignee = todo.assignee ?? ""
        speaker = todo.speaker ?? ""
        projectID = todo.projectID
        priority = todo.priority
        dueDate = todo.dueDate
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let parentTodo: TodoItem

        switch mode {
        case .create:
            let todo = TodoItem(
                title: trimmedTitle,
                notes: notes.isEmpty ? nil : notes,
                assignee: assignee.isEmpty ? nil : assignee,
                speaker: speaker.isEmpty ? nil : speaker,
                priority: priority,
                dueDate: dueDate,
                projectID: projectID
            )
            modelContext.insert(todo)
            parentTodo = todo
        case .edit(let todo):
            todo.title = trimmedTitle
            todo.notes = notes.isEmpty ? nil : notes
            todo.assignee = assignee.isEmpty ? nil : assignee
            todo.speaker = speaker.isEmpty ? nil : speaker
            todo.projectID = projectID
            todo.priority = priority
            todo.dueDate = dueDate
            parentTodo = todo
        }

        if let acceptedBreakdown {
            persistAcceptedBreakdown(acceptedBreakdown, parent: parentTodo)
        }

        try? modelContext.save()
        dismiss()
    }

    private func applyBreakdown(_ result: TaskBreakdownApplyResult) {
        acceptedBreakdown = result
        if !result.assignee.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            assignee = result.assignee
        }
        if let projectID = result.projectID {
            self.projectID = projectID
        }
        if let dueDate = result.dueDate {
            self.dueDate = dueDate
        }
    }

    private func persistAcceptedBreakdown(_ result: TaskBreakdownApplyResult, parent: TodoItem) {
        let resolvedAssignee = normalizedOptional(result.assignee) ?? normalizedOptional(assignee)
        let resolvedProjectID = result.projectID ?? projectID
        let resolvedDueDate = result.dueDate ?? dueDate

        for draft in result.acceptedDrafts {
            let subtask = TodoItem(
                title: draft.title,
                notes: TaskBreakdownMetadata.composeSubtaskNotes(
                    rationale: draft.rationale,
                    citations: draft.citations
                ),
                assignee: resolvedAssignee,
                priority: draft.priority,
                dueDate: resolvedDueDate,
                projectID: resolvedProjectID,
                parentID: parent.id
            )
            modelContext.insert(subtask)
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Task Breakdown Sheet

struct TaskBreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @AppStorage("selectedProvider") private var selectedProvider = "OpenAI"

    let parentTitle: String
    let parentNotes: String
    let onAccept: (TaskBreakdownApplyResult) -> Void

    @State private var drafts: [TaskBreakdownDraft]
    @State private var assignee: String
    @State private var projectID: UUID?
    @State private var dueDateEnabled: Bool
    @State private var dueDate: Date
    @State private var isGenerating = false
    @State private var generationMessage: String?
    @State private var didLoadInitialSuggestions = false

    init(
        parentTitle: String,
        parentNotes: String,
        initialProjectID: UUID?,
        initialAssignee: String,
        initialDueDate: Date?,
        onAccept: @escaping (TaskBreakdownApplyResult) -> Void
    ) {
        self.parentTitle = parentTitle
        self.parentNotes = parentNotes
        self.onAccept = onAccept
        _drafts = State(initialValue: TaskBreakdownDraft.makeInitial(parentTitle: parentTitle, notes: parentNotes))
        _assignee = State(initialValue: initialAssignee)
        _projectID = State(initialValue: initialProjectID)
        _dueDateEnabled = State(initialValue: initialDueDate != nil)
        _dueDate = State(initialValue: initialDueDate ?? Date().addingTimeInterval(86400))
    }

    private var currentProvider: AIProvider {
        AIProvider(rawValue: selectedProvider) ?? .openai
    }

    private var currentAPIKey: String {
        switch currentProvider {
        case .openai:
            return KeychainService.load(key: .apiKeyOpenAI).trimmingCharacters(in: .whitespacesAndNewlines)
        case .gemini:
            return KeychainService.load(key: .apiKeyGemini).trimmingCharacters(in: .whitespacesAndNewlines)
        case .deepseek:
            return KeychainService.load(key: .apiKeyDeepSeek).trimmingCharacters(in: .whitespacesAndNewlines)
        case .local:
            return ""
        }
    }

    private var trimmedParentTitle: String {
        parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: MemoraSpacing.xs) {
                        Label("親タスク", systemImage: "square.stack.3d.up")
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)

                        Text(parentTitle)
                            .font(MemoraTypography.title3)
                            .foregroundStyle(.primary)

                        if !parentNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(parentNotes)
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(.vertical, MemoraSpacing.xxxs)
                }

                Section {
                    TextField("担当者を一括設定", text: $assignee)

                    if !projects.isEmpty {
                        Picker("プロジェクトを一括設定", selection: $projectID) {
                            Text("未設定").tag(Optional<UUID>.none)
                            ForEach(projects) { project in
                                Text(project.title).tag(Optional(project.id))
                            }
                        }
                    }

                    Toggle("期限を一括設定", isOn: $dueDateEnabled)
                    if dueDateEnabled {
                        DatePicker("期限", selection: $dueDate, displayedComponents: .date)
                    }
                } header: {
                    Text("一括反映")
                }

                Section {
                    if isGenerating {
                        HStack(spacing: MemoraSpacing.sm) {
                            ProgressView()
                            Text("AIが subtasks を生成中です")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }
                        .padding(.vertical, MemoraSpacing.xxxs)
                    }

                    if let generationMessage, !generationMessage.isEmpty {
                        Text(generationMessage)
                            .font(MemoraTypography.caption1)
                            .foregroundStyle(MemoraColor.textSecondary)
                            .padding(.vertical, MemoraSpacing.xxxs)
                    }

                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: MemoraSpacing.sm) {
                            TextField("サブタスク", text: $draft.title)
                                .font(MemoraTypography.subheadline)

                            TextField("理由", text: Binding(
                                get: { draft.rationale ?? "" },
                                set: { draft.rationale = $0.isEmpty ? nil : $0 }
                            ), axis: .vertical)
                            .lineLimit(1...3)
                            .font(MemoraTypography.caption1)

                            Picker("優先度", selection: $draft.priority) {
                                ForEach(Priority.allCases, id: \.self) { level in
                                    Text(level.label).tag(level.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)

                            if !draft.citations.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: MemoraSpacing.xs) {
                                        ForEach(Array(draft.citations.enumerated()), id: \.offset) { _, citation in
                                            Text(citation)
                                                .font(MemoraTypography.caption2)
                                                .foregroundStyle(MemoraColor.textSecondary)
                                                .padding(.horizontal, MemoraSpacing.xs)
                                                .padding(.vertical, 6)
                                                .background(MemoraColor.divider.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                        .padding(.vertical, MemoraSpacing.xxxs)
                    }
                    .onDelete { offsets in
                        drafts.remove(atOffsets: offsets)
                    }

                    Button {
                        drafts.append(TaskBreakdownDraft.empty())
                    } label: {
                        Label("サブタスクを追加", systemImage: "plus")
                    }

                    Button {
                        Task {
                            await generateDrafts(forceFallbackMessage: false)
                        }
                    } label: {
                        Label("AI提案を再生成", systemImage: "arrow.clockwise")
                    }
                    .disabled(isGenerating || trimmedParentTitle.isEmpty)
                } header: {
                    Text("提案された Breakdown")
                }
            }
            .navigationTitle("AIで分解")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: trimmedParentTitle + parentNotes) {
                guard !didLoadInitialSuggestions else { return }
                didLoadInitialSuggestions = true
                await generateDrafts(forceFallbackMessage: true)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("採用") {
                        onAccept(
                            TaskBreakdownApplyResult(
                                parentTitle: parentTitle,
                                drafts: drafts.filter {
                                    !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                },
                                assignee: assignee,
                                projectID: projectID,
                                dueDate: dueDateEnabled ? dueDate : nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(drafts.allSatisfy {
                        $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    })
                }
            }
        }
    }

    @MainActor
    private func generateDrafts(forceFallbackMessage: Bool) async {
        guard !trimmedParentTitle.isEmpty else {
            drafts = [TaskBreakdownDraft.empty()]
            generationMessage = "親タスクのタイトルを入力すると AI 分解を実行できます。"
            return
        }

        guard !currentAPIKey.isEmpty else {
            drafts = TaskBreakdownDraft.makeInitial(parentTitle: trimmedParentTitle, notes: parentNotes)
            generationMessage = "APIキー未設定のため、タイトルとメモから下書きを作成しています。"
            return
        }

        isGenerating = true
        generationMessage = nil

        let planner = TaskPlannerService()

        do {
            try await planner.configure(apiKey: currentAPIKey, provider: currentProvider)
            let subtasks = try await planner.decomposeTask(
                taskTitle: trimmedParentTitle,
                taskNotes: normalizedOptional(parentNotes),
                context: breakdownContext()
            )

            let generatedDrafts = TaskBreakdownDraft.fromPlannedSubtasks(subtasks)
            if generatedDrafts.isEmpty {
                drafts = TaskBreakdownDraft.makeInitial(parentTitle: trimmedParentTitle, notes: parentNotes)
                generationMessage = "AI が候補を返さなかったため、タイトルとメモから下書きを作成しました。"
            } else {
                drafts = generatedDrafts
                generationMessage = forceFallbackMessage ? nil : "最新の AI 提案に更新しました。"
            }
        } catch {
            drafts = TaskBreakdownDraft.makeInitial(parentTitle: trimmedParentTitle, notes: parentNotes)
            generationMessage = "AI 分解に失敗したため、タイトルとメモから下書きを作成しました。"
        }

        isGenerating = false
    }

    private func breakdownContext() -> String {
        var sections: [String] = []

        let trimmedNotes = parentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            sections.append("メモ:\n\(trimmedNotes)")
        }

        let trimmedAssignee = assignee.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAssignee.isEmpty {
            sections.append("担当者: \(trimmedAssignee)")
        }

        if let projectID,
           let project = projects.first(where: { $0.id == projectID }) {
            sections.append("プロジェクト: \(project.title)")
        }

        if dueDateEnabled {
            sections.append("期限: \(dueDateLabel(dueDate))")
        }

        return sections.joined(separator: "\n\n")
    }

    private static let dueDateLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        return f
    }()

    private func dueDateLabel(_ date: Date) -> String {
        Self.dueDateLabelFormatter.string(from: date)
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Task Breakdown Helpers

struct TaskBreakdownApplyResult {
    let parentTitle: String
    let drafts: [TaskBreakdownDraft]
    let assignee: String
    let projectID: UUID?
    let dueDate: Date?

    var acceptedDrafts: [TaskBreakdownDraft] {
        drafts.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct TaskBreakdownDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var rationale: String?
    var citations: [String]
    var priority: String

    static func empty() -> TaskBreakdownDraft {
        TaskBreakdownDraft(
            id: UUID(),
            title: "",
            rationale: nil,
            citations: [],
            priority: Priority.medium.rawValue
        )
    }

    static func fromPlannedSubtasks(_ subtasks: [PlannedSubtask]) -> [TaskBreakdownDraft] {
        subtasks.map { subtask in
            TaskBreakdownDraft(
                id: subtask.id,
                title: subtask.title,
                rationale: nil,
                citations: subtask.citation.map { [$0] } ?? [],
                priority: Priority.medium.rawValue
            )
        }
    }

    static func makeInitial(parentTitle: String, notes: String) -> [TaskBreakdownDraft] {
        let noteLines = notes
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "•", with: "") }
            .map { $0.replacingOccurrences(of: "-", with: "") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !noteLines.isEmpty {
            return noteLines.prefix(4).map { line in
                TaskBreakdownDraft(
                    id: UUID(),
                    title: line,
                    rationale: "親タスクのメモから抽出した候補",
                    citations: [String(line.prefix(36))],
                    priority: Priority.medium.rawValue
                )
            }
        }

        let normalizedTitle = parentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            TaskBreakdownDraft(
                id: UUID(),
                title: "「\(normalizedTitle)」の要件を整理する",
                rationale: "最初にスコープを明確化するため",
                citations: ["\(normalizedTitle)"],
                priority: Priority.high.rawValue
            ),
            TaskBreakdownDraft(
                id: UUID(),
                title: "担当者と期限を確定する",
                rationale: "実行可能な task にするため",
                citations: ["担当者", "期限"],
                priority: Priority.medium.rawValue
            ),
            TaskBreakdownDraft(
                id: UUID(),
                title: "実作業を進める",
                rationale: "本体の実行ステップ",
                citations: ["実行"],
                priority: Priority.medium.rawValue
            ),
            TaskBreakdownDraft(
                id: UUID(),
                title: "結果を確認して共有する",
                rationale: "抜け漏れと認識齟齬を防ぐため",
                citations: ["確認", "共有"],
                priority: Priority.low.rawValue
            )
        ]
    }
}

enum TaskBreakdownMetadata {
    static let parentMarker = "[Parent]"
    static let rationaleMarker = "[Rationale]"
    static let citationsMarker = "[Citations]"

    static func composeSubtaskNotes(rationale: String?, citations: [String]) -> String? {
        var lines: [String] = []
        if let rationale, !rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("\(rationaleMarker) \(rationale)")
        }
        if !citations.isEmpty {
            lines.append("\(citationsMarker) \(citations.joined(separator: " / "))")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func parentTitle(from notes: String?) -> String? {
        guard let notes else { return nil }
        for line in notes.split(whereSeparator: \.isNewline) {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.hasPrefix(parentMarker) {
                return text.replacingOccurrences(of: parentMarker, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

// MARK: - Identifiable

extension TodoItem: Identifiable {}
