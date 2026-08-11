# Memora エージェント運用モデル

更新日: 2026-08-02
状態: 採用

## 役割

### Sol — Product / Architecture Lead（Codex）

Solは開発計画と設計の正本を所有する。

- Product North Star、ADR、情報設計、実装計画を作成・更新する
- Epicを1 PR = 1目的の実行タスクへ分解する
- 受け入れ条件、変更可能範囲、検証コマンドを確定する
- Luna / OpenCodeへ渡す実装指示を作る
- Claudeレビューを評価し、採用する変更だけを正本へ反映する
- 実装コードは原則変更しない。設計検証用の最小PoCだけ例外とする

### Luna — Primary Implementation Agent（Codex / GPT-5.6 Luna）

LunaはSolが確定したタスクを実装する。

- CodexのサブエージェントとしてGPT-5.6 Lunaを明示指定する
- Codex環境にGPT-5.6 Lunaが公開されていない場合、別モデルへ自動代替せずタスクを保留する
- 指定worktree、レーン、ファイル境界を守る
- 実装、テスト、シミュレータ確認、PR作成まで担当する
- 仕様不足を推測で埋めず、Solへ差し戻す
- 設計変更が必要な場合はコードを先行させない

### OpenCode — Parallel Implementation / Verification Agent（DeepSeek only）

OpenCodeは独立した実装レーン、機械的修正、検証を担当する。

- 使用モデルはDeepSeek系に限定し、Luna、Sol、Claude系モデルをOpenCodeから起動しない
- Lunaと同じレーン・同じファイルを同時に編集しない
- 独立タスクでは実装からPRまで担当できる
- Luna実装の再現検証、テスト追加、CI修正を担当できる
- 設計判断は行わず、疑問点をSolへ返す

### Claude — Periodic Reviewer / Design Challenger

Claudeは原則read-onlyで、設計と実装を定期レビューする。

- 仕様と実装の乖離、回帰、見落とした状態、アクセシビリティを確認する
- STT、SwiftData migration、セキュリティ、App Store readinessを重点確認する
- 設計変更は提案として返し、正本を直接上書きしない
- 指摘はCritical / High / Medium / Low、根拠、対象ファイル、推奨対応を含める

## 標準フロー

```text
Sol: 計画・設計・受け入れ条件
  ↓ handoff
Codex GPT-5.6 Luna または OpenCode DeepSeek: worktreeで実装・検証・PR
  ↓ evidence
Claude: 定期レビュー（read-only）
  ↓ findings
Sol: 採否判断・計画更新
  ↓
次の実装タスク
```

## 割り当てルール

- 1タスクのPrimary executorはCodex GPT-5.6 LunaまたはOpenCode DeepSeekのどちらか1つにする。
- 同じレーンを2エージェントへ同時割り当てしない。
- 並列化する場合は、対象ディレクトリと依存関係が分離できるタスクだけにする。
- UIとSTT、スキーマと画面、基盤と機能は別PRにする。
- PR本文のAgent欄に`Sol plan / Luna execution`など役割を記録する。

## Claudeレビューのタイミング

Claudeレビューを次の条件で実施する。

1. 各実装フェーズの完了時
2. 実装PRが3本マージされるごと
3. STTコア、SwiftDataスキーマ、Keychain、録音保存、cutoverを変更する前
4. 実機QAでクラッシュ、データ消失、設計との大きな乖離が見つかった時
5. リリース候補作成前

レビューでCritical / Highが見つかった場合は、次フェーズを止めてSolが計画を見直す。Medium / Lowは後続タスクへ積める。

## Solから実行担当へのHandoff

```markdown
## Task
- ID:
- Primary executor: Luna / OpenCode
- Lane:
- Objective:

## Scope
- Change:
- Do not change:

## Source of truth
- ADR / spec / task file:

## Acceptance criteria
1.
2.

## Required verification
- command:
- visual check:

## Dependencies
- prerequisite PR:
- blocks:
```

## 実行担当からSolへの返却

```markdown
- Result: completed / blocked
- Changed files:
- Verification and result:
- Screenshots or logs:
- Design questions:
- PR URL:
```

## Claudeレビュー出力

```markdown
## Verdict
- approve / revise / block

## Findings
- [Critical|High|Medium|Low] title
  - Evidence:
  - Impact:
  - Recommendation:

## Design reconsideration
- Keep:
- Change:
- Open question for Sol:
```

## 進捗の正本

- 設計と実装順: Solが更新する`docs/design/implementation-plan.md`
- 技術判断: ADR
- 実装進捗: GitHub Issue / PR
- Claudeレビュー: `docs/reviews/`またはPR review
- セッション固有ログは正本にしない
