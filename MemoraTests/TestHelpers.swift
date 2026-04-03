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

struct STTCoreTests {
    @Test("オンデバイス認識タイムアウトは専用メッセージを返す")
    func onDeviceTimeoutErrorMessage() {
        let error = OnDeviceTranscriptionTimeoutError()
        #expect(error.errorDescription == OnDeviceTranscriptionTimeoutError.message)
    }

    @Test("オンデバイス認識タイムアウトは CoreError へ変換される")
    func onDeviceTimeoutMapsToCoreError() {
        let mapped = STTErrorMapper.mapToCoreError(OnDeviceTranscriptionTimeoutError())

        #expect(
            mapped == .transcriptionError(
                .transcriptionFailed(OnDeviceTranscriptionTimeoutError.message)
            )
        )
    }
}
