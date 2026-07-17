import Foundation

/// Ask AI の検索・コンテキスト生成に渡す memory privacy 状態。
/// 共有コアはこの値だけを受け取り、UserDefaults などのホスト状態を参照しない。
public struct AskAIMemoryPrivacyConfiguration: Sendable {
    public let mode: String
    public let disabledFactIDs: Set<UUID>

    public init(mode: String, disabledFactIDs: Set<UUID>) {
        self.mode = mode
        self.disabledFactIDs = disabledFactIDs
    }
}
