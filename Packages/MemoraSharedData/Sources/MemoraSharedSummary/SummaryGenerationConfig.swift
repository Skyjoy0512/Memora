/// 要約計算に必要な最小限の設定。画面固有のGenerationConfigから分離する。
public struct SummaryGenerationConfig: Sendable {
    public var customPrompt: String?

    public init(customPrompt: String? = nil) {
        self.customPrompt = customPrompt
    }
}
