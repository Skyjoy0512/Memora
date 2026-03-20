# TCA 移行タスクリスト

## Claude D による基盤実装（完了済み）

### Models
- ✅ AudioFile.swift - 仕様準拠修正
- ✅ Transcript.swift - 仕様準拠修正
- ✅ Project.swift - 仕様準拠修正
- ✅ MeetingNote.swift - 新規作成
- ✅ TodoItem.swift - 新規作成
- ✅ Attachment.swift - 新規作成
- ✅ ProcessingJob.swift - 新規作成
- ✅ ProcessingChunk.swift - 新規作成
- ✅ ChatScope.swift - 新規作成

### Persistence
- ✅ SwiftDataStack.swift - ModelContainer 管理
- ✅ AudioFileRepository.swift
- ✅ TranscriptRepository.swift
- ✅ MeetingNoteRepository.swift
- ✅ ProjectRepository.swift
- ✅ TodoRepository.swift
- ✅ AttachmentRepository.swift
- ✅ JobRepository.swift

### Dependencies
- ✅ DependencyKey+Memora.swift - TCA 依存注入

### Utilities
- ✅ FileManager+Memora.swift
- ✅ Duration+Format.swift
- ✅ DateFormatter+Memora.swift
- ✅ Logger+Memora.swift

### App
- ✅ MemoraApp.swift - TCA AppReducer 統合
- ✅ ContentView.swift - 削除（MemoraApp に統合）

---

## Xcode での必要な作業

### 1. Swift Package Manager で TCA を追加

```
パッケージ URL: https://github.com/pointfreeco/swift-composable-architecture.git
バージョン: 1.17.0 以上
```

**手順:**
1. Xcode で Memora.xcodeproj を開く
2. File > Add Package Dependencies
3. 上記 URL を入力
4. Next > Next > Add Package

### 2. 新規ファイルをプロジェクトに追加

以下のファイルを Xcode プロジェクトに追加（ドラッグ＆ドロップ）：

```
Memora/Core/Models/MeetingNote.swift
Memora/Core/Models/TodoItem.swift
Memora/Core/Models/Attachment.swift
Memora/Core/Models/ProcessingJob.swift
Memora/Core/Models/ProcessingChunk.swift
Memora/Core/Models/ChatScope.swift
Memora/Core/Persistence/SwiftDataStack.swift
Memora/Core/Persistence/AudioFileRepository.swift
Memora/Core/Persistence/TranscriptRepository.swift
Memora/Core/Persistence/MeetingNoteRepository.swift
Memora/Core/Persistence/ProjectRepository.swift
Memora/Core/Persistence/TodoRepository.swift
Memora/Core/Persistence/AttachmentRepository.swift
Memora/Core/Persistence/JobRepository.swift
Memora/Core/Dependencies/DependencyKey+Memora.swift
Memora/Core/Utilities/FileManager+Memora.swift
Memora/Core/Utilities/Duration+Format.swift
Memora/Core/Utilities/DateFormatter+Memora.swift
Memora/Core/Utilities/Logger+Memora.swift
```

**注意:**
- Targets: Memora にチェックを入れる
- Copy items if needed: Create groups を選択

### 3. ビルドエラーの確認

`Cmd+B` でビルドし、エラーがないことを確認。

---

## 次のステップ（各エージェント）

### Claude A (Files / Recording / Import)
TCA Reducer と View を実装し、Dependency を使用する：
- FilesListReducer, FilesListView, FilesRowView
- RecordingReducer, RecordingView
- ImportReducer, ImportView

### Claude C (Projects / Todo / AskAI / Settings)
TCA Reducer と View を実装し、Dependency を使用する：
- ProjectsListReducer, ProjectsListView, ProjectsRowView
- ProjectDetailReducer, ProjectDetailView
- TodoListReducer, TodoListView, TodoRowView, TodoEditSheet
- AskAIReducer, AskAIView, ChatBubbleView, SuggestionCardView
- SettingsReducer, SettingsView, 各Section

### Claude D (継続)
未実装のサービスを実装：
- LLMRouter + LLMProviders
- PipelineCoordinator
- DecisionExtractor
- TodoExtractor

---

## 仕様書との差分（要確認）

### 未実装の Model プロパティ
- AudioFile に `localPath` で保存済みだが、仕様ではフルパスではなく相対パス
- `FileManager+Memora` で `audioDirectory` をベースパスとして使用する設計

### 依存関係
- PipelineCoordinator は未実装（プレースホルダー）
- LLMRouter は未実装（プレースホルダー）
- エージェント A が Feature を実装する前に、これらのプレースホルダーを実際の実装に置き換える必要あり

### 注意点
- AudioRecorder / AudioPlayer / TranscriptionEngine は Protocol 経由で Dependency 注入されるが、実装は現在のまま使用
- SummarizationEngine は将来 LLMRouter に統合される
- AIService は LLMRouter に置き換えられる
