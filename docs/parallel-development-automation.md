# 並列開発の自動反映セットアップ

## 目的
- 各エージェントの進捗を Issue / PR / Project V2 に自動反映する。
- 「誰が何を進めているか」を GitHub 上で常に確認できる状態にする。
- GitHub初心者でも、まずは Issue + PR だけで並列開発を回せるようにする。

## 追加した自動化
- `.github/workflows/setup-labels.yml`
  - 初期ラベル（`status:*`, `lane:*`, `agent:*`, `type:*`）を作成/更新
- `.github/workflows/ci.yml`
  - `master` への push / PR で iOSビルドを実行
- `.github/workflows/pr-labeler.yml`
  - PR差分のパスから `lane:*` ラベルを自動付与
- `.github/workflows/auto-pr-from-push.yml`
  - `master` 以外のブランチに push したら、未作成なら Draft PR を自動作成
- `.github/workflows/auto-enable-automerge.yml`
  - PR に `automerge` ラベルが付いたら Auto-merge を自動有効化（リポジトリ設定側でAuto-merge有効が前提）
- `.github/workflows/status-label-sync.yml`
  - Issue/PRイベントに応じて `status:*` ラベルを自動で1つに統一
- `.github/workflows/issue-form-label-sync.yml`
  - Issueフォームの `Lane` / `Agent` 回答を `lane:*` / `agent:*` ラベルへ自動同期
- `.github/workflows/epic-auto-split.yml`
  - `[Epic]` Issue の `要件` 箇条書きから子Taskを自動起票
- `.github/workflows/project-v2-sync.yml`
  - Issue/PRを Project V2 に追加し、Status列を自動更新
- `.github/workflows/pr-progress-comment.yml`
  - `Closes #123` 形式でリンクされたIssueに、PR進捗コメントを自動投稿
- `.github/workflows/linked-issue-status-from-pr.yml`
  - PR本文で参照されたIssue（`Closes #123`, `Refs #123`）の `status:*` をPR状態に連動して更新

## 必須のGitHub設定

### 1) 一度だけ実行
1. Actions タブから `Setup Labels` を手動実行
2. `type:* / status:* / lane:* / agent:* / automerge / needs:pm-triage` ラベルが作成されることを確認

### 2) Repository Variables（Project同期を使う場合のみ）
`Settings > Secrets and variables > Actions > Variables` に以下を追加:

- `GH_PROJECT_OWNER`
  - 例: `Skyjoy0512` または組織名
- `GH_PROJECT_NUMBER`
  - 例: `3`（Project V2の番号）

任意（未設定時はデフォルト値を使用）:
- `GH_PROJECT_STATUS_FIELD`（default: `Status`）
- `GH_PROJECT_STATUS_TODO`（default: `Todo`）
- `GH_PROJECT_STATUS_IN_PROGRESS`（default: `In Progress`）
- `GH_PROJECT_STATUS_REVIEW`（default: `In Review`）
- `GH_PROJECT_STATUS_DONE`（default: `Done`）

### 3) Repository Secret（Project同期を使う場合のみ・推奨）
`Settings > Secrets and variables > Actions > Secrets`:

- `GH_PROJECT_AUTOMATION_TOKEN`（推奨）
  - 権限: Project V2を更新できる権限（classic PATなら `repo` + `project`）
  - 未設定時は `GITHUB_TOKEN` を使うが、Project権限不足で更新失敗する場合がある

## 運用ルール（実務）
- 1 Issue = 1 Agent = 1 Branch
- Issue は `Agent Task` テンプレートで作成
- PR本文に必ず `Closes #<issue-number>` を書く
- ドラフトPR: `status:in-progress`、Ready for review: `status:review`、Merge: `status:done`

## 最短スタート（Project V2なし）
1. Actions で `Setup Labels` を1回実行
2. `Agent Task` テンプレートでIssue作成
3. PR本文に `Closes #<issue-number>` を書いてPR作成
4. 以降はPR自動作成・ラベル・Issueコメント・status更新が自動で動く

この運用だけでも「誰がどのIssueをどこまで進めたか」は追跡可能。

## Agent Teamsとの関係
- GitHub Actionsは「Issue/PR/CI/マージ」の自動化を担当。
- Claude Code Agent Teams（Lead + Teammates）は「実装作業」の並列化を担当。
- Agent Teams自体をGitHub Actions上で直接実行する構成は想定しない（対話的セッションのため）。

## 現時点の制限
- `agent:*` ラベルは Issueフォームの選択値に依存（フォームを使わないIssueでは自動付与されない）
- Project V2 の列名がデフォルトと異なる場合は Variables の調整が必要

## 動作確認チェック
1. Issue を `Agent Task` で作る
2. ブランチを切って PR 作成（`Closes #<Issue番号>` を記載）
3. PR に `lane:*` と `status:*` が付く
4. Project V2 に項目が追加され、Statusが更新される
5. Ready for review / Merge 時に Issue へ自動コメントが付く
