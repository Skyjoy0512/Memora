import SwiftUI
import Observation
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
        guard isChipSupported else { return false }
        guard isMemorySufficient else { return false }
        return true
    }

    /// 有効化できない理由（UI 表示用）
    static var ineligibilityReason: String? {
        if !isOSSupported {
            return "iOS 26 以降が必要です"
        }
        if !isChipSupported {
            return "A17 Pro / M1 以降のチップが必要です"
        }
        if !isMemorySufficient {
            return "8GB 以上のメモリが必要です"
        }
        return nil
    }

    /// 詳細なデバイス情報（ベンチマーク UI 用）
    static var deviceSummary: String {
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        return "RAM: \(memoryGB)GB / Chip: \(chipIdentifier) / OS eligible: \(isOSSupported) / Chip eligible: \(isChipSupported) / Memory eligible: \(isMemorySufficient)"
    }

    private static var isOSSupported: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// A17 Pro / M1 以降（Neural Engine 搭載）かを判定する。
    /// iPhone: A17 Pro (iPhone 15 Pro 系) 以降
    /// iPad / Mac: M1 以降
    /// シミュレータでは常に true を返す（開発用途）。
    private static var isChipSupported: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let chip = chipIdentifier.lowercased()

        // Mac (Apple Silicon): always supported
        if chip.hasPrefix("mac") { return true }

        // iPad: M1+ or A17 Pro+
        if chip.hasPrefix("ipad") {
            return isIPadChipSupported(chip)
        }

        // iPhone: A17 Pro+ (iPhone15,2+ = iPhone 15 Pro)
        return isIPhoneChipSupported(chip)
        #endif
    }

    // Gemma 4 は 8GB+ RAM を目安とする（stable path の 6GB より厳しい）
    private static var isMemorySufficient: Bool {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let eightGB: UInt64 = 8 * 1024 * 1024 * 1024
        return physicalMemory >= eightGB
    }

    /// hw.machine からデバイス識別子を取得する
    static var chipIdentifier: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    /// iPhone チップ判定: A17 Pro 以降
    /// iPhone15,2 = iPhone 15 Pro (A17 Pro)
    /// iPhone16,x = iPhone 16 series (A18 Pro)
    /// iPhone17,x = iPhone 17 series (A19 Pro)
    private static func isIPhoneChipSupported(_ chip: String) -> Bool {
        // "iphone15,2" 以降のモデル番号
        guard let modelNumber = extractModelNumber(from: chip, prefix: "iphone") else {
            return false
        }
        // iPhone 15 Pro (15) 以降 → A17 Pro 以降
        return modelNumber >= 15
    }

    /// iPad チップ判定: M1 以降 または A17 Pro 以降
    private static func isIPadChipSupported(_ chip: String) -> Bool {
        // M1+ iPad: iPad13,x (M1), iPad14,x (M2), iPad16,x (M4)
        if let modelNumber = extractModelNumber(from: chip, prefix: "ipad") {
            // iPad13,1+ = M1 以降
            if modelNumber >= 13 { return true }
        }
        return false
    }

    /// "iphone15,2" → 15, "ipad13,1" → 13 のようにモデル番号を抽出
    private static func extractModelNumber(from chip: String, prefix: String) -> Int? {
        guard chip.hasPrefix(prefix) && chip.count > prefix.count else { return nil }
        let withoutPrefix = String(chip.dropFirst(prefix.count))
        let modelStr = withoutPrefix.prefix { $0.isNumber }
        guard !modelStr.isEmpty else { return nil }
        return Int(modelStr)
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

    /// LLMProvider protocol 準拠。現在有効化可能かを返す。
    var isAvailable: Bool {
        get async {
            Self.isReady
        }
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
            title: nil,
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
@Observable
final class Gemma4BenchmarkRunner {
    private(set) var results: [Gemma4BenchmarkResult] = []
    private(set) var isRunning = false

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
