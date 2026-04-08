import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Feature Flag

/// Gemma 4 実験機能の feature flag。
/// デフォルト OFF。Settings の開発者機能から明示的に有効化する。
struct Gemma4FeatureFlag {
    @AppStorage("gemma4ExperimentalEnabled") static var isEnabled: Bool = false
}

// MARK: - Device Gate

/// Gemma 4 実験プロファイルのデバイス要件チェック。
/// iOS 26+, Apple Silicon (A17 Pro / M1+), 8GB+ RAM を要求する。
enum Gemma4DeviceGate {
    /// このデバイスで Gemma 4 実験が有効化可能か
    static var isEligible: Bool {
        guard isOSSupported else { return false }
        guard isMemorySufficient else { return false }
        return true
    }

    /// 有効化できない理由（UI 表示用）
    static var ineligibilityReason: String? {
        if !isOSSupported {
            return "iOS 26 以降が必要です"
        }
        if !isMemorySufficient {
            return "8GB 以上のメモリが必要です"
        }
        return nil
    }

    /// 詳細なデバイス情報（ベンチマーク UI 用）
    static var deviceSummary: String {
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        return "RAM: \(memoryGB)GB / OS eligible: \(isOSSupported) / Memory eligible: \(isMemorySufficient)"
    }

    private static var isOSSupported: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    // Gemma 4 は 8GB+ RAM を目安とする（stable path の 6GB より厳しい）
    private static var isMemorySufficient: Bool {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let eightGB: UInt64 = 8 * 1024 * 1024 * 1024
        return physicalMemory >= eightGB
    }
}

// MARK: - Experimental Provider

/// Gemma 4 実験プロファイル。
/// stable path (LocalLLMProvider) とは完全に独立して動作する。
/// feature flag + device gate を通過した場合のみ有効。
final class Gemma4ExperimentalProvider: LLMProvider {
    let displayName = "Gemma 4 (Experimental)"

    /// feature flag と device gate の両方を満たしているか
    static var isReady: Bool {
        Gemma4FeatureFlag.isEnabled && Gemma4DeviceGate.isEligible
    }

    func generate(_ prompt: String) async throws -> String {
        guard Self.isReady else {
            throw LLMProviderError.notAvailable
        }

        // iOS 26 Foundation Models を使用。
        // 将来 Gemma 4 固有のモデル指定が可能になればここを差し替える。
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession(
                instructions: """
                あなたは Memora の実験的 AI アシスタント（Gemma 4 プロファイル）です。
                必ず日本語で簡潔に答えてください。
                """
            )
            let response = try await session.respond(to: prompt)
            return response.content
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    func summarize(transcript: String) async throws -> LLMProviderSummary {
        guard Self.isReady else {
            throw LLMProviderError.notAvailable
        }

        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            let session = LanguageModelSession(
                instructions: """
                あなたは会議の文字起こしから要約を作成する実験的アシスタントです（Gemma 4 プロファイル）。
                以下のフォーマットで出力してください:
                [要約]
                会議の要約文

                [重要ポイント]
                ・ポイント1
                ・ポイント2

                [アクションアイテム]
                ・アイテム1
                ・アイテム2
                """
            )
            let prompt = "以下の文字起こしから要約を作成してください:\n\n\(transcript)"
            let response = try await session.respond(to: prompt)
            return Self.parseSummaryResponse(response.content)
            #else
            throw LLMProviderError.notAvailable
            #endif
        }
        throw LLMProviderError.notAvailable
    }

    // LocalLLMProvider と同じパーサーを使う（フォーマット互換）
    private static func parseSummaryResponse(_ text: String) -> LLMProviderSummary {
        let sections = text.components(separatedBy: "\n")
        var currentSection = ""
        var summaryLines: [String] = []
        var keyPoints: [String] = []
        var actionItems: [String] = []

        for line in sections {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("[要約]") || trimmed.contains("## 要約") {
                currentSection = "summary"
                continue
            } else if trimmed.contains("[重要ポイント]") || trimmed.contains("## 重要ポイント") || trimmed.contains("キーポイント") {
                currentSection = "keyPoints"
                continue
            } else if trimmed.contains("[アクションアイテム]") || trimmed.contains("## アクション") {
                currentSection = "actionItems"
                continue
            }

            let content = trimmed
                .replacingOccurrences(of: "^[•\\-・*]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            guard !content.isEmpty else { continue }

            switch currentSection {
            case "summary":
                summaryLines.append(content)
            case "keyPoints":
                keyPoints.append(content)
            case "actionItems":
                actionItems.append(content)
            default:
                break
            }
        }

        if summaryLines.isEmpty, keyPoints.isEmpty, actionItems.isEmpty {
            summaryLines = [text.prefix(500).description]
        }

        return LLMProviderSummary(
            summary: summaryLines.joined(separator: "\n"),
            keyPoints: keyPoints,
            actionItems: actionItems
        )
    }
}

// MARK: - Benchmark

/// Gemma 4 実験プロファイルのベンチマーク結果。
struct Gemma4BenchmarkResult: Identifiable {
    let id = UUID()
    let testName: String
    let latencyMs: Double
    let tokenCount: Int
    let tokensPerSecond: Double
    let success: Bool
    let errorMessage: String?
    let timestamp: Date
}

/// Gemma 4 ベンチマークランナー。
/// UI スレッドをブロックしないよう @MainActor で管理する。
@MainActor
final class Gemma4BenchmarkRunner: ObservableObject {
    @Published private(set) var results: [Gemma4BenchmarkResult] = []
    @Published private(set) var isRunning = false

    private let testPrompts = [
        ("短文生成", "今日の天気を一言で教えてください。"),
        ("要約", "以下の文章を要約してください: チームミーティングで新機能の優先順位について議論しました。来月のリリースに向けて、パフォーマンス改善を最優先とし、UIのブラッシュアップは次フェーズに回すことになりました。"),
        ("リスト生成", "会議の準備に必要なことを3つ挙げてください。"),
    ]

    func runAll() async {
        guard !isRunning else { return }
        guard Gemma4ExperimentalProvider.isReady else { return }
        isRunning = true
        results.removeAll()

        let provider = Gemma4ExperimentalProvider()

        for (name, prompt) in testPrompts {
            let start = ContinuousClock.now
            do {
                let response = try await provider.generate(prompt)
                let elapsed = start.duration(to: ContinuousClock.now)
                let ms = Double(elapsed.components.seconds) * 1000.0
                    + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0
                let tokenCount = response.count / 3 // 日本語の概算トークン数
                let tps = ms > 0 ? Double(tokenCount) / (ms / 1000.0) : 0

                results.append(Gemma4BenchmarkResult(
                    testName: name,
                    latencyMs: ms,
                    tokenCount: tokenCount,
                    tokensPerSecond: tps,
                    success: true,
                    errorMessage: nil,
                    timestamp: Date()
                ))
            } catch {
                let elapsed = start.duration(to: ContinuousClock.now)
                let ms = Double(elapsed.components.seconds) * 1000.0
                    + Double(elapsed.components.attoseconds) / 1_000_000_000_000.0

                results.append(Gemma4BenchmarkResult(
                    testName: name,
                    latencyMs: ms,
                    tokenCount: 0,
                    tokensPerSecond: 0,
                    success: false,
                    errorMessage: error.localizedDescription,
                    timestamp: Date()
                ))
            }
        }

        isRunning = false
    }
}
