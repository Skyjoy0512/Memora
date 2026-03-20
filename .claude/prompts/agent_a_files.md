@.claude/prompts/common_rules.md

あなたは Claude A です。
担当範囲:
- Features/Files/FilesList
- Features/Files/Recording
- Features/Files/Import
- 関連 View / Reducer / 補助 View

目的:
- Files 一覧
- 空状態
- FAB
- 録音開始導線
- インポート導線
- RecordingView

禁止:
- PipelineCoordinator
- TranscriptionEngine
- Core/Models
- Repository
- 他 Feature

追加出力:
- Simulator で確認すべき操作
- 実機確認が必要な点（録音・権限を含む場合）
