import SwiftUI

/// Memora 全体で統一されたアニメーションプリセット。
/// Reduce Motion 環境では .none にフォールバックする設計。
enum MemoraAnimation {

    // MARK: - Spring Presets

    /// 標準的なSpring（ボタン、カード出現）
    static let springDefault = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// 弾力のあるSpring（FAB、バウンス演出）
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// 鋭いSpring（スナップ的変化、チェック完了）
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.9)

    // MARK: - Duration Presets

    static let standardDuration: Double = 0.25
    static let slowDuration: Double = 0.35

    // MARK: - Reduce Motion Support

    /// Reduce Motionが有効な場合はnil、無効なら指定アニメーションを返す
    static func spring(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : springDefault
    }

    static func bouncy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : springBouncy
    }

    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : springSnappy
    }
}

/// Memora 全体で統一されたTransitionプリセット。
enum MemoraTransition {
    /// フェードイン + 軽いスケール（カード出現、メッセージ）
    static let fadeIn = AnyTransition.opacity.combined(with: .scale(scale: 0.95))

    /// 下からスライド（シート、バナー）
    static let slideUp = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// チップ出現（ステータスチップ、タグ）
    static let chipAppear = AnyTransition.scale.combined(with: .opacity)

    /// Reduce Motion 用（即時出現）
    static let instant = AnyTransition.identity
}
