import Foundation
import SwiftData

/// 要約結果をSwiftDataのTodoItemへ保存するホスト側責務。
@MainActor
enum TodoItemSummarySaver {
    static func save(
        from result: SummaryResult,
        sourceFileId: UUID,
        sourceFileTitle: String,
        modelContext: ModelContext
    ) {
        for actionText in result.actionItems {
            let trimmed = actionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var assignee: String?
            var speaker: String?
            var title = trimmed

            if let colonRange = trimmed.range(of: ":", options: []),
               let speakerPart = trimmed[trimmed.startIndex..<colonRange.lowerBound].trimmingCharacters(in: .whitespaces).split(separator: " ").last {
                let speakerName = String(speakerPart)
                if speakerName.count <= 10 && !speakerName.contains("。") {
                    assignee = speakerName
                    speaker = speakerName
                    title = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }

            let todo = TodoItem(
                title: title,
                assignee: assignee,
                speaker: speaker,
                priority: "medium",
                projectID: nil,
                sourceAudioFileID: sourceFileId
            )
            modelContext.insert(todo)
        }

        do {
            try modelContext.save()
        } catch {
            DebugLogger.shared.addLog("SummarizationEngine", "Failed to save todo items: \(error.localizedDescription)", level: .error)
        }
    }
}
