import Foundation
import SwiftData

protocol SummarizationEngineProtocol {
    var isSummarizing: Bool { get }
    var progress: Double { get }

    func summarize(transcript: String) async throws -> SummaryResult
    func summarizeWithSpeakers(transcript: String, segments: [SpeakerSegment]) async throws -> SummaryResult
}

struct SummaryResult {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
    let decisions: [String]?

    init(summary: String, keyPoints: [String], actionItems: [String], decisions: [String]? = nil) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.decisions = decisions
    }

    /// Format action items as newline-separated string for storage
    var actionItemsText: String {
        actionItems.joined(separator: "\n")
    }

    /// Format key points as newline-separated string for storage
    var keyPointsText: String {
        keyPoints.joined(separator: "\n")
    }

    /// Format decisions as newline-separated string for storage
    var decisionsText: String? {
        guard let decisions, !decisions.isEmpty else { return nil }
        return decisions.joined(separator: "\n")
    }
}

final class SummarizationEngine: SummarizationEngineProtocol, ObservableObject {
    @Published var isSummarizing = false
    @Published var progress = 0.0

    private let router = LLMRouter.shared

    func configure(apiKey: String, provider: AIProvider = .openai) async throws {
        await MainActor.run {
            router.setProvider(provider)
            router.setAPIKey(apiKey, for: provider)
        }
    }

    func summarize(transcript: String) async throws -> SummaryResult {
        await MainActor.run {
            isSummarizing = true
            progress = 0.0
        }

        do {
            await MainActor.run { progress = 0.2 }

            let llmResponse = try await router.summarize(transcript: transcript)

            await MainActor.run { progress = 0.8 }

            let result = SummaryResult(
                summary: llmResponse.summary ?? llmResponse.rawText,
                keyPoints: llmResponse.keyPoints,
                actionItems: llmResponse.actionItems,
                decisions: llmResponse.decisions
            )

            await MainActor.run {
                progress = 1.0
                isSummarizing = false
            }

            return result
        } catch {
            await MainActor.run {
                isSummarizing = false
            }
            throw error
        }
    }

    func summarizeWithSpeakers(transcript: String, segments: [SpeakerSegment]) async throws -> SummaryResult {
        await MainActor.run {
            isSummarizing = true
            progress = 0.0
        }

        do {
            await MainActor.run { progress = 0.1 }

            await MainActor.run { progress = 0.2 }

            let llmResponse = try await router.summarize(
                transcript: transcript,
                includeSpeakers: true,
                segments: segments
            )

            await MainActor.run { progress = 0.8 }

            let result = SummaryResult(
                summary: llmResponse.summary ?? llmResponse.rawText,
                keyPoints: llmResponse.keyPoints,
                actionItems: llmResponse.actionItems,
                decisions: llmResponse.decisions
            )

            await MainActor.run {
                progress = 1.0
                isSummarizing = false
            }

            return result
        } catch {
            await MainActor.run {
                isSummarizing = false
            }
            throw error
        }
    }

    // MARK: - Action Item → TodoItem Conversion

    /// Convert action items from a summary result into TodoItem objects via repository
    @MainActor
    func createTodoItems(from result: SummaryResult, sourceFileId: UUID, sourceFileTitle: String, todoRepo: TodoItemRepositoryProtocol) {
        for actionText in result.actionItems {
            // Skip empty items
            let trimmed = actionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Extract assignee if pattern like "田中: 〇〇までに報告書を提出する" exists
            var assignee: String?
            var speaker: String?
            var title = trimmed

            if let colonRange = trimmed.range(of: ":", options: []),
               let speakerPart = trimmed[trimmed.startIndex..<colonRange.lowerBound].trimmingCharacters(in: .whitespaces).split(separator: " ").last {
                let speakerName = String(speakerPart)
                // Check if the speaker name is short enough to be a name (not a sentence)
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
                projectID: nil
            )
            try? todoRepo.save(todo)
        }
    }

    // MARK: - Private Helpers

    private func buildAnnotatedTranscript(transcript: String, segments: [SpeakerSegment]) -> String {
        guard !segments.isEmpty else { return transcript }

        var lines: [String] = []
        for segment in segments {
            let speaker = segment.speakerLabel.isEmpty ? "不明" : segment.speakerLabel
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                lines.append("[\(speaker)] \(text)")
            }
        }

        return lines.isEmpty ? transcript : lines.joined(separator: "\n")
    }
}
