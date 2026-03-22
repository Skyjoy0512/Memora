# PMエージェント運用手順（Claude Code）

## これは何か
- Claude Code の標準機能である「カスタムサブエージェント」を使って、
  EpicをIssueに分解し、Lane/Agentを割り当てる運用。
- 専用のPMエージェントは標準搭載ではないため、プロジェクト側で定義して使う。

## 追加済みファイル
- `.claude/agents/pm-orchestrator.md`
- `.claude/commands/pm-breakdown.md`
- `.claude/commands/pm-assign.md`
- `.github/ISSUE_TEMPLATE/epic.yml`
- `scripts/pm/create_issues_from_plan.sh`

## 使い方

### 1) Epicを作る
- GitHubで `Epic / PM Breakdown` テンプレートを使ってIssue作成

### 2) PMエージェントで分解する
Claude Code で以下を実行:

```text
/pm-breakdown <Epicの本文またはIssueリンク>
```

出力として、Issue一覧と「GitHub登録用 JSON」が生成される。

### 3) JSONからIssueを一括作成する（任意）
1. PMエージェントが出した JSON を `tmp/issues.json` に保存
2. 以下を実行

```bash
scripts/pm/create_issues_from_plan.sh tmp/issues.json
```

### 4) 実装運用
- 各Issueで `1 Issue = 1 Agent = 1 Branch`
- PR本文に `Closes #<issue-number>`
- 既存Workflowで status/lane/agent が自動同期
- 並列実装は `/team-kickoff <Epic内容>` で Agent Teams の Lead に委譲可能

## 再アサインしたい時

```text
/pm-assign <対象Issue一覧や現状説明>
```

PMエージェントが依存関係を見直して、担当再配置案を出す。

## 前提
- `gh auth login` 済み（Issue一括作成を使う場合）
- `jq` インストール済み（Issue一括作成を使う場合）

## 注意
- PMエージェントは提案を出す役。最終判断は人間が行う。
- 分解粒度が粗い場合は、受け入れ条件を先に明確化して再分解する。
