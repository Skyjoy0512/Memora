# Claude Code Parallel Lane Prompts

> 速度を上げたい時だけ使う。  
> 同時に 2〜3 セッション立てる場合、ファイル競合が少ない組み合わせで始める。

## Lane A — STT Reliability

```text
あなたは Memora の Claude Lane A です。
最優先文書は以下です。
1. CLAUDE.md
2. docs/Memora_Product_North_Star.md
3. docs/Memora_Speed_Plan.md

今回は Epic A — STT Reliability のみを対象にしてください。
目的は transcription crash を止めることです。

制約:
- STT 以外の機能拡張はしない
- broad rewrite 禁止
- 最小差分
- 1PRで1成果

やること:
- crash の再現条件を読む
- SpeechAnalyzer / fallback / preflight / diagnostics の安全化を進める
- 実装後、何がまだ危険かを明記する
```

## Lane B — AskAI Usable

```text
あなたは Memora の Claude Lane B です。
最優先文書は以下です。
1. CLAUDE.md
2. docs/Memora_Product_North_Star.md
3. docs/Memora_Speed_Plan.md

今回は Epic B — AskAI Usable のみを対象にしてください。
目的は file / project / global の AskAI を product として成立させることです。

制約:
- STT コアは触らない
- broad rewrite 禁止
- AskAIView に責務を抱え込ませない
- service 中心で進める

やること:
- retrieval / context build を service 化する
- transcript / summary / memo / photo OCR / todo を扱えるようにする
- 回答に使った context が追える構造にする
```

## Lane C — Personal Memory + Task Decomposition

```text
あなたは Memora の Claude Lane C です。
最優先文書は以下です。
1. CLAUDE.md
2. docs/Memora_Product_North_Star.md
3. docs/Memora_Speed_Plan.md

今回は Epic C — Personal Memory + Task Decomposition のみを対象にしてください。
目的は AskAI が使うほどパーソナライズされ、AI がタスクを分解できるようにすることです。

制約:
- Epic B の土台を前提にする
- broad rewrite 禁止
- app-owned memory を採用する
- 外部の ChatGPT memory 前提で設計しない

やること:
- personal memory model / service を整える
- output preference や task granularity を記録できるようにする
- AI task decomposition を Todo に繋ぐ
```

## 併走のおすすめ

- まずは **Lane A だけ** 開始
- Lane A が落ち着いたら **Lane B** を開始
- Lane B の service 形が見えたら **Lane C** を開始

## 併走しない方がいい組み合わせ

- Lane A と、STT / PipelineCoordinator / TranscriptionEngine を触る別セッション
- Lane B と、AskAIView / Knowledge 系を広く触る別セッション
- Lane C と、同じ memory/todo 周りを触る別セッション
