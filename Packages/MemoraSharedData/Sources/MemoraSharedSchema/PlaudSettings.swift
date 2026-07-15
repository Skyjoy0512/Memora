import Foundation
import SwiftData

/// Plaud デバイス連携設定（Plaud Toolkit 互換 API）
@Model
public final class PlaudSettings {
    /// API サーバー（デフォルト: api.plaud.ai）
    public var apiServer: String = "api.plaud.ai"

    /// メールアドレス
    public var email: String = ""

    /// パスワード
    public var password: String = ""

    /// アクセストークン
    public var accessToken: String = ""

    /// リフレッシュトークン
    public var refreshToken: String = ""

    /// トークン有効期限
    public var tokenExpiresAt: Date?

    /// ユーザー ID
    public var userId: String = ""

    /// 有効フラグ
    public var isEnabled: Bool = false

    /// 最終同期日時
    public var lastSyncAt: Date?

    /// 自動同期有効フラグ
    public var autoSyncEnabled: Bool = false

    /// 作成日時
    public var createdAt: Date = Date()

    /// 更新日時
    public var updatedAt: Date = Date()

    public init() {}
}
