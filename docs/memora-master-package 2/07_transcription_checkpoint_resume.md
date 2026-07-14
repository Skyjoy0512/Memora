# 07. 文字起こしチェックポイント & 再開 詳細設計書

Lane: C (Model) + B (STT) / **STT コアタスク + 保存形式追加(新モデル。既存 Transcript は不変)**
依存: 02(BG キャンセルが前提)/ 対応 PR: PR-C1(モデル)→ PR-B8(パイプライン組込)

> boundary 遵守: 「保存フォーマット変更は Migration 設計なしで入れない」→ 本件は**既存モデルを変更せず新モデルを追加**する(additive)。SwiftData の additive change は lightweight migration で吸収されるが、`MemoraSchema` のバージョン管理方式(■確認: `MemoraSchema.swift` が VersionedSchema を使っているか)に従うこと。

---

## 1. 目的

長時間音声の文字起こしは、BG 移行(02 で「安全にキャンセル」される)・アプリ kill・クラッシュで**最初からやり直し**になる。チャンク単位の結果を逐次永続化し、再実行時に完了済みチャンクをスキップする。これが iOS 単体での長時間音声対応の本命(サーバー処理は将来 P3)。

## 2. 設計概要

```
runTask:
  chunker.analyzeAndChunk → chunks
  checkpoint = load(fileID, fingerprint)          ← 新規
  for chunk in chunks:
      if checkpoint.has(chunk.index): reuse       ← 新規
      else: transcribe → checkpoint.save(chunk)   ← 新規
  merge → diarize → final
  checkpoint.delete(fileID)                        ← 新規(成功時)
```

キーポイント:
- チェックポイントの有効性は **audio fingerprint(ファイルサイズ + duration 秒 + チャンク構成ハッシュ)** で判定。音声が差し替わっていたら破棄。
- チャンク再利用時も一時チャンクファイルは**再生成される**(チャンク URL は毎回変わる)ため、チェックポイントは「index → TranscriptionResult(JSON)」のみを持ち、音声には依存しない。
- 話者分離・merge・後処理は**毎回最終段で再実行**(チャンク結果のみ再利用)。
- 対象はローカルモードのみでも可だが、API モードも失敗時の課金節約になるため両対応とする。

## 3. PR-C1: SwiftData モデル

### 3.1 新規ファイル: `Memora/Core/Models/TranscriptionCheckpoint.swift`

```swift
import Foundation
import SwiftData

/// 文字起こしのチャンク単位チェックポイント。
/// 完了済みチャンクの結果を保持し、中断後の再実行で再利用する。
/// 成功完了時に削除される揮発性の中間データ。
@Model
final class TranscriptionCheckpoint {
    /// 対象 AudioFile。1 ファイルにつき最大 1 チェックポイント。
    @Attribute(.unique) var audioFileID: UUID
    /// 音声の同一性指紋: "\(fileSizeBytes)-\(durationSecInt)-\(chunkCount)"
    var audioFingerprint: String
    var totalChunks: Int
    var createdAt: Date
    var updatedAt: Date
    /// チャンク index → 結果 JSON(CheckpointChunkResult をエンコード)
    var chunkResultsJSON: [Int: Data]

    init(audioFileID: UUID, audioFingerprint: String, totalChunks: Int) {
        self.audioFileID = audioFileID
        self.audioFingerprint = audioFingerprint
        self.totalChunks = totalChunks
        self.createdAt = Date()
        self.updatedAt = Date()
        self.chunkResultsJSON = [:]
    }
}

/// チェックポイントに保存するチャンク結果(コア DTO の Codable ミラー)。
/// TranscriptionResult 自体を Codable 化しないのは、コア DTO への
/// 準拠追加(保存形式への波及)を避けるため。
struct CheckpointChunkResult: Codable {
    struct Segment: Codable {
        let id: String
        let speakerLabel: String
        let startSec: Double
        let endSec: Double
        let text: String
        let isEstimatedTiming: Bool   // 03 実装後。未実装なら false 固定で入れておく
    }
    let fullText: String
    let language: String
    let segments: [Segment]
}
```

注: `[Int: Data]` が SwiftData 属性として保存できない場合(■確認: Dictionary 属性のサポート状況。不可なら)、`var chunkResultsBlob: Data`(`[Int: CheckpointChunkResult]` 全体を JSONEncoder で1 blob 化)へフォールバックする。blob 方式は書き込みごとに全体再エンコードだがチャンク数は高々数百・各数 KB なので許容。**実装エージェントはまず blob 方式で実装してよい(確実に動く)**。

### 3.2 スキーマ登録

`MemoraSchema.swift` のモデル一覧へ `TranscriptionCheckpoint.self` を追加。VersionedSchema 運用なら新バージョンを起こし additive migration を定義(■確認: 既存 `DataModelV2Tests` の流儀に合わせる)。

### 3.3 ストアアクセサ: `Memora/Core/Services/TranscriptionCheckpointStore.swift`(新規)

STTService(非 MainActor)から SwiftData を直接触らないため、MainActor のストアを介す:

```swift
import Foundation
import SwiftData

/// TranscriptionCheckpoint の読み書き。MainActor で ModelContext を扱う。
@MainActor
final class TranscriptionCheckpointStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(audioFileID: UUID, fingerprint: String) -> [Int: CheckpointChunkResult] {
        guard let cp = fetch(audioFileID: audioFileID) else { return [:] }
        guard cp.audioFingerprint == fingerprint else {
            // 音声が変わっている → 破棄
            modelContext.delete(cp)
            try? modelContext.save()
            return [:]
        }
        return decode(cp)
    }

    func save(audioFileID: UUID, fingerprint: String, totalChunks: Int,
              chunkIndex: Int, result: CheckpointChunkResult) {
        let cp = fetch(audioFileID: audioFileID)
            ?? {
                let new = TranscriptionCheckpoint(
                    audioFileID: audioFileID,
                    audioFingerprint: fingerprint,
                    totalChunks: totalChunks
                )
                modelContext.insert(new)
                return new
            }()
        var all = decode(cp)
        all[chunkIndex] = result
        encode(all, into: cp)
        cp.updatedAt = Date()
        try? modelContext.save()
    }

    func delete(audioFileID: UUID) {
        guard let cp = fetch(audioFileID: audioFileID) else { return }
        modelContext.delete(cp)
        try? modelContext.save()
    }

    // fetch/decode/encode は blob 方式で実装(§3.1 注記どおり)
    private func fetch(audioFileID: UUID) -> TranscriptionCheckpoint? { ... }
    private func decode(_ cp: TranscriptionCheckpoint) -> [Int: CheckpointChunkResult] { ... }
    private func encode(_ dict: [Int: CheckpointChunkResult], into cp: TranscriptionCheckpoint) { ... }
}
```

## 4. PR-B8: パイプライン組込

### 4.1 変更対象
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/PipelineCoordinator.swift`(store の生成と受け渡し)
- `Memora/Core/Services/STTSupportTypes.swift`(DTO 変換ヘルパ)

### 4.2 受け渡し設計

`STTService` は ModelContext を持たない/持たせない。**チェックポイント операはコールバック注入**にする(テスト容易性も確保):

```swift
// STTSupportTypes.swift
struct STTCheckpointHooks: Sendable {
    /// 完了済みチャンク結果を返す(fingerprint 不一致処理は hook 実装側の責務)
    let load: @Sendable (_ fingerprint: String) async -> [Int: CheckpointChunkResult]
    /// チャンク完了ごとに呼ばれる
    let save: @Sendable (_ fingerprint: String, _ totalChunks: Int, _ chunkIndex: Int, _ result: CheckpointChunkResult) async -> Void
    /// 全体成功時に呼ばれる
    let clear: @Sendable () async -> Void
}
```

`STTService.startTranscription(audioURL:language:)` に optional 引数を追加(既定 nil で完全後方互換):

```swift
func startTranscription(
    audioURL: URL,
    language: String?,
    checkpointHooks: STTCheckpointHooks? = nil
) async throws -> (any STTTaskHandleProtocol, AsyncStream<STTEvent>)
```

■確認: `STTServiceProtocol` の宣言。protocol にも既定値なしで追加するとモックが壊れるため、protocol は既存シグネチャのまま維持し、**extension でデフォルト転送**するか、STTService 具象型のみに新シグネチャを足して `TranscriptionEngine` から具象呼びする(既存も `as? STTService` キャストで具象を触っているため後者が現実的)。

`PipelineCoordinator` 側(MainActor)で hooks を構築:

```swift
let store = TranscriptionCheckpointStore(modelContext: modelContext)
let fileID = audioFile.id
let hooks = STTCheckpointHooks(
    load: { fingerprint in
        await MainActor.run { store.load(audioFileID: fileID, fingerprint: fingerprint) }
    },
    save: { fingerprint, total, index, result in
        await MainActor.run { store.save(audioFileID: fileID, fingerprint: fingerprint, totalChunks: total, chunkIndex: index, result: result) }
    },
    clear: {
        await MainActor.run { store.delete(audioFileID: fileID) }
    }
)
```

■確認: PipelineCoordinator → TranscriptionEngine → STTService の呼び出しチェーン。`TranscriptionEngine.transcribe(audioURL:language:referenceSpeakerCount:)` に `checkpointHooks` を透過させる引数を追加(既定 nil)。

### 4.3 `runTask` の変更(擬似差分)

```swift
preparedChunks = try await chunker.analyzeAndChunk(...)

// --- checkpoint 復元 ---
let fingerprint = await makeFingerprint(url: handle.audioURL, chunkCount: preparedChunks.count)
var restored: [Int: TranscriptionResult] = [:]
if let hooks = checkpointHooks {
    let saved = await hooks.load(fingerprint)
    restored = saved.mapValues { $0.toTranscriptionResult() }
    if !restored.isEmpty {
        DebugLogger.shared.addLog("STTService", "チェックポイント復元 — \(restored.count)/\(preparedChunks.count) チャンクを再利用", level: .info)
    }
}

// 直列ループ内:
for (index, chunk) in preparedChunks.enumerated() {
    try Task.checkCancellation()

    if let reused = restored[chunk.index] {
        chunkResults.append(reused)
        handle.yield(.audioChunkCompleted(chunkIndex: chunk.index, result: reused))
        // 進捗/LiveActivity 更新は通常経路と同じ計算で yield
        continue
    }

    // ...既存の transcribe...
    chunkResults.append(result)
    handle.yield(.audioChunkCompleted(chunkIndex: chunk.index, result: result))
    if let hooks = checkpointHooks {
        await hooks.save(fingerprint, preparedChunks.count, chunk.index, CheckpointChunkResult(from: result))
    }
    // ...LiveActivity...
}

// 成功終端(finalResult 確定後、cleanup 前):
if let hooks = checkpointHooks { await hooks.clear() }
```

API 並列経路(`processChunksConcurrently`)も同様: 復元済み index を group に積まず、完了ごとに `hooks.save`。■注意: 並列 save は MainActor 直列化されるため競合しない。

fingerprint:

```swift
private func makeFingerprint(url: URL, chunkCount: Int) async -> String {
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? -1
    let duration = Int(await audioFileDuration(for: url))
    return "\(size)-\(duration)-\(chunkCount)"
}
```

DTO 変換(`STTSupportTypes.swift`):

```swift
extension CheckpointChunkResult {
    init(from result: TranscriptionResult) { ... }
    func toTranscriptionResult() -> TranscriptionResult { ... }
}
```

### 4.4 キャンセル/失敗時の扱い

- `CancellationError` / エラー catch 節では **checkpoint を削除しない**(次回再開のために残す)。
- チェックポイントの寿命管理: `AudioFile` 削除時に残骸が残る。`AudioFileRepository` の削除処理(■確認: 削除実装箇所)に `TranscriptionCheckpointStore.delete(audioFileID:)` 呼び出しを追加。加えて起動時掃除(30 日超の checkpoint 削除)を `MemoraApp` の初期化後タスクに追加(任意、AC 外)。

### 4.5 STT 報告事項(PR-B8 説明に記載)

- 選択順への影響: なし。チャンク実行の前段に「復元スキップ」が入るのみ。
- 保存フォーマット: 既存 `Transcript` 不変。新規 `TranscriptionCheckpoint`(additive)。
- 話者分離: 影響なし(最終段で従来どおり実行)。

## 5. AC / 確認方法

1. **再開の実証**: 5 分音声(チャンク 4 個程度)のローカル文字起こし中、チャンク 2 完了時点でアプリを kill → 再起動 → 同ファイルで再実行 → ログに「チェックポイント復元 — 2/4」→ 完走。総処理時間が初回より明確に短い。
2. **fingerprint 無効化**: チェックポイント保存後に音声ファイルを別ファイルで差し替え(または duration の異なる同名ファイル)→ 再実行で復元されず全チャンク再処理+旧チェックポイント破棄ログ。
3. **成功時クリア**: 完走後、`TranscriptionCheckpoint` レコードが 0 件(DebugSection のデータ確認手段、なければテストで担保)。
4. **キャンセル時保持**: BG キャンセル(02)後にレコードが残っている。
5. **AudioFile 削除**でチェックポイントも消える。
6. API 並列モードでも 1 と同等の再開が成立。
7. 既存テスト+新規テスト(08 §4)green。マイグレーション後に既存データ(Transcript / AudioFile)が読める(実機アップグレードインストールで確認)。

## 6. PR 分割

| PR | 内容 |
|---|---|
| PR-C1 | モデル + Store + スキーマ登録 + マイグレーションテスト(パイプライン未接続。単体で無害) |
| PR-B8 | hooks 注入 + runTask/並列経路の組込 + 掃除処理 |
