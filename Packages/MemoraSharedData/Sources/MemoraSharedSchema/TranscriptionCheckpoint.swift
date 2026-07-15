import Foundation
import SwiftData

/// 文字起こしのチャンク単位チェックポイント。
/// 完了済みチャンクの結果を保持し、中断後の再実行で再利用する。
/// 成功完了時に削除される揮発性の中間データ。
@Model
public final class TranscriptionCheckpoint {
    @Attribute(.unique) var audioFileID: UUID
    public var audioFingerprint: String
    public var totalChunks: Int
    public var createdAt: Date
    public var updatedAt: Date
    @Attribute(.externalStorage) var chunkResultsBlob: Data

    public init(audioFileID: UUID, audioFingerprint: String, totalChunks: Int) {
        self.audioFileID = audioFileID
        self.audioFingerprint = audioFingerprint
        self.totalChunks = totalChunks
        self.createdAt = Date()
        self.updatedAt = Date()
        self.chunkResultsBlob = Data()
    }
}
