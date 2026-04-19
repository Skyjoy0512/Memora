import ActivityKit
import Foundation
import os.log

private enum LiveActivityLogger {
    private static let logger = Logger(subsystem: "com.memora.Memora", category: "LiveActivity")
    static func info(_ message: String) { logger.info("\(message)") }
    static func warning(_ message: String) { logger.warning("\(message)") }
}

/// 文字起こし進捗の Live Activity 属性定義。
/// Dynamic Island / ロック画面に進捗バーを表示する。
struct TranscriptionActivityAttributes: ActivityAttributes {
    /// ファイル名（Live Activity 開始時に固定）
    let fileName: String
    let totalChunks: Int

    struct ContentState: Codable, Hashable {
        /// 0.0〜1.0 の進捗率
        let progress: Double
        /// 現在処理中のチャンク番号（1-based）
        let currentChunk: Int
        /// ステータステキスト
        let statusText: String
    }
}

/// Live Activity の開始・更新・終了を管理する。
@MainActor
enum TranscriptionLiveActivity {
    private static var currentActivity: Activity<TranscriptionActivityAttributes>?

    /// Live Activity を開始する。
    /// iOS 16.1+ で利用可能。未対応の場合は何もしない。
    static func start(fileName: String, totalChunks: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TranscriptionActivityAttributes(
            fileName: fileName,
            totalChunks: totalChunks
        )
        let initialState = TranscriptionActivityAttributes.ContentState(
            progress: 0,
            currentChunk: 0,
            statusText: "文字起こしを準備中..."
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            currentActivity = activity
            LiveActivityLogger.info("LiveActivity 開始: \(activity.id)")
        } catch {
            LiveActivityLogger.warning("LiveActivity 開始失敗: \(error.localizedDescription)")
        }
    }

    /// 進捗を更新する。
    static func update(progress: Double, currentChunk: Int, totalChunks: Int) {
        guard let activity = currentActivity else { return }

        let percentage = Int(progress * 100)
        let state = TranscriptionActivityAttributes.ContentState(
            progress: progress,
            currentChunk: currentChunk,
            statusText: "文字起こし中… \(currentChunk)/\(totalChunks) (\(percentage)%)"
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 文字起こし完了時に Live Activity を終了する。
    static func finish(success: Bool, characterCount: Int) {
        guard let activity = currentActivity else { return }

        let finalState = TranscriptionActivityAttributes.ContentState(
            progress: 1.0,
            currentChunk: 0,
            statusText: success ? "完了（\(characterCount)文字）" : "文字起こしに失敗しました"
        )

        Task {
            await activity.update(.init(state: finalState, staleDate: nil))
            // 完了表示を3秒間維持してから終了
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await activity.end(nil, dismissalPolicy: .after(.now + 1))
        }
        currentActivity = nil
    }
}
