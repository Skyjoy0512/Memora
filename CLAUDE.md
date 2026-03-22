# Memora 開発運用ガイド（MCP / 並列開発 / 2026-03 更新）

## 0. 目的
- Memora を「MCP 前提」で高速に開発する。
- GitHub での PR 運用を標準化し、ローカルでの手動マージを極力なくす。
- Figma デザインを SwiftUI に再現しつつ、LiftKit の設計思想を使って黄金比ベースで整える。

## 1. コミュニケーションルール
- 回答・進捗報告・完了報告は日本語で行う。
- 実装前に「やること」「変更対象ファイル」「変更しないファイル」を宣言する。
- ログやエラー原文は英語のまま引用してよいが、解釈は日本語で記述する。
- 変更は最小差分を原則とし、依頼範囲外のついでリファクタはしない。

## 2. 現在の技術前提（このリポジトリ基準）
- iOS target: 17.0（`project.yml`）
- Xcode: 26.3（ローカル確認済み）
- 実装: SwiftUI + SwiftData + MVVM ベース
- ディレクトリ責務:
  - `Memora/App`: App 起動・ライフサイクル
  - `Memora/Core/Services`: 録音・再生・STT・要約などのドメインサービス
  - `Memora/Core/Models`: SwiftData モデル
  - `Memora/Core/ViewModels`: 画面状態管理
  - `Memora/Views`: UI

## 3. MCP / ツール運用方針

### 3.1 Superpowers（開発プロセスの型）
- Claude Code では plugin として利用する。
- 推奨インストール:
```bash
/plugin install superpowers@claude-plugins-official
```
- 基本フロー:
  1. brainstorming
  2. writing-plans
  3. using-git-worktrees
  4. subagent-driven-development
  5. test-driven-development
  6. requesting-code-review

### 3.1.1 Swift Agent Skills（Swift 専門スキルカタログ）
- `twostraws/swift-agent-skills` は「単体スキル」ではなく、Swift 向け skill 集のディレクトリとして扱う。
- 運用ルール:
  - いきなり全導入せず、用途ごとに 1 つずつ評価して採用する。
  - 採用前に README / ライセンス / 更新状況を確認する。
  - 第三者 skill は必ず内容をレビューしてから使う（盲目的に実行しない）。
- Memora の初期採用候補:
  - SwiftUI: `twostraws/SwiftUI-Agent-Skill`
  - SwiftData: `twostraws/SwiftData-Agent-Skill`
  - Concurrency: `twostraws/Swift-Concurrency-Agent-Skill`
  - Testing: `twostraws/Swift-Testing-Agent-Skill`
- スキルを増やしすぎると文脈が散るため、常時有効は上記 4 系統までを目安にする。

### 3.2 XcodeBuildMCP（iOS 開発の主ツール）
- Codex / Claude から同じ MCP サーバーを使う。
- 推奨（npx 経由）:
```bash
codex mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
```
- 作業開始時の標準手順（CLI でも MCP でも同じ意図）:
  1. `doctor`（環境確認）
  2. `discover_projs`（対象プロジェクト検出）
  3. `list_schemes`（Scheme 特定）
  4. `session_show_defaults` → 必要なら `session_set_defaults`
  5. `build_sim` / `test_sim`
- 不具合調査時は `start_sim_log_cap` / `stop_sim_log_cap` を優先して証拠を残す。

### 3.3 vibe-kanban（可視化と並列実行）
- 起動:
```bash
npx vibe-kanban
```
- 運用ルール:
  - 1 Issue = 1 Workspace = 1 ブランチ
  - Workspace ごとに担当エージェントを固定する
  - レビューコメントは PR ではなく、まず Workspace の diff 上で返す
  - PR 作成後は GitHub 側で Auto-merge を使う

### 3.4 CCpocket（モバイルからの進行・承認）
- 外出中の「確認」「軽微指示」「再実行トリガー」用途に限定する。
- 秘密情報の入力・本番デプロイ操作はモバイル経由で行わない。
- 重要判断は必ず GitHub Issue / PR コメントに残す（チャットのみで完結させない）。

### 3.5 Claude Agent Teams（Lead + Teammates）
- Agent Teams を並列開発の第一選択とする（複雑なEpicのみ）。
- Lead は PM 役として、Issue 分解・割当・進捗統合を行う。
- 詳細運用は `docs/agent-teams-playbook.md` を参照。

## 4. GitHub 運用（ローカル手動マージ最小化）

実際の自動反映手順は `docs/parallel-development-automation.md` を参照する。

### 4.1 必須設定（`master`）
- Branch protection を有効化
- Required status checks を必須化
- Require pull request before merging を有効化
- Auto-merge を有効化
- 可能なら Merge queue を有効化
- Squash merge を標準化（履歴を単純化）
- GitHub Project V2 は任意（未設定でも Issue/PR ラベル運用で並列開発は可能）

### 4.2 ブランチ命名
- `feat/<issue-id>-<slug>`
- `fix/<issue-id>-<slug>`
- `chore/<issue-id>-<slug>`

### 4.3 PR ルール
- 1 PR 1 目的（巨大 PR 禁止）
- 変更ファイルの責務が複数レーンにまたがる場合は PR を分割
- CI green + review 完了後に Auto-merge を設定

## 5. 並列開発の責務分割（Memora 用）

### 5.1 レーン定義
- Lane A: UI 実装
  - 対象: `Memora/Views/**`
- Lane B: 音声/STT
  - 対象: `Memora/Core/Services/Audio*`, `Memora/Core/Services/STT*`, `Memora/Core/Services/TranscriptionEngine.swift`
- Lane C: モデル/状態管理
  - 対象: `Memora/Core/Models/**`, `Memora/Core/ViewModels/**`, `Memora/Core/Contracts/**`
- Lane D: アプリ基盤/統合
  - 対象: `Memora/App/**`, `project.yml`, `Memora.xcodeproj/**`, `.github/**`
- Lane E: QA/運用
  - 対象: テスト、ログ収集、CI、リリースノート、回帰確認

### 5.2 競合回避ルール
- 1 Issue で触るレーンは原則 1 つ。
- 複数レーンが必要な作業は「基盤 PR → 機能 PR」の順で分割。
- `project.pbxproj` と CI は Lane D のみが変更する。

## 6. Figma + MCP + LiftKit 運用（黄金比補正）

### 6.1 前提
- Figma MCP は接続済み前提で使う。
- Auto Layout が崩れている画面は、実装前に Figma 側で構造を補正してから着手する。
- 補正できない場合は assumptions を明示して実装する。

### 6.2 LiftKit の扱い
- LiftKit は「設計思想の参照」として使う。
- 現行 LiftKit は README 上で production 非推奨の注意があるため、Memora に直接依存として入れない。
- 利用対象:
  - スケール/余白/比率のルール
  - Figma 上の再設計指針

### 6.3 黄金比トークン（SwiftUI 側の推奨値）
- 比率定数: `phi = 1.618`
- Spacing scale（px）: `5, 8, 13, 21, 34, 55`
- Corner radius（px）: `8, 13, 21`
- Typography scale（pt）: `12, 14, 17, 21, 26, 34`
- 行間の目安: `fontSize * 1.45 ~ 1.62`

### 6.4 UI レビュー時の合格条件
- 余白がトークンスケールに乗っている
- 主要コンテナ比が 1:1.618 近傍（許容差 ±8%）
- 視覚重心が崩れていない
- iOS 可用性を満たす（最小タップ領域 44pt）

## 7. 作業開始チェックリスト
1. `git fetch origin`
2. `git switch -c <type>/<issue-id>-<slug>`
3. MCP 健全性確認（`doctor` 相当）
4. 対象 Issue の受け入れ条件を貼る
5. 実装開始

## 8. 完了報告テンプレート（必須）
- 変更概要
- 変更ファイル一覧
- 影響範囲
- 実行した確認（build/test/log）
- 未確認事項（実機確認が必要な点）
- 次の PR でやること

## 8.1 PMエージェント運用
- Epic分解と担当割り当ては `docs/pm-agent-workflow.md` を参照する。
- Claude Code では `/pm-breakdown` と `/pm-assign` を使ってIssue分解・再アサインを行う。

## 9. 禁止事項
- `master` への直接 push
- 担当レーン外の無断変更
- 証拠なしの「動作したはず」報告
- 仕様変更をコード先行で進めること
