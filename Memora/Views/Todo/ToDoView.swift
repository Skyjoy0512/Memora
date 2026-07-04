import SwiftUI
import SwiftData

// MARK: - ToDo View

struct ToDoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TodoItem.createdAt, order: .reverse)
    private var allTodos: [TodoItem]
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
            todoContent
            .navigationTitle("ToDo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("ToDoを追加")
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

    @ViewBuilder
    private var todoContent: some View {
        if incompleteTodos.isEmpty && completedTodos.isEmpty {
            ContentUnavailableView(
                "ToDoはまだありません",
                systemImage: "checklist",
                description: Text("議事録から自動抽出するか、手動で追加できます。"),
                actions: {
                    Button("ToDoを追加") {
                        showAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            )
        } else {
            todoList
        }
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            if !incompleteTodos.isEmpty {
                Section {
                    ForEach(incompleteTodos) { todo in
                        TodoRowView(
                            todo: todo,
                            parentTitle: parentTitle(for: todo),
                            onComplete: {
                                MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                                    todo.isCompleted.toggle()
                                    todo.completedAt = todo.isCompleted ? Date() : nil
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editingTodo = todo }
                        .accessibilityHint("ToDoを編集")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton(todo)
                        }
                        .swipeActions(edge: .leading) {
                            completeButton(todo)
                        }
                    }
                } header: { Text("未完了") }
            }

            if !completedTodos.isEmpty {
                Section {
                    ForEach(completedTodos) { todo in
                        TodoRowView(
                            todo: todo,
                            parentTitle: parentTitle(for: todo),
                            onComplete: {
                                MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                                    todo.isCompleted.toggle()
                                    todo.completedAt = todo.isCompleted ? Date() : nil
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editingTodo = todo }
                        .accessibilityHint("ToDoを編集")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton(todo)
                        }
                    }
                } header: { Text("完了済み") }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Swipe Actions

    private func completeButton(_ todo: TodoItem) -> some View {
        Button {
            MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                todo.isCompleted.toggle()
                todo.completedAt = todo.isCompleted ? Date() : nil
            }
        } label: {
            Label(todo.isCompleted ? "未完了に戻す" : "完了",
                  systemImage: todo.isCompleted ? "xmark.circle" : "checkmark.circle")
        }
        .tint(todo.isCompleted ? .secondary : .green)
    }

    private func deleteButton(_ todo: TodoItem) -> some View {
        Button(role: .destructive) {
            MemoraAnimation.animate(reduceMotion, using: MemoraAnimation.springSnappy) {
                modelContext.delete(todo)
                try? modelContext.save()
            }
        } label: {
            Label("削除", systemImage: "trash")
        }
    }

    private func parentTitle(for todo: TodoItem) -> String? {
        guard let parentID = todo.parentID else {
            return TaskBreakdownMetadata.parentTitle(from: todo.notes)
        }

        return allTodos.first(where: { $0.id == parentID })?.title
            ?? TaskBreakdownMetadata.parentTitle(from: todo.notes)
    }
}

#Preview {
    ToDoView()
        .modelContainer(for: [TodoItem.self, Project.self], inMemory: true)
}
