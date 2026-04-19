import SwiftData
import Foundation

// MARK: - Versioned Schema

/// Memora のスキーマバージョン定義。
/// スキーマ変更時は新しい VersionedSchema を追加し、
/// MemoraMigrationPlan の stages にマイグレーションを追加すること。
enum MemoraSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AudioFile.self,
        Transcript.self,
        Project.self,
        MeetingNote.self,
        MeetingMemo.self,
        PhotoAttachment.self,
        KnowledgeChunk.self,
        AskAISession.self,
        AskAIMessage.self,
        MemoryProfile.self,
        MemoryFact.self,
        TodoItem.self,
        ProcessingJob.self,
        WebhookSettings.self,
        PlaudSettings.self,
        CalendarEventLink.self,
        GoogleMeetSettings.self,
        NotionSettings.self,
        CustomSummaryTemplate.self
    ]
}

// MARK: - Migration Plan

/// スキーママイグレーションプラン。
/// V1 → V2 のような段階的マイグレーションを定義する。
/// 現時点では V1 のみなのでマイグレーション段階は空。
///
/// 将来のスキーマ変更例:
/// 1. 新しい VersionedSchema (V2) を定義
/// 2. LightweightMigration または ManualMigration を追加
/// 3. plan の stages に登録
///
/// ```
/// // 例: カラム追加の軽量マイグレーション
/// static let plan = MigrationPlan(stages: [
///     migrateV1toV2
/// ])
///
/// static let migrateV1toV2 = MigrationStage.lightweight(
///     fromVersion: MemoraSchemaV1.self,
///     toVersion: MemoraSchemaV2.self
/// )
/// ```
enum MemoraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MemoraSchemaV1.self]
    }

    static let stages: [MigrationStage] = [
        // V1 のみ。将来のスキーマ変更時に段階を追加する。
    ]

    /// マイグレーションプラン未適用のストア（初期導入前）を許容
    static let minimumSchemaVersion = MemoraSchemaV1.self

    static var migrationStageOrder: [MigrationStage] { stages }
}
