# 09. PR 計画・ロールアウト・レビュー観点

---

## 1. PR 一覧(推奨マージ順)

> **更新(統合版)**: 長時間クラッシュ対策(14)が最優先の PR-B9〜B11 として先頭に入りました。
> STT コアを触る順序は **B9/B10/B11(14)→ B1〜B4(02)→ B8(07)** です。全体の実装順は `31_master_roadmap.md` を参照。

| 順 | PR ID | ブランチ名(例) | Lane | 設計書 | サイズ目安 | STT コア編集 |
|---|---|---|---|---|---|---|
| 0a | PR-B9 | `fix/stt-chunker-streaming` | B | 14 §3 | M | あり |
| 0b | PR-B10 | `fix/stt-streaming-merge` | B | 14 §4 | L | あり |
| 0c | PR-B11 | `feat/stt-memory-guard` | B | 14 §5 | S | あり |
| 1 | PR-B1 | `fix/stt-cancel-recognition-task` | B | 02 §2 | S | あり |
| 2 | PR-B2 | `fix/stt-background-expiration` | B | 02 §3 | S | あり |
| 3 | PR-B3 | `refactor/stt-deadline-utility` | B | 02 §4 | M | あり |
| 4 | PR-E1 | `test/stt-deadline-merge-silence` | E | 08 §2-4 | M | 抽出のみ(※1) |
| 5 | PR-B4 | `fix/stt-tail-silence-coverage` | B | 02 §5 | S | あり |
| 6 | PR-A1 | `feat/home-capture-fab` | A | 01 §4 | S | なし |
| 7 | PR-A2 | `fix/filedetail-fixed-tabs` | A | 01 §5 | S | なし |
| 8 | PR-A3 | `refactor/generation-flow-sheet` | A | 01 §6 | M | なし |
| 9 | PR-A4 | `fix/filedetail-more-menu` | A | 01 §7 | S | なし |
| 10 | PR-A6 | `feat/processing-status-badges` | A | 04 §3 | M | なし |
| 11 | PR-A7 | `feat/failure-alert-actions` | A | 04 §4 | S | なし |
| 12 | PR-B5 | `feat/stt-api-verbose-segments` | B | 03 §4 | M | あり |
| 13 | PR-B6 | `feat/stt-speechanalyzer-timing` | B | 03 §5 | M | あり(要実機検証先行) |
| 14 | PR-A5 | `feat/transcript-estimated-and-follow` | A | 03 §6 | M | なし |
| 15 | PR-A8 | `refactor/settings-hierarchy` | A | 05 | M | なし |
| 16 | PR-B7 | `feat/stt-posthoc-diarization-api` | B | 06 §3 | S | あり |
| 17 | PR-A9 | `feat/posthoc-diarization-ui` | A | 06 §4 | M | なし |
| 18 | PR-C1 | `feat/transcription-checkpoint-model` | C | 07 §3 | M | なし(モデル追加) |
| 19 | PR-B8 | `feat/stt-checkpoint-resume` | B | 07 §4 | L | あり |
| 20 | PR-E2 | `test/checkpoint-store` | E | 08 §5 | S | なし |

※1: PR-E1 で `merge` / retry 判定の関数抽出(`STTMerge` / `shouldRetryOnServer`)を伴う場合、その抽出コミットは PR-B3/B4 側に入れてもよい(実装エージェントの判断で、**抽出=挙動不変コミット**を明示分離すること)。

並行可能なトラック:
- トラック STT: 1→2→3→4→5→12→13→16→18→19→20
- トラック UI: 6→7→8→9→10→11→14→15→17(14 は 12 マージ後、17 は 16 マージ後)

## 2. 各 PR の共通テンプレート(CLAUDE.md §8 準拠)

```
## 変更概要
(設計書 XX §Y に基づく。1〜3 行)

## 変更ファイル一覧
- ...

## 影響範囲
- 画面: / サービス: / 保存形式: / バックエンド選択順:

## 実行した確認
- build_sim: green
- test_sim: green(新規テスト N 件追加)
- sim log: (該当ログ抜粋)

## 未確認事項(実機が必要な点)
- ...

## 次の PR でやること
- ...
```

STT コア編集 PR は上記に加えて必ず記載(CLAUDE.md §10):
- 変更したバックエンド選択順(なしなら「変更なし」と明記)
- SpeechAnalyzer / SFSpeechRecognizer / API のどこに影響するか
- 話者分離と保存フォーマットへの影響
- build/test/log の確認結果

## 3. レビュー観点(レビュアー/セルフレビュー用)

### STT 系(B)
- [ ] `didResume` 系フラグの lock 順序が「lock → 読み書き → unlock → 副作用」になっているか
- [ ] continuation の resume 経路がすべて `resumeOnce` / ガード経由か(直接 resume が残っていないか)
- [ ] `Task.checkCancellation()` がチャンクループ先頭にあるか(既存維持)
- [ ] UIKit API(UIApplication)呼び出しがすべて MainActor 経由か
- [ ] 診断ログ(`STTDiagnosticsLog` / `DebugLogger`)が変更経路にも記録されるか
- [ ] 一時チャンクの cleanup が全終端(成功/キャンセル/失敗)で呼ばれるか

### UI 系(A)
- [ ] STT コア保護ファイルに diff がないこと(`git diff --name-only` で機械確認)
- [ ] 状態フラグの追加が最小か(sheet 化で減らせるものを @State で増やしていないか)
- [ ] 44pt タップ領域 / accessibilityLabel / reduceMotion 分岐
- [ ] 日本語文言のトーン統一(です・ます、体言止めの混在なし)
- [ ] Dark mode でのコントラスト(特にチップ・バッジ)

### モデル系(C)
- [ ] 既存 @Model への破壊的変更ゼロ(additive のみ)
- [ ] `MemoraSchema` 登録漏れなし(未登録だと実行時クラッシュ)
- [ ] in-memory container テストが通ること
- [ ] 実機の「アップグレードインストール」(旧ビルド→新ビルド上書き)で既存データが読めること

## 4. ロールアウト / リスク緩和

1. **PR-B1〜B4 を最初の TestFlight に単独で載せる**(UI 変更と混ぜない)。クラッシュ率・文字起こし成功率のベースライン比較を行う。DebugLogger/STTDiagnostics のログで「タイムアウト後 partial なし」「BG キャンセル動作」を実機確認。
2. UI 群(PR-A1〜A9)は次ビルド。画面変更が多いためスクリーンショット付きで PR を出す。
3. PR-B6(SpeechAnalyzer timing)は **実機検証タスクの結果を Issue に貼ってから**着手判定(03 §5.3)。取得不可なら縮小版(推定フラグのみ)で出す。
4. Checkpoint(PR-C1/B8)は最後。マイグレーションを含むため、直前ビルドからのアップグレードインストール検証を必須とする。
5. 各段階で問題が出た場合の切り戻し: すべての PR は squash merge 前提のため revert 1 コミットで戻せる。B8 の revert 時は `TranscriptionCheckpoint` レコードが残るが、読み手がいなくなるだけで無害(次の掃除実装で削除)。

## 5. Issue 起票テンプレート(vibe-kanban / GitHub 用)

各 PR に対応する Issue を先に切る(1 Issue = 1 Workspace = 1 ブランチ)。

```
Title: [PR-B1] SFSpeechRecognizer タイムアウト時に recognitionTask を cancel する
Labels: lane:B, priority:P0, stt-core
Body:
  設計書: memora-design-package/02_stt_stability.md §2
  受け入れ条件: 設計書 §2.4 の 1〜4
  変更対象: Memora/Core/Services/STTService.swift
  変更しないもの: バックエンド選択順 / 保存形式 / 話者分離ロジック
```

## 6. 実装エージェントへの起動プロンプト例

```
あなたは Memora リポジトリの実装エージェントです。
まず CLAUDE.md、docs/transcription-core-boundary.md、
memora-design-package/00_README.md、
memora-design-package/02_stt_stability.md を読んでください。

タスク: 設計書 02 §2(PR-B1)のみを実装してください。
- 実装前に「やること / 変更対象ファイル / 変更しないファイル」を宣言すること
- 設計書内の「■確認せよ」項目を先に検証し、結果を報告してから実装すること
- 設計書のスニペットと現行コードが食い違う場合は、設計意図を優先し差分を報告すること
- 完了報告は CLAUDE.md §8 テンプレートで、STT コア報告(§10)も含めること
- 依頼範囲外の変更(ついでリファクタ)は禁止
```
