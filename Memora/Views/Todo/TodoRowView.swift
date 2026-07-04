import SwiftUI
import SwiftData

// MARK: - Todo Row View

struct TodoRowView: View {
    let todo: TodoItem
    let parentTitle: String?
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onComplete()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "未完了に戻す" : "完了にする")

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)

                if let parentTitle, !parentTitle.isEmpty {
                    Label("親: \(parentTitle)", systemImage: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !todo.isCompleted {
                    HStack(spacing: 8) {
                        if let assignee = todo.assignee, !assignee.isEmpty {
                            Label(assignee, systemImage: "person.crop.circle")
                        }

                        if let speaker = todo.speaker, !speaker.isEmpty {
                            Label(speaker, systemImage: "person.fill")
                        }

                        if let dueDate = todo.dueDate {
                            Label(dueDateString(dueDate), systemImage: "calendar")
                                .foregroundStyle(isOverdue(dueDate) ? .red : .secondary)
                        }

                        if let priority = Priority(rawValue: todo.priority) {
                            priorityDot(priority)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .short
        return f
    }()

    private func dueDateString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今日" }
        if Calendar.current.isDateInTomorrow(date) { return "明日" }
        return Self.dueDateFormatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date() && !todo.isCompleted
    }

    @ViewBuilder
    private func priorityDot(_ priority: Priority) -> some View {
        switch priority {
        case .high:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .medium:
            Circle().fill(.blue).frame(width: 8, height: 8)
        case .low:
            Circle().fill(.secondary).frame(width: 8, height: 8)
        }
    }
}

// MARK: - Priority Enum

enum Priority: String, CaseIterable {
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
