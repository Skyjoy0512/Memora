import Foundation

protocol SummarizationEngineProtocol {
    var isSummarizing: Bool { get }
    var progress: Double { get }

    func summarize(transcript: String) async throws -> SummaryResult
}

struct SummaryResult {
    let summary: String
    let keyPoints: [String]
    let actionItems: [String]
}

final class SummarizationEngine: SummarizationEngineProtocol, ObservableObject {
    @Published var isSummarizing = false
    @Published var progress = 0.0

    private var aiService: AIService?

    func configure(apiKey: String, provider: AIProvider = .openai) async throws {
        let service = AIService()
        service.setProvider(provider)
        try await service.configure(apiKey: apiKey)
        self.aiService = service
    }

    func summarize(transcript: String) async throws -> SummaryResult {
        guard let service = aiService else {
            throw AIError.notConfigured
        }

        isSummarizing = true
        progress = 0

        do {
            progress = 0.5
            let (summary, keyPoints, actionItems) = try await service.summarize(transcript: transcript)
            progress = 1.0

            isSummarizing = false

            return SummaryResult(
                summary: summary,
                keyPoints: keyPoints,
                actionItems: actionItems
            )
        } catch {
            isSummarizing = false
            throw error
        }
    }
}
