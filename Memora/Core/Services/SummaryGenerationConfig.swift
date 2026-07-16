import Foundation

/// 要約計算に必要な最小限の設定。画面固有のGenerationConfigから分離する。
struct SummaryGenerationConfig: Sendable {
    var customPrompt: String?

    init(customPrompt: String? = nil) {
        self.customPrompt = customPrompt
    }
}
