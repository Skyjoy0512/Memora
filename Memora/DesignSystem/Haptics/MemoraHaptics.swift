import SwiftUI
import UIKit

/// Memora 全体で統一されたハプティックフィードバック。
/// 物理デバイスでのみ動作（Simulator ではサイレント）。
enum MemoraHaptics {
    /// 軽いタップ（ボタン押下、ナビゲーション遷移）
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 中程度のタップ（録音開始、重要なトグル操作）
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 成功フィードバック（録音完了、保存成功）
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告フィードバック（エラー、削除確認）
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// エラーフィードバック（操作失敗）
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// 選択変更（タブ切替、スコープ選択、セグメント切替）
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
