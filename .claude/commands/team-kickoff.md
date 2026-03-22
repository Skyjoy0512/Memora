Agent Teams を起動して、Lead として以下を実行してください。

入力:
$ARGUMENTS

必須手順:
1. まず作業を Issue 単位（1 Issue = 1 Agent = 1 Branch）に分解する
2. 各 Issue に Lane（A-E）と担当（Codex/Claude/Pair）を割り当てる
3. 依存関係を明示して、並列実行可能なタスクから着手する
4. Teammate ごとに編集対象ファイルを分離し、衝突を避ける
5. 各タスク完了時に「変更点 / 検証結果 / 残課題」を報告させる
6. 最後にLeadが統合サマリを作成する

出力フォーマット:
- Team構成（Lead + Teammates）
- タスク割当表（Issue, Lane, Agent, 依存, 状態）
- 実行順序（Phase 1/2/...）
- 進捗報告テンプレート
