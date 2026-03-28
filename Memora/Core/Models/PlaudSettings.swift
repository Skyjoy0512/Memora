import Foundation
import SwiftData

/// Plaud デバイス連携設定（Plaud Toolkit 互換 API）
@Model
final class PlaudSettings {
    /// API サーバー（デフォルト: api.plaud.ai）
    var apiServer: String = "api.plaud.ai"

    /// メールアドレス
    var email: String = ""

    /// パスワード
    var password: String = ""

    /// アクセストークン
    var accessToken: String = ""

    /// リフレッシュトークン
    var refreshToken: String = ""

    /// トークン有効期限
    var tokenExpiresAt: Date?

    /// ユーザー ID
    var userId: String = ""

    /// 有効フラグ
    var isEnabled: Bool = false

    /// 最終同期日時
    var lastSyncAt: Date?

    /// 自動同期有効フラグ
    var autoSyncEnabled: Bool = false

    /// 作成日時
    var createdAt: Date = Date()

    /// 更新日時
    var updatedAt: Date = Date()

    /// トークンが有効かどうか
    var isTokenValid: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        return Date() < expiresAt
    }

    /// トークンをリフレッシュすべきか（30日以内）
    var shouldRefreshToken: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        return expiresAt < thirtyDaysFromNow
    }

    init() {}
}
