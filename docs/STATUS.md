# Memora 開発ステータス（2026-09-08）

> 目的: GitHub 上のコードだけを読む AI モデル（Claude / Codex / OpenCode 等）が
> 「いま何が最新で、どこに進捗・課題の材料があるか」を誤認せず把握するための案内。
> 本ファイルは main に置き、常に最新の状態を指し示すよう更新する。

## リポジトリの正体と読み方

- 製品: Memora — iOS ファースト / local-first の会議メモアプリ（録音→文字起こし→要約→Ask AI→エクスポート）
- 実装対象: `apps/mobile-expo`（React Native / Expo / Expo Router / HeroUI Native）。旧 SwiftUI UI は 2026-08-09 に削除済み（ADR-003）
- 開発運用の正本: [CLAUDE.md](../CLAUDE.md) と [docs/agent-operating-model.md](./agent-operating-model.md)（役割: Sol / Luna / OpenCode / Claude）
- デザイン判定基準: [docs/design/prohibitions.md](./design/prohibitions.md)、[MEMORA_DESIGN.md](./design/MEMORA_DESIGN.md)
- トークン正本: `apps/mobile-expo/src/theme/tokens.ts`（互換アダプタ: `src/design/tokens.ts`）

## 最新状態（重要）

**`main` の最新は #210（2026-08-15）で、8月中旬以降の Lane F 作業は main に無い。**
最新の実装・検証・報告はすべて以下に集約されている:

- **PR #212（Draft）** — ブランチ `chore/opencode-20260816`
  - コミット 8 件: 単体テスト +21（65→86→93）/ hitSlop 追加 / fontSize トークン化 /
    **Open Design v2 デザイン刷新（全画面・共通部品・トークン）** /
    生成失敗画面の改善（T1）/ hitSlop フォローアップ / FileDetail 未使用スタイル削除 /
    報告書の git 管理化
  - この PR を「現在の最新」として読むこと。main 単体を読むと 3 週間前の状態になる

## 検証状態（2026-09-07 / 09-08 実測）

| コマンド | 結果 |
|---|---|
| `npm test`（apps/mobile-expo） | pass — 9 ファイル / 93 件 |
| `npm run typecheck` | pass |
| `npx expo export --platform web` | pass |
| `git diff --check` | pass |
| `npm run qa:ios:build` / 実機 / Simulator | 未実行（環境制約。実機 QA は次担当） |

## 実用度スコア: 約 57 / 100

「実機で日常運用に耐える」を 100 とした評価。詳細は
`docs/agent-workflows/score-usable-2026-09-07.md`（PR #212 に同梱）。

- コアフロー（録音→STT→要約→詳細→Ask AI→エクスポート）はコード上接続済み
- 未達の主因: **実機 / 配信ゲート（25/100 相当）**、Ask AI の対象指定・コピー・音声入力、
  会議キャプチャ、Settings の大半が未実装
- 配信は「アプリ完成まで署名・ストア提出を先送り」の方針（過去セッション合意）

## 判断保留・次の決定待ち（翌朝の作業の起点）

1. **フォント方針の衝突**: `@expo-google-fonts/inter` / `ibm-plex-mono` の追加が
   prohibitions §3.1（フォント非依存）と v0.6/v0.7 デザイン正本（Plex/Inter 採用）で矛盾。
   どちらを正とするか上位判断が必要（PR #212 に含まれる）
2. **fontSize 直書き 3 件**: タブラベル 11（NativeTabs・native 直渡し）/
   islandTimer 12 / recordingTime 44 — 新トークン追加または設計判断待ち
3. **hitSlop 未達**: PlayerBar シークバーは非干渉上限 28pt（44 未満）/
   Ask AI 対象シートの RadioGroup 行は実機での干渉確認が必要
4. **未実装導線**: 会議キャプチャ・タスク期限・Ask AI コピー/添付/音声入力・Settings 主要行 —
   仕様判断が必要（一覧: `docs/agent-workflows/review-v2-refresh.md`）
5. **実機 QA**: 録音→バックグラウンド継続→要約（実 API キー）→書き出しの完走と署名成立

## 報告書の所在（PR #212 に git 管理化済み）

- `docs/agent-workflows/opencode-handoff-2026-08-16-result.md` — Lane F 品質対応（A〜E）結果
- `docs/agent-workflows/opendesign-v2-handoff-2026-08-24.md` — Open Design v2 刷新の引き継ぎ
- `docs/agent-workflows/review-v2-refresh.md` — v2 刷新レビュー（要修正・判断保留）
- `docs/agent-workflows/score-usable-2026-09-07.md` — 実用度スコアリング（57/100）
- `docs/agent-workflows/triage-root-misc-2026-09-07.md` — root 雑多ファイルの切り分け

## ローカル運用メモ

- `apps/mobile-expo/ios/Podfile.lock` にはローカル差分があり、コミット対象外（CI 生成物）
- root の `AGENTS.md` / `PROJECT_SPEC.md` / `TASKS.md` / `CODEX_BOOTSTRAP_PROMPT.md` /
  `zoom-meeting-notes-spec.zip` は **Memora とは別案件（Zoom Meeting Notes Chrome 拡張）** の
  誤置ファイル（git 未管理）。AGENTS.md は自動適用されるため撤去済み。残りも整理待ち
- `docs/design-system/` はデザイン正本ジェネレータ一式（git 未管理・管理方針決定待ち）
