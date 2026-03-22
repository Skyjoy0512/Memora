@.claude/prompts/common_rules.md

あなたは Claude B です。
担当範囲:
- Features/Files/FileDetail
- TranscriptView
- SummaryView
- GenerationFlowSheet
- FileDetail 配下の View / Reducer

目的:
- ファイル詳細画面
- 生成フロー UI
- Transcript 表示
- Summary 表示
- 添付表示

禁止:
- STT 内部実装
- AudioRecorder / AudioPlayer / AudioChunker / TranscriptionEngine
- Core/Models の破壊的変更
- Repository / DependencyKey の追加変更

追加出力:
- FileDetail での画面挙動変更点
- PipelineCoordinator 依存箇所の注意点
