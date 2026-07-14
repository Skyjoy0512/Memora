# 32. Ph2 マージ計画(レビュー結果と衝突解消手順)

レビュー日: 2026-07-05 / 対象: Ph2 実装の18ブランチ(全て origin/main = 44dc30e 起点 ✅)

---

## 1. レビュー総評

**良い点**
- 全18ブランチが正しく main から切られている(前回の旧履歴事故は解消)✅
- UI系7ブランチは STT コア保護ファイルに一切触れていない ✅
- ストリーミング系(B9→B10→B11)は正しく積み上げ(stacked)構造 ✅
- UI系はマージシミュレーションで全て衝突なし ✅

**問題点(マージ前に要対応)**
| # | 問題 | 深刻度 |
|---|---|---|
| P-1 | STT系5ブランチがマージ衝突する(後述) | 高(構造問題) |
| P-2 | checkpoint の fingerprint がエスケープバグで**全ファイル同一文字列**になる | 高(実バグ) |
| P-3 | Gemini 文字起こしの既存実装が古いモデル/不正MIMEで実運用不可 | 中 |
| P-4 | checkpoint 復元チャンクで進捗/LiveActivity 更新がスキップされる | 低 |

## 2. P-1: マージ衝突の詳細と原因

マージシミュレーション結果(ロードマップ順):

```
OK       feat/stt-memory-guard        (B9+B10+B11 一括)
OK       fix/stt-cancel-recognition-task  (B1)
CONFLICT fix/stt-background-expiration    (B2)  → STTService.swift
CONFLICT refactor/stt-deadline-utility    (B3)  → STTSupportTypes.swift
CONFLICT fix/stt-tail-silence-coverage    (B4)  → STTSupportTypes.swift
CONFLICT test/stt-deadline-merge-silence  (E1)  → STTSupportTypes.swift
OK       feat/transcription-checkpoint-model (C1)
CONFLICT feat/stt-checkpoint-resume       (B8)  → STTService + STTSupportTypes
OK       feat/gemini-transcription-provider(Z1)
OK       UI系7本すべて
```

原因: B2〜B8 が**ストリーミング改修(B9-B11)適用前の main から独立に切られ、旧 runTask / 旧 STTSupportTypes を前提に書かれている**。設計書 14 §6 の「07 の runTask 差分は 14 適用後のループを前提に書き直す」が守られていない。

衝突の質:
- STTSupportTypes の3件(B3/B4/E1)は「ファイル末尾への追記同士」の**軽微な衝突**。両方の追記を残せば解消。
- B2 の STTService 衝突は startTranscription 周辺。中程度。
- **B8 は runTask のループ本体が B10 で書き換わっているため、機械的な解消では済まない**。checkpoint フックをストリーミングループ(plan/exportSlice/merger)に組み込み直す必要がある(設計 14 §4.3 に組込先のコードが既にある)。

## 3. P-2: fingerprint バグ(必修正)

`feat/stt-checkpoint-resume` の `makeFingerprint`:

```swift
return "\\(size)-\\(duration)-\\(chunkCount)"   // ← バックスラッシュがエスケープされ
// 実行結果は常に固定文字列 「\(size)-\(duration)-\(chunkCount)」
```

影響: 全ファイル・全状態で fingerprint が同一 → **音声を差し替えても古いチェックポイントが「有効」と誤判定**され、壊れた transcript が復元される。修正は `\\(` → `\(` の3箇所(同ブランチの DebugLogger 文字列にも同種のエスケープあり。`grep '\\\\(' ` で全捜索して直す)。

## 4. P-3: Gemini 文字起こし

ブランチ自体はフラグ2箇所の変更のみだが、main に既存の `GeminiService.transcribe` が存在し配線済みのため構造は正しい。ただし既存実装に2点の問題:

1. `gemini-1.5-flash` — 廃止系モデル。**`gemini-2.5-flash`(または実装時点の現行 Flash)へ変更**。
2. `mime_type: "audio/mp4a"` — 不正な MIME。チャンクは m4a なので **`audio/mp4`** に修正(Gemini 対応 MIME を実装時に確認)。

加えて設計 22 §3 の「無料枠は学習利用される」警告 UI が未実装。フラグ ON でユーザーに露出するため、**警告文言だけでも設定画面の Gemini 選択時に添えてからマージ**すること。

## 5. マージ実行計画

### Phase A: 衝突なし群を先にマージ(即実行可)
```
1. feat/stt-memory-guard            ← B9/B10/B11(長時間対策の本体)
2. fix/stt-cancel-recognition-task  ← B1
3. feat/transcription-checkpoint-model ← C1(モデルのみ、無害)
4. UI系7本(home-capture-fab → filedetail-fixed-tabs → generation-flow-sheet
   → filedetail-more-menu → processing-status-badges → failure-alert-actions
   → settings-hierarchy)
   ※ fix/filedetail-fixed-tabs は Figma 判断(25 D-2)次第で保留可
```
※ 各マージ後にビルド確認。UI系は「memory-guard 適用後の main」に対しても衝突しないことをシミュレーション確認済み。

### Phase B: 衝突群をリベース+修正(Codex 1タスクずつ)
```
5. fix/stt-background-expiration  → 最新 main に rebase、衝突解消(設計02 §3 準拠)
6. refactor/stt-deadline-utility  → 同上(STTSupportTypes 末尾追記の統合)
7. fix/stt-tail-silence-coverage  → 同上
8. test/stt-deadline-merge-silence → 同上
9. feat/stt-checkpoint-resume     → **rebase でなく再実装に近い**。
   14 §4.3 のストリーミングループへ hooks を組込み直す + P-2 fingerprint 修正
   + 復元チャンクでも進捗/LiveActivity を更新(P-4)
```

### Phase C: Gemini(修正後にマージ)
```
10. feat/gemini-transcription-provider に追いコミット:
    モデル更新(2.5-flash)+ MIME 修正 + 設定画面の学習利用警告
```

## 6. Codex への指示テンプレート(Phase B 用)

```
git fetch origin
git checkout <ブランチ名>
git rebase origin/main
衝突が出たら、設計書 <対応設計書§> の意図に従って解消すること。
特に feat/stt-checkpoint-resume は、main の runTask が
ストリーミング構造(AudioChunkPlan / exportSlice / StreamingTranscriptMerger)に
変わっているため、旧 preparedChunks ループへの挿入をやめ、
設計書 14_long_file_streaming.md §4.3 のとおりストリーミングループへ組み込むこと。
併せて makeFingerprint の "\\(" エスケープバグを "\(" に修正(同種箇所を全検索)。
解消後: build green を確認して force-push(--force-with-lease)。
```

## 7. マージ後の必須手動確認

- [ ] 3時間級の音声でローカル文字起こしが完走(14 の本丸。Instruments でピークメモリ確認)
- [ ] 途中 kill → 再実行で「チェックポイント復元 n/m」ログ+完走
- [ ] 音声ファイル差し替え後に古いチェックポイントが破棄される(P-2 修正の検証)
- [ ] Gemini 文字起こしが実際に成功する(API キー設定)
- [ ] FAB → 録音 → 保存 → 自動文字起こし(UI 統合確認)
