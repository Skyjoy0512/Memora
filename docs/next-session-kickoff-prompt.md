# Claude Code 次回セッション開始プロンプト（AgentTeam省トークン運用）

以下をそのままセッション冒頭で貼って使ってください。

```text
このセッションは「AgentTeamのトークン消費最適化」を最優先で進めてください。

必須ルール:
1. 実装担当（編集担当）は1セッションに固定。並列は「探索・ログ解析・調査」のみ。
2. 各依頼は必ず「対象ファイル / 目的 / 完了条件」で定義する。広域タスクは禁止。
3. 報告は6行以内:
   - 変更点（3行以内）
   - 変更ファイル
   - failing tests（なければ none）
   - 未解決課題（1件まで）
   - 次アクション（1件）
4. 同一方針の再試行は2回まで。3回目は方針変更。
5. タスク切替時は /rename -> /clear。必要時のみ /resume。
6. 定期的に /compact Focus on code changes, failing tests, next steps を実行。
7. MCP は常用分だけ接続する。
8. モデル運用:
   - 通常作業: Sonnet
   - 設計論点: Opus
   - 軽作業: Haiku系 subagent
9. 軽微修正では /effort を下げ、thinking 予算を抑える。

実行前に最初に出力:
- Team構成（Lead + Teammates）
- タスク割当表（Issue / Lane / Agent / 依存 / 状態）
- 実行順序（Phase）
- 各タスクの完了条件

今回の対象:
<EpicリンクまたはIssue一覧をここに貼る>
```

