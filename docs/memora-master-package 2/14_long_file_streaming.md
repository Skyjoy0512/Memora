# 14. 長時間ファイルのクラッシュ対策(ストリーミング処理)詳細設計書

Lane: B (STT コア) / **STT コアタスク** / 優先度: **P0(最優先)**
依存: 02(安定化)、07(checkpoint)と相互補完 / 対応 PR: PR-B9〜B11

> この文書は「長時間ファイルで文字起こしが重い・クラッシュする」問題への直接対策。
> 07(checkpoint)は「中断からの再開」、本書(14)は「そもそもメモリ枯渇でクラッシュさせない」。
> 両方入れると「落ちない・落ちても再開できる」になる。**14 を先に入れる。**

---

## 1. クラッシュの根本原因(現行コードで確認済み)

`STTService.runTask` と `AudioChunker.analyzeAndChunk` を読んだ結果、長時間ファイルで落ちる原因は3つ:

### 原因 A: 全チャンクを事前に一括書き出し
`AudioChunker.analyzeAndChunk` は文字起こし開始**前**に、ファイル全体を 90 秒チャンクに割って**全部を一時 m4a に書き出し**、`[AudioChunk]` 配列で全件返す。

```
3時間ファイル → 120 チャンク → 120 個の m4a を一気に生成 → 全部ディスクに残す
```
- ディスク: 120 個の一時ファイルが同時に存在(元ファイルとほぼ同容量の重複)。
- 書き出し中に `AVAssetExportSession` を直列で 120 回。開始までに長時間かかり、その間ユーザーは無反応の画面を見る。

### 原因 B: 全チャンク結果をメモリに保持
`runTask` は `var chunkResults: [TranscriptionResult] = []` に**全チャンクの文字起こし結果を貯めてから**最後に merge する。
- 3時間 = 数万セグメント + 全文テキストがメモリに滞留。
- API 並列経路(`processChunksConcurrently`)は `orderedResults` 配列 + バッチ結果も同時保持。

### 原因 C: ピークメモリの偏り
チャンク生成(A)→ 全文字起こし(B)が段階分離しているため、ピーク時に「全一時ファイル + 全結果 + デコードバッファ」が重なる。iOS のメモリ上限(端末により 1〜3GB 程度で jetsam kill)に達して**OS に強制終了**される(これがクラッシュの実体)。

## 2. 対策の方針: ストリーミング(逐次)処理へ

「全部作ってから全部処理」を「1個作って処理して捨てる」に変える。

```
現行(バッチ):
  [全チャンク書き出し] → [全チャンク文字起こし] → [全結果 merge]
  ピークメモリ = 全部

改善(ストリーミング):
  for 各チャンク:
     1個書き出し → 文字起こし → 結果を「逐次マージ器」に流す → 一時ファイル即削除
  ピークメモリ = 1〜数チャンク分
```

- チャンクは**必要になった直前に1個だけ書き出す**(遅延生成)。
- 文字起こしが済んだチャンクの一時ファイルは**即削除**。
- 結果は全件配列に貯めず、**逐次マージ器**(下記)に流し込み、確定した transcript を随時 SwiftData に追記保存。
- これにより 3 時間でも 10 時間でもピークメモリはほぼ一定になる。

## 3. PR-B9: AudioChunker の遅延(ストリーミング)化

### 3.1 変更対象
- `Memora/Core/Services/AudioChunker.swift`
- `Memora/Core/Contracts/`(プロトコルに逐次 API 追加)

### 3.2 設計: プラン + オンデマンド書き出し

チャンク分割を「計画(plan)」と「書き出し(export)」に分ける。計画は軽い(境界の秒数リストを作るだけ、ファイル書き出しなし)。

```swift
/// チャンクの境界だけを持つ軽量プラン(ファイル書き出しはしない)
struct AudioChunkPlan: Sendable {
    struct Slice: Sendable {
        let index: Int
        let startSec: Double
        let endSec: Double
    }
    let sourceURL: URL
    let totalDuration: Double
    let slices: [Slice]
    var count: Int { slices.count }
    var isSingleChunk: Bool { slices.count == 1 }
}

protocol AudioChunkerProtocol {
    /// 従来 API(短尺・後方互換のため残す)
    func analyzeAndChunk(fileURL: URL, onProgress: AudioChunkProgressHandler?) async throws -> [AudioChunk]

    /// 新API: 計画だけ作る(書き出さない・軽い)
    func plan(fileURL: URL) async throws -> AudioChunkPlan

    /// 新API: 1スライスだけを一時ファイルへ書き出す(呼ばれた時に初めて書く)
    func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk

    func cleanup(chunks: [AudioChunk]) async
    /// 単一チャンクの後始末(逐次処理用)
    func cleanupChunk(_ chunk: AudioChunk) async
}
```

### 3.3 実装

```swift
func plan(fileURL: URL) async throws -> AudioChunkPlan {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { throw AudioChunkerError.fileNotFound }
    let asset = AVURLAsset(url: fileURL)
    guard let loaded = try? await asset.load(.duration) else { throw AudioChunkerError.durationUnavailable }
    let duration = CMTimeGetSeconds(loaded)
    guard duration.isFinite, duration >= 0 else { throw AudioChunkerError.durationUnavailable }

    if duration < shortThreshold {
        return AudioChunkPlan(sourceURL: fileURL, totalDuration: duration,
                              slices: [.init(index: 0, startSec: 0, endSec: duration)])
    }
    let chunkDuration = standardChunkDuration   // 90s
    var slices: [AudioChunkPlan.Slice] = []
    var startSec = 0.0
    var index = 0
    while startSec < duration {
        let endSec = min(startSec + chunkDuration, duration)
        slices.append(.init(index: index, startSec: startSec, endSec: endSec))
        index += 1
        startSec = endSec
    }
    return AudioChunkPlan(sourceURL: fileURL, totalDuration: duration, slices: slices)
}

func exportSlice(_ slice: AudioChunkPlan.Slice, from plan: AudioChunkPlan) async throws -> AudioChunk {
    // 単一チャンク(短尺)は元ファイルをそのまま使い書き出さない
    if plan.isSingleChunk {
        return AudioChunk(index: 0, startSec: 0, endSec: plan.totalDuration, url: plan.sourceURL, isTemporary: false)
    }
    let asset = AVURLAsset(url: plan.sourceURL)
    let url = try await exportChunk(from: asset, start: slice.startSec, end: slice.endSec, index: slice.index)
    return AudioChunk(index: slice.index, startSec: slice.startSec, endSec: slice.endSec, url: url, isTemporary: true)
}

func cleanupChunk(_ chunk: AudioChunk) async {
    guard chunk.isTemporary else { return }
    try? FileManager.default.removeItem(at: chunk.url)
}
```

`exportChunk`(既存の AVAssetExportSession 処理)はそのまま流用。

### 3.4 AC
1. 3時間ファイルで `plan()` が即座に返る(ファイル書き出しゼロ)。
2. `exportSlice` を呼んだ時だけ1個の m4a が生成される。
3. 短尺(90秒未満)は書き出しゼロで元ファイルを使う(従来どおり)。

## 4. PR-B10: runTask のストリーミング化 + 逐次マージ

### 4.1 変更対象
- `Memora/Core/Services/STTService.swift`(`runTask`, `processChunksConcurrently`)
- `Memora/Core/Services/STTSupportTypes.swift`(逐次マージ器)

### 4.2 逐次マージ器(全結果を配列に貯めない)

```swift
/// チャンク結果を逐次受け取り、オフセット加算しながら
/// 全文とセグメントを積み上げる。全 TranscriptionResult を配列保持しない。
struct StreamingTranscriptMerger {
    private(set) var fullTextParts: [String] = []
    private(set) var segments: [TranscriptionSegment] = []
    private var detectedLanguage: String?

    mutating func append(chunk: AudioChunk, result: TranscriptionResult) {
        if detectedLanguage == nil, !result.language.isEmpty { detectedLanguage = result.language }
        let offset = chunk.startSec
        fullTextParts.append(result.text)
        for seg in result.segments {
            segments.append(TranscriptionSegment(
                id: seg.id,
                speakerLabel: seg.speakerLabel,
                startSec: seg.startSec + offset,
                endSec: seg.endSec + offset,
                text: seg.text,
                isEstimatedTiming: seg.isEstimatedTiming   // 03 実装後
            ))
        }
    }

    func finalize() -> TranscriptionResult {
        TranscriptionResult(
            fullText: fullTextParts.joined(separator: "\n"),
            language: detectedLanguage ?? "ja",
            segments: segments
        )
    }

    /// メモリ上限が心配な超長時間向け: 確定済みセグメントを外部に吐き出して自身は解放
    mutating func drainSegments() -> [TranscriptionSegment] {
        let out = segments
        segments.removeAll(keepingCapacity: false)
        return out
    }
}
```

注: `segments` は最終的に `Transcript` に保存するため完全には捨てられないが、**中間の `TranscriptionResult` オブジェクト(各チャンクの全文文字列コピー等)を貯めない**だけでメモリは大幅に減る。超長時間(例: 8時間超)対策として `drainSegments` で SwiftData に分割追記する経路も用意(§4.4)。

### 4.3 runTask 直列経路の書き換え(擬似差分)

```swift
// 変更前: let preparedChunks = try await chunker.analyzeAndChunk(...)  // 全書き出し
// 変更後: plan だけ作る
let plan = try await chunker.plan(fileURL: handle.audioURL)
let totalChunks = max(plan.count, 1)
DebugLogger.shared.addLog("STTService", "チャンク計画: \(plan.count)(遅延生成)", level: .info)

var merger = StreamingTranscriptMerger()

// checkpoint 復元(07 と統合する場合)
let fingerprint = await makeFingerprint(url: handle.audioURL, chunkCount: plan.count)
let restored = await checkpointHooks?.load(fingerprint) ?? [:]

for slice in plan.slices {
    try Task.checkCancellation()

    // 復元済みなら書き出しも文字起こしもスキップ
    if let saved = restored[slice.index] {
        merger.append(chunk: AudioChunk(index: slice.index, startSec: slice.startSec, endSec: slice.endSec, url: handle.audioURL, isTemporary: false),
                      result: saved.toTranscriptionResult())
        handle.yield(.audioChunkCompleted(chunkIndex: slice.index, result: saved.toTranscriptionResult()))
        updateProgressAndLiveActivity(slice.index + 1, totalChunks)
        continue
    }

    // 1個だけ書き出す
    let chunk = try await chunker.exportSlice(slice, from: plan)
    do {
        let result = try await transcribeChunk(chunk, ...)   // 既存のチャンク文字起こし
        merger.append(chunk: chunk, result: result)
        handle.yield(.audioChunkCompleted(chunkIndex: slice.index, result: result))
        await checkpointHooks?.save(fingerprint, plan.count, slice.index, CheckpointChunkResult(from: result))
    } catch {
        await chunker.cleanupChunk(chunk)   // 失敗時もこのチャンクは消す
        throw error
    }
    // ★このチャンクの一時ファイルを即削除(メモリ&ディスク解放の要)
    await chunker.cleanupChunk(chunk)
    updateProgressAndLiveActivity(slice.index + 1, totalChunks)
}

let finalResult = merger.finalize()
await checkpointHooks?.clear()
// 以降、既存の話者分離・保存処理へ finalResult を渡す
```

**要点**: `preparedChunks`(全チャンク配列)と `chunkResults`(全結果配列)が消え、常に「今のチャンク1個」だけをメモリに持つ。cleanup も逐次。

### 4.4 超長時間向け: セグメントの分割追記(任意・Phase 2)

8時間超などでセグメント配列自体が重い場合、一定数ごとに `Transcript` へ追記保存して merger を drain する。ただし現行の `Transcript`(並列配列)は「全体を1回で保存」前提なので、追記対応は保存形式の見直しが要る。**まずは §4.3 のストリーミングだけで大半の端末の 3〜5 時間は救済できる**ため、4.4 は必要になってから。

### 4.5 API 並列経路のストリーミング化

`processChunksConcurrently` も「全チャンク事前書き出し前提」なので直す:
- plan の slices を `maxConcurrentChunks`(4)ずつのバッチに分け、**バッチ単位で exportSlice → 並列文字起こし → 即 merger.append → 即 cleanupChunk**。
- `orderedResults` 全件配列をやめ、バッチ内だけ順序を保ち merger に順次流す。
- 並列は「同時に最大4チャンクだけディスク&メモリに存在」に制限され、ピークが一定になる。

```swift
for batch in plan.slices.chunked(into: maxConcurrentChunks) {
    let chunks = try await withThrowingTaskGroup(of: (Int, AudioChunk).self) { g in
        for slice in batch { g.addTask { (slice.index, try await self.chunker.exportSlice(slice, from: plan)) } }
        var acc: [(Int, AudioChunk)] = []
        for try await r in g { acc.append(r) }
        return acc.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    let results = try await withThrowingTaskGroup(of: (Int, TranscriptionResult).self) { g in
        for chunk in chunks { g.addTask { (chunk.index, try await self.transcribeChunk(chunk, ...)) } }
        var acc: [(Int, TranscriptionResult)] = []
        for try await r in g { acc.append(r) }
        return acc.sorted { $0.0 < $1.0 }
    }
    for (i, (idx, result)) in results.enumerated() {
        merger.append(chunk: chunks[i], result: result)
        await checkpointHooks?.save(fingerprint, plan.count, idx, CheckpointChunkResult(from: result))
    }
    for chunk in chunks { await chunker.cleanupChunk(chunk) }   // バッチ終了で即削除
}
```

### 4.6 AC
1. 3時間のローカルファイルで文字起こしが**クラッシュせず完走**する(実機の実メモリで確認、jetsam kill が起きない)。
2. 処理中のピークメモリが従来比で大幅減(Instruments Allocations で確認、チャンク数に比例して増えない)。
3. 一時 m4a がディスクに「同時に1個(直列)/最大4個(並列)」しか存在しない(処理中に `chunksDirectory` を監視)。
4. 進捗・Live Activity が従来どおりチャンクごとに更新。
5. 途中キャンセルで現チャンクの一時ファイルも残らない。
6. 短尺・中尺の既存挙動が不変。

## 5. PR-B11: メモリ圧・熱・時間のガード

### 5.1 メモリ警告への応答
`STTService` で `UIApplication.didReceiveMemoryWarningNotification`(iOS)を購読し、警告時に:
- 進行中の API 並列度を一時的に下げる(4→1)。
- ログに記録し、必要ならユーザーに「省メモリモードに切替」表示。

```swift
NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                       object: nil, queue: .main) { [weak self] _ in
    self?.underMemoryPressure = true
    DebugLogger.shared.addLog("STTService", "メモリ警告受信 — 並列度を下げます", level: .warning)
}
```

### 5.2 長時間の事前見積もりとユーザー確認
`plan()` の総時間から概算処理時間・チャンク数を出し、極端に長い(例: 3時間超)場合は開始前に確認:

```
「この録音は約 N 時間で、文字起こしに時間がかかります(推定 M 分)。
 バックグラウンドでも継続しますが、端末の充電を推奨します。開始しますか?」
```

これは 04(失敗UX)/ Live Activity とも整合。

### 5.3 バックグラウンド継続との整合
02(BG 期限切れの安全停止)と 07(checkpoint)により、BG で中断されても再開できる。14 のストリーミングは「BG 中断時に貯め込んだ巨大メモリを失わない」意味でも有効(そもそも貯めない)。

### 5.4 AC
1. メモリ警告で並列度が下がりログに残る。
2. 長時間ファイルで開始前に確認ダイアログ(充電推奨)。
3. BG 中断 → 復帰(または再起動)後、checkpoint から再開しクラッシュなく完走。

## 6. 07(checkpoint)との統合方針

14 と 07 は同じ `runTask` を触る。**マージ順**:
1. まず **14(PR-B9/B10)** を入れてストリーミング化(落ちなくする)。
2. 次に **07(PR-C1/B8)** の checkpoint hooks を、14 のストリーミングループに差し込む(§4.3 に既に `checkpointHooks` 呼び出しを織り込み済み)。
3. 結果、「落ちない(14)+落ちても再開(07)」が両立。

コンフリクトを避けるため、07 の runTask 差分は「14 適用後のループ」を前提に書き直す(09/30 のPR順に反映)。

## 7. テスト(08 に追加)

- `AudioChunkPlan` の境界計算(3時間→ 正しいスライス数・端数)単体テスト。
- `StreamingTranscriptMerger` のオフセット加算・言語確定・finalize を単体テスト(実機不要)。
- 長時間はメモリの単体テストが難しいため、**手動QA**: 実機で3時間ファイル→Instruments Allocations でピークメモリがチャンク数に比例しないことを確認。

## 8. まとめ

| 症状 | 原因 | 対策 |
|---|---|---|
| 長時間で重い(開始が遅い) | 全チャンク事前書き出し | plan で遅延生成(B9) |
| 長時間でクラッシュ(OS kill) | 全チャンク結果+全一時ファイルのメモリ/ディスク滞留 | ストリーミング処理+逐次削除+逐次マージ(B10) |
| メモリ警告で不安定 | 並列度固定・ガードなし | メモリ警告応答・並列度可変(B11) |
| 中断で最初から | 中間結果を保持しない | checkpoint(07)と統合 |
