import Testing
import Foundation
@testable import Memora

/// テスト用の共通ヘルパー
///
/// - Note: iOS 26.2 Simulator において、テストホストアプリが既に ModelContainer を
///   作成している状態で同じスキーマの別 ModelContainer を作成すると
///   SwiftData が EXC_BREAKPOINT を起こすバグがある。
///   そのため ModelContext を使ったテストは不可。
///   @Model オブジェクトのプロパティテストのみ実行する。
enum TestModelContainer {
}
