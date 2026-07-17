import Foundation

/// Ask AI の検索・コンテキスト生成に渡す memory privacy 状態。
/// 共有コアはこの値だけを受け取り、UserDefaults などのホスト状態を参照しない。
struct AskAIMemoryPrivacyConfiguration: Sendable {
    let mode: String
    let disabledFactIDs: Set<UUID>
}
