# Claude Code Agent Teams 運用手順（Memora）

## 概要
- Agent Teams は Claude Code の実験機能。
- Lead（PM役）+ Teammates（実装担当）で並列開発を進める。
- Memora では `1 Issue = 1 Agent = 1 Branch` を必須ルールにする。

## 前提確認
1. Claude Code バージョン確認
```bash
claude --version
```
- `2.1.32+` が必要（現在この環境は `2.1.80`）。

2. 有効化設定（このリポジトリでは設定済み）
- `.claude/settings.json`
  - `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`
  - `teammateMode = "in-process"`

3. Claude Code セッションを再起動

## 最短の起動方法
1. EpicをGitHubで作成（`Epic / PM Breakdown` テンプレート）
2. Claude Codeで以下を実行
```text
/team-kickoff <Epic内容 or Epic Issueリンク>
```
3. Leadがタスク分解と割り当てを提示する
4. 合意後、Leadに「その割り当てで実行開始して」と指示

## Leadへの推奨プロンプト
```text
Create a team with 3 teammates to implement this epic in parallel.
You are the lead. Break work into issue-sized tasks, assign one teammate per task,
and wait for teammates to finish before final integration.
```

## 運用ルール（重要）
- Teammateに重複ファイルを触らせない
- PR本文に `Closes #<issue-number>` を必ず書く
- Draft中は `status:in-progress`、Review可能で `status:review`、mergeで `status:done`
- Leadは定期的に各Teammateの進捗を回収して再配分する
- ブランチ push 時のPR作成とラベル同期は GitHub Actions が自動実行する

## 進捗が見えないとき
- in-process modeでは、画面上にTeammateが見えにくい場合がある
- `Shift+Down` でアクティブなTeammateを巡回して状態確認する

## うまくいかない時の対処
- Teamが作られない: タスクが小さすぎる可能性があるので、より大きい目標で依頼
- Leadが自分で実装し始める: 「Teammateの完了を待って統合に徹して」と明示
- タスク詰まり: `pm-assign` で再分解・再アサイン

## 補助コマンド
- Epic分解: `/pm-breakdown <要望>`
- 再アサイン: `/pm-assign <現状>`
- Team起動: `/team-kickoff <Epic内容>`

## 参考
- Agent Teams docs: https://code.claude.com/docs/en/agent-teams
- Settings docs: https://code.claude.com/docs/en/settings
