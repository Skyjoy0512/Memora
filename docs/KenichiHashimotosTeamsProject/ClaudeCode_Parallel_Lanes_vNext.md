# Claude Code Parallel Lane Prompts (Optional)

> これは複数の Claude セッションを並列で回すときだけ使う。  
> 単独運用なら `ClaudeCode_Kickoff_Prompt_vNext.txt` だけでよい。

---

## Lane A — STT / Reliability

```text
あなたは Memora の STT / reliability lane を担当します。
まず以下を読むこと。
1. docs/Memora_vNext_Current_Truth_and_Execution_Plan.md
2. CLAUDE.md
3. docs/transcription-core-boundary.md

current truth は docs/Memora_vNext_Current_Truth_and_Execution_Plan.md です。

あなたの担当は A 系タスクのみです。
優先順は A1 → A2 → A3 → A4。
今回は未完了の最上位 A タスク 1件だけを実装してください。

実装前に以下を宣言:
- 現状理解
- 変更するファイル
- 変更しないファイル
- 実装方針
- リスク

完了後:
- docs/Memora_vNext_Current_Truth_and_Execution_Plan.md の対象 task を更新
- 完了報告テンプレートで報告
- 次の A タスクを 1つ提案
```

---

## Lane B — iOS 26 Design

```text
あなたは Memora の design lane を担当します。
まず以下を読むこと。
1. docs/Memora_vNext_Current_Truth_and_Execution_Plan.md
2. CLAUDE.md

current truth は docs/Memora_vNext_Current_Truth_and_Execution_Plan.md です。

あなたの担当は B 系タスクのみです。
優先順は B1 → B2 → B3。
A1 が未完了でも、STT コアに触れない UI 作業だけ進めてよいです。
ただし reliability lane と競合するファイルが多い場合は着手を止めてください。

実装前に以下を宣言:
- 現状理解
- 変更するファイル
- 変更しないファイル
- 実装方針
- リスク

完了後:
- docs/Memora_vNext_Current_Truth_and_Execution_Plan.md の対象 task を更新
- 完了報告テンプレートで報告
- 次の B タスクを 1つ提案
```

---

## Lane C — Ask AI / Local LLM

```text
あなたは Memora の Ask AI / local LLM lane を担当します。
まず以下を読むこと。
1. docs/Memora_vNext_Current_Truth_and_Execution_Plan.md
2. CLAUDE.md
3. docs/transcription-core-boundary.md（STT に触る場合のみ）

current truth は docs/Memora_vNext_Current_Truth_and_Execution_Plan.md です。

あなたの担当は C 系タスクのみです。
優先順は C1 → C2 → C3 → C4。
A1/A2 が未完了の間は、STT に依存しない範囲でのみ進めてください。

実装前に以下を宣言:
- 現状理解
- 変更するファイル
- 変更しないファイル
- 実装方針
- リスク

完了後:
- docs/Memora_vNext_Current_Truth_and_Execution_Plan.md の対象 task を更新
- 完了報告テンプレートで報告
- 次の C タスクを 1つ提案
```
