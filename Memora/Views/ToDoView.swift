import SwiftUI
import SwiftData

struct ToDoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.repositoryFactory) private var repoFactory
    @Query(filter: #Predicate<TodoItem> { !$0.isCompleted },
           sort: \TodoItem.createdAt,
           order: .reverse)
    private var incompleteTodos: [TodoItem]

    @Query(filter: #Predicate<TodoItem> { $0.isCompleted },
           sort: \TodoItem.completedAt,
           order: .reverse)
    private var completedTodos: [TodoItem]

    @State private var showAddSheet = false
    @State private var editingTodo: TodoItem?

    var body: some View {
        NavigationStack {
            Group {
                if incompleteTodos.isEmpty && completedTodos.isEmpty {
                    emptyState
                } else {
                    todoList
                }
            }
            .navigationTitle("ToDo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(MemoraTypography.body)
                            .foregroundStyle(MemoraColor.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                TodoEditSheet(mode: .create)
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditSheet(mode: .edit(todo))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: MemoraSpacing.xxxl) {
            Spacer()

            EmptyStateView(
                icon: "checklist",
                title: "ToDoはまだありません",
                description: "議事録から自動で抽出されます",
                buttonTitle: "手動で追加",
                buttonAction: { showAddSheet = true }
            )

            Spacer()
        }
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            if !incompleteTodos.isEmpty {
                Section {
                    ForEach(incompleteTodos) { todo in
                        TodoRowView(todo: todo)
                            .onTapGesture { editingTodo = todo }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                deleteButton(todo)
                            }
                            .swipeActions(edge: .leading) {
                                completeButton(todo)
                            }
                    }
                } header: {
                    Text("未完了")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
            }

            if !completedTodos.isEmpty {
                Section {
                    ForEach(completedTodos) { todo in
                        TodoRowView(todo: todo)
                            .onTapGesture { editingTodo = todo }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                deleteButton(todo)
                            }
                    }
                } header: {
                    Text("完了済み")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Swipe Actions

    private func completeButton(_ todo: TodoItem) -> some View {
        Button {
            withAnimation {
                todo.isCompleted.toggle()
                todo.completedAt = todo.isCompleted ? Date() : nil
            }
        } label: {
            Label(todo.isCompleted ? "未完了に戻す" : "完了",
                  systemImage: todo.isCompleted ? "xmark.circle" : "checkmark.circle")
        }
        .tint(todo.isCompleted ? MemoraColor.textSecondary : MemoraColor.accentGreen)
    }

    private func deleteButton(_ todo: TodoItem) -> some View {
        Button(role: .destructive) {
            withAnimation {
                if let factory = repoFactory {
                    try? factory.todoItemRepo.delete(todo)
                } else {
                    modelContext.delete(todo)
                    try? modelContext.save()
                }
            }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
}

// MARK: - Todo Row

private struct TodoRowView: View {
    let todo: TodoItem

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            // Check circle
            Button {
                withAnimation {
                    todo.isCompleted.toggle()
                    todo.completedAt = todo.isCompleted ? Date() : nil
                }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(todo.isCompleted ? MemoraColor.accentGreen : MemoraColor.textTertiary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text(todo.title)
                    .font(MemoraTypography.body)
                    .foregroundStyle(todo.isCompleted ? MemoraColor.textTertiary : MemoraColor.textPrimary)
                    .strikethrough(todo.isCompleted)

                if !todo.isCompleted {
                    HStack(spacing: MemoraSpacing.xs) {
                        if let speaker = todo.speaker, !speaker.isEmpty {
                            Label(speaker, systemImage: "person.fill")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }

                        if let dueDate = todo.dueDate {
                            Label(dueDateString(dueDate), systemImage: "calendar")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(isOverdue(dueDate) ? MemoraColor.accentRed : MemoraColor.textSecondary)
                        }

                        if let priority = Priority(rawValue: todo.priority) {
                            priorityDot(priority)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, MemoraSpacing.xxxs)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func dueDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if Calendar.current.isDateInToday(date) { return "今日" }
        if Calendar.current.isDateInTomorrow(date) { return "明日" }
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date() && !todo.isCompleted
    }

    @ViewBuilder
    private func priorityDot(_ priority: Priority) -> some View {
        switch priority {
        case .high:
            Circle().fill(MemoraColor.accentRed).frame(width: 8, height: 8)
        case .medium:
            Circle().fill(MemoraColor.accentBlue).frame(width: 8, height: 8)
        case .low:
            Circle().fill(MemoraColor.textTertiary).frame(width: 8, height: 8)
        }
    }
}

// MARK: - Priority

private enum Priority: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var label: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

// MARK: - Todo Edit Sheet

struct TodoEditSheet: View {
    enum Mode {
        case create
        case edit(TodoItem)
    }

    let mode: Mode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.repositoryFactory) private var repoFactory
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var speaker = ""
    @State private var priority = "medium"
    @State private var dueDate: Date?
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)

                    if !speaker.isEmpty || mode.isEdit {
                        TextField("担当者", text: $speaker)
                    }
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
        }
    }

    private func loadIfEditing() {
        guard case .edit(let todo) = mode else { return }
        title = todo.title
        notes = todo.notes ?? ""
        speaker = todo.speaker ?? ""
        priority = todo.priority
        dueDate = todo.dueDate
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        switch mode {
        case .create:
            let todo = TodoItem(
                title: trimmedTitle,
                notes: notes.isEmpty ? nil : notes,
                speaker: speaker.isEmpty ? nil : speaker,
                priority: priority,
                dueDate: dueDate
            )
            if let factory = repoFactory {
                try? factory.todoItemRepo.save(todo)
            } else {
                modelContext.insert(todo)
                try? modelContext.save()
            }
        case .edit(let todo):
            todo.title = trimmedTitle
            todo.notes = notes.isEmpty ? nil : notes
            todo.speaker = speaker.isEmpty ? nil : speaker
            todo.priority = priority
            todo.dueDate = dueDate
        }
        dismiss()
    }
}

extension TodoEditSheet.Mode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

// MARK: - TodoItem Identifiable conformance

extension TodoItem: @retroactive Identifiable {}

#Preview {
    ToDoView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
