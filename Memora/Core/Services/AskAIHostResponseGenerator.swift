import Foundation

/// Ask AI コアから分離した、ホスト側の回答生成契約。
/// RNでは構成済み LLMProvider を使う実装を注入でき、SwiftUIでは既存の provider 選択を維持する。
protocol AskAIResponseGenerating {
    func generateResponse(for prompt: String) async throws -> String
}

/// SwiftUI ホストの既存 provider 選択と出力経路をそのまま保持する実装。
final class AskAIHostResponseGenerator: AskAIResponseGenerating {
    private let provider: AIProvider
    private let apiKey: String

    init(provider: AIProvider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
    }

    func generateResponse(for prompt: String) async throws -> String {
        let service = AIServiceHostService()
        service.setProvider(provider)

        // Local プロバイダーは空文字列で configure する既存挙動を維持する。
        try await service.configure(apiKey: apiKey)

        if provider == .local {
            // Local は自由テキスト generate、リモートは summarize(...).summary を使う。
            return try await service.generate(prompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return try await service.summarize(transcript: prompt).summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
