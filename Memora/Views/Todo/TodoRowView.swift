import SwiftUI
import SwiftData

// MARK: - Todo Row View

struct TodoRowView: View {
    let todo: TodoItem
    let parentTitle: String?
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: MemoraSpacing.sm) {
            // Check circle — Nothing style
            Button {
                onComplete()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            todo.isCompleted ? Color.clear : MemoraColor.accentNothing,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if todo.isCompleted {
                        Circle()
                            .fill(MemoraColor.accentGreen)
                            .frame(width: 24, height: 24)
                            .nothingGlow(.subtle)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: MemoraSpacing.xxxs) {
                Text(todo.title)
                    .font(MemoraTypography.phiBody)
                    .foregroundStyle(todo.isCompleted ? MemoraColor.textTertiary : MemoraColor.textPrimary)
                    .strikethrough(todo.isCompleted)

                if let parentTitle, !parentTitle.isEmpty {
                    Label("親: \(parentTitle)", systemImage: "arrow.turn.down.right")
                        .font(MemoraTypography.caption1)
                        .foregroundStyle(MemoraColor.accentNothing)
                }

                if !todo.isCompleted {
                    HStack(spacing: MemoraSpacing.xs) {
                        if let assignee = todo.assignee, !assignee.isEmpty {
                            Label(assignee, systemImage: "person.crop.circle")
                                .font(MemoraTypography.caption1)
                                .foregroundStyle(MemoraColor.textSecondary)
                        }

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
            AccentDotIndicator(color: MemoraColor.accentNothing, size: 8, glowing: true)
        case .medium:
            Circle().fill(MemoraColor.accentBlue).frame(width: 8, height: 8)
        case .low:
            Circle().fill(MemoraColor.textTertiary).frame(width: 8, height: 8)
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
