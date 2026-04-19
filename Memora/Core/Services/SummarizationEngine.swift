import Foundation
import SwiftData
import Observation

protocol SummarizationEngineProtocol {
    var isSummarizing: Bool { get }
    var progress: Double { get }

    func summarize(transcript: String, config: GenerationConfig) async throws -> SummaryResult
    func summarizeWithSpeakers(transcript: String, segments: [SpeakerSegment], config: GenerationConfig) async throws -> SummaryResult
}

struct SummaryResult {
    let suggestedTitle: String?
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
    let decisions: [String]?

    init(suggestedTitle: String? = nil, summary: String, keyPoints: [String], actionItems: [String], decisions: [String]? = nil) {
        self.suggestedTitle = suggestedTitle
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

@Observable
final class SummarizationEngine: SummarizationEngineProtocol {
    var isSummarizing = false
    var progress = 0.0

    private var aiService: AIService?

    func configure(apiKey: String, provider: AIProvider = .openai) async throws {
        let service = AIService()
        service.setProvider(provider)
        try await service.configure(apiKey: apiKey)
        self.aiService = service
    }

    func summarize(transcript: String, config: GenerationConfig = GenerationConfig()) async throws -> SummaryResult {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        await MainActor.run {
            isSummarizing = true
            progress = 0.0
        }

        do {
            await MainActor.run { progress = 0.2 }

            let title: String?
            let summary: String
            let keyPoints: [String]
            let actionItems: [String]

            if let customPrompt = config.customPrompt {
                let prompt = Self.buildCustomPrompt(transcript: transcript, customPrompt: customPrompt)
                let response = try await service.generate(prompt)
                (title, summary, keyPoints, actionItems) = try Self.parseJSONResponse(response)
            } else {
                (title, summary, keyPoints, actionItems) = try await service.summarize(transcript: transcript)
            }

            await MainActor.run { progress = 0.8 }

            // Try to extract decisions from summary context
            let result = SummaryResult(
                suggestedTitle: title,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
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

    func summarizeWithSpeakers(transcript: String, segments: [SpeakerSegment], config: GenerationConfig = GenerationConfig()) async throws -> SummaryResult {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        await MainActor.run {
            isSummarizing = true
            progress = 0.0
        }

        do {
            await MainActor.run { progress = 0.1 }

            // Build speaker-annotated transcript
            let annotatedTranscript = buildAnnotatedTranscript(transcript: transcript, segments: segments)

            await MainActor.run { progress = 0.2 }

            let title: String?
            let summary: String
            let keyPoints: [String]
            let actionItems: [String]

            if let customPrompt = config.customPrompt {
                let prompt = Self.buildCustomPrompt(transcript: annotatedTranscript, customPrompt: customPrompt)
                let response = try await service.generate(prompt)
                (title, summary, keyPoints, actionItems) = try Self.parseJSONResponse(response)
            } else {
                (title, summary, keyPoints, actionItems) = try await service.summarize(transcript: annotatedTranscript)
            }

            await MainActor.run { progress = 0.8 }

            let result = SummaryResult(
                suggestedTitle: title,
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
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

    /// Convert action items from a summary result into TodoItem objects and insert into model context
    @MainActor
    func createTodoItems(from result: SummaryResult, sourceFileId: UUID, sourceFileTitle: String, modelContext: ModelContext) {
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
            modelContext.insert(todo)
        }

        do {
            try modelContext.save()
        } catch {
            DebugLogger.shared.addLog("SummarizationEngine", "Failed to save todo items: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Private Helpers

    private static func buildCustomPrompt(transcript: String, customPrompt: String) -> String {
        """
        以下の transcript に基づいて、ユーザーの指示に従って出力してください。

        ユーザーの指示: \(customPrompt)

        出力は以下のJSON形式のみで返してください（Markdownコードブロックなし）：
        {
          "title": "内容を表す簡潔なタイトル（20字以内）",
          "summary": "要約",
          "keyPoints": ["ポイント1", "ポイント2"],
          "actionItems": ["アクションアイテム1", "アクションアイテム2"]
        }

        Transcript:
        \(transcript)
        """
    }

    private static func parseJSONResponse(_ response: String) throws -> (title: String?, summary: String, keyPoints: [String], actionItems: [String]) {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String else {
            throw AIError.invalidResponse
        }

        let title = json["title"] as? String
        let keyPoints = json["keyPoints"] as? [String] ?? []
        let actionItems = json["actionItems"] as? [String] ?? []

        return (title, summary, keyPoints, actionItems)
    }

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
