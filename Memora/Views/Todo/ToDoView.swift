import SwiftUI
import SwiftData

// MARK: - ToDo View

struct ToDoView: View {
    @Environment(\.modelContext) private var modelContext
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
                            .font(MemoraTypography.phiBody)
                            .foregroundStyle(MemoraColor.accentNothing)
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
                        Button {
                            editingTodo = todo
                        } label: {
                            TodoRowView(
                                todo: todo,
                                parentTitle: parentTitle(for: todo),
                                onComplete: {
                                    withAnimation {
                                        todo.isCompleted.toggle()
                                        todo.completedAt = todo.isCompleted ? Date() : nil
                                    }
                                }
                            )
                            .nothingCard(.minimal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Todo を編集")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: MemoraSpacing.xxxs, leading: MemoraSpacing.md, bottom: MemoraSpacing.xxxs, trailing: MemoraSpacing.md))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton(todo)
                        }
                        .swipeActions(edge: .leading) {
                            completeButton(todo)
                        }
                    }
                } header: {
                    GlassSectionHeader(title: "未完了", icon: "circle")
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }

            if !completedTodos.isEmpty {
                Section {
                    ForEach(completedTodos) { todo in
                        Button {
                            editingTodo = todo
                        } label: {
                            TodoRowView(
                                todo: todo,
                                parentTitle: parentTitle(for: todo),
                                onComplete: {
                                    withAnimation {
                                        todo.isCompleted.toggle()
                                        todo.completedAt = todo.isCompleted ? Date() : nil
                                    }
                                }
                            )
                            .nothingCard(.minimal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Todo を編集")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: MemoraSpacing.xxxs, leading: MemoraSpacing.md, bottom: MemoraSpacing.xxxs, trailing: MemoraSpacing.md))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton(todo)
                        }
                    }
                } header: {
                    GlassSectionHeader(title: "完了済み", icon: "checkmark.circle")
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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
