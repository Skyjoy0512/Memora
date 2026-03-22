# Memora 開発指示プロンプト

## 概要

Claude Code をメインとして、Windows 側と macOS 側の両方で使用できるように、統一された指示プロンプトを作成します。

## 基本原則

### 1. プロジェクトコンテキストの明確化
- **アプリ名**: Memora
- **目的**: iPhone 向けの議事録・文字起こし・要約アプリ
- **開発方針**: iOS First, SwiftUI Center, シンプルで保守しやすい構成
- **技術スタック**: Swift 6, Strict Concurrency, TCA 1.17+

### 2. 役割分担の明確化
- **Windows 側**: 設計・設計・ドキュメント管理
- **macOS 側**: 実装・テスト・デバッグ
- **共通**: GitHub 管理

### 3. 統一されたルール
- **言語**: すべての回答は日本語
- **コミュニケーション**: 定期的な同期を取る
- **コード品質**: ベストプラクティスへの従う

## 指示プロンプトの構造

### システムレベルの指示

```markdown
# Memora 開発システムプロンプト

## 基本ルール
- あなたは Memora iOS アプリの開発アシスタントです
- すべての回答は日本語で行ってください
- 技術的な用語はできるだけわかりやすく説明する
- 実装前に、何をするかを日本語で短く整理する
- iOS First / SwiftUI を優先
- TCA アーキテクチャに従う
- コードの変更は最小限に

## 開発フェーズ

### フェーズ 1: プロジェクト初期化
- プロジェクトの作成方法を指示
- TCA 依存の追加
- 基本ディレクトリ構成の作成

### フェーズ 2: 実装
- 各ファイルの実装指示
- テストの実施指示
- ドキュメントの更新

## Windows 側での使用

### 開発方法
1. `claude [prompt]` コマンドで指示プロンプトを適用
2. `claude --help` で使用可能なコマンドの確認
3. �画・設計時に明示的に指示を追加

## macOS 側での使用

### 開発方法
1. 直接のコード編集
2. Xcode プロジェクトでの実装・テスト
3. ファイルのコミット・プッシュ

## コミュニケーション

### 定期的な同期
1. macOS 側で実装完了後の GitHub へのプッシュ
2. Windows 側で最新の変更をプル
3. 定期的な進捗確認

## 品告・問題解決

### エラー発生時の対応
- 具体的なエラーメッセージを共有
- 再現手順の記録
- 次のアクションを明確に

## コード品質の維持

### テスト
- 実装前のテスト計画
- テスト実施時の手順を明確に
```

### プロジェクトファイルの指示

#### Core/Models/
```markdown
# Core/Models/ での実装指示

## AudioFile.swift

# 指示
- @Model クラスとして定義してください
- 必須フィールド: id, title, recordedAt, durationSec, localPath, sourceType
- 関係: transcript, meetingNote, attachments, jobs
- 初期化時: createdAt を現在時刻に設定
- SwiftData との互換性を保ってください

## Project.swift

# 指示
- @Model クラスとして定義してください
- 必須フィールド: id, title, descriptionText
- 関係: files
- 初期化時: createdAt を現在時刻に設定
- SwiftData との互換性を保ってください

## TodoItem.swift

# 指示
- @Model クラスとして定義してください
- 必須フィールド: id, title, isCompleted
- オプションフィールド: sourceFileId, projectId, assigneeLabel, dueDate
- 初期化時: createdAt を現在時刻に設定
- SwiftData との互換性を保ってください
```

### Core/Persistence/
```markdown
# Core/Persistence/での実装指示

## SwiftDataStack.swift

# 指示
- ModelContainer を初期化するシングルトンを実装してください
- 3つのモデル（AudioFile, Project, TodoItem）を登録してください
- エラーハンドリング: fatalError でクラッシュさせず、ログ出力を行う
- @Model デコレータを使用して環境を渡す構成にしてください
- 初期化時の SwiftData.Context の取得方法を明確にしてください

## AudioFileRepository.swift

# 指示
- Repository プロトコルを定義してください
- fetchAll(), fetch(id:), save(), delete(), deleteAll() メソッドを実装してください
- 非同期処理: async/await を適切に使用
- エラーハンドリング: 適切なエラーメッセージを投げる
- TCA の DependencyKey を登録して、依存注入を可能にしてください

## DesignSystem/Theme/
```markdown
# DesignSystem/Theme/ での実装指示

## Colors.swift

# 指示
- MemoraColor enum を定義してください
- ライトモード用カラーのみを実装してください
- Backgrounds, Text, Accents, Dividers, Shadows をカテゴライズしてください
- Color(hex:) イニシャライザメソッドを実装してください
- 16進数カラーコードを扱ってください

## Typography.swift

# 指示
- MemoraTypography enum を定義してください
- iOS システムフォントを使用してください
- スタイル: largeTitle, title1, title2, title3, headline, body, callout, subheadline, footnote, caption1, caption2
- フォントウェイトを適切に設定してください
```

## DesignSystem/Components/
```markdown
# DesignSystem/Components/での実装指示

## LiquidGlassModifier.swift

# 指示
- ViewModifier プロトコルに準拠してください
- パラメータ: cornerRadius, opacity, shadowRadius を設定可能にしてください
- 3層構造（背景ブラー + 半透明オーバーレイ + ストローク）を実現してください
- .liquidGlass() 拡張メソッドを実装してください

## EmptyStateView.swift

# 指示
- SwiftUI View として実装してください
- パラメータ: icon, title, description, actionTitle, action を受け取るクロージャー
- レイアウト: 縦方向に配置
- アクションボタン: 必要に応じて実行される処理

## Features/Files/FilesList/
```markdown
# Features/Files/FilesList/での実装指示

## FilesListReducer.swift

# 指示
- @Reducer 構造を実装してください
- State, Action, body を定義してください
- State: files, isLoading, errorMessage
- Action: onAppear, filesLoaded, deleteFile, errorOccurred
- body: Reduce でアクションを処理してください
- Effect: .run { send in } で非同期処理を実装してください
- DependencyKey を登録して、audioFileRepository の依存注入を有効にしてください

## FilesListView.swift

# 指示
- WithViewStore を使用して Reducer と接続してください
- List ビューを実装してください
- 空の状態: EmptyStateView を表示
- ローディング中: ProgressView を表示
- エラー時: ToastView を表示
- List は ForEach を使用して実装してください

## FilesRowView.swift

# 指示
- WithViewStore を使用して Row データを受け取ってください
- liquidGlass を適用したカードデザインを実装してください
- レイアウト: アイコン、タイトル、日付、所要時間を左配置
- 中央: タイトルとサマリーを中央配置
- 右: チェックマークとサマリーを右配置

## Features/Files/Recording/
```markdown
# Features/Files/Recording/での実装指示

## RecordingReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: isRecording, elapsedTime, errorMessage
- Action: toggleRecording, stopRecording
- body: Reduce で録音の開始・停止を処理してください
- Effect: Timer を使用して経過時間を更新してください

## RecordingView.swift

# 指示
- WithViewStore を使用して Reducer と接続してください
- 全画面モーダルとして実装してください
- 経過時間を大きく表示
- 録音開始/停止ボタンを実装してください
- 波形ビジュアライザー（モック）を表示
- liquidGlass を適用したカードデザインを実装してください

## Features/Files/Import/
```markdown
# Features/Files/Import/での実装指示

## ImportReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: selectedFile, importState
- Action: fileSelected, importCompleted
- body: Reduce でファイル選択・インポートを処理してください
```

## Features/Files/Projects/
```markdown
# Features/Files/Projects/での実装指示

## ProjectsListReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: projects, isLoading, errorMessage
- Action: onAppear, projectsLoaded, createProject, deleteProject
- body: Reduce でプロジェクト管理を処理してください
```

## Features/Files/Projects/ProjectDetail/
```markdown
# Features/Files/Projects/ProjectDetail/での実装指示

## ProjectDetailReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: selectedProject, isEditing, projectDetails
- Action: projectSelected, toggleEditing, saveProject, deleteProject
- body: Reduce でプロジェクト詳細の編集を処理してください
```

## Features/Todo/
```markdown
# Features/Todo/での実装指示

## TodoListReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: todos, isLoading, errorMessage
- Action: onAppear, todosLoaded, createTodo, toggleTodo, deleteTodo
- body: Reduce で ToDo 管理を処理してください
```

## Features/AskAI/
```markdown
# Features/AskAI/での実装指示

## AskAIReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: chatHistory, isLoading, errorMessage
- Action: onAppear, messageSent, messageReceived
- body: Reduce で AI チャットを処理してください
```

## Features/Settings/
```markdown
# Features/Settings/での実装指示

## SettingsReducer.swift

# 指示
- @Reducer 構造を実装してください
- State: settings, isSaving
- Action: onAppear, settingChanged
- body: Reduce で設定管理を処理してください
```

## App/AppReducer.swift
```markdown
# App/AppReducer.swift での実装指示

# 指示
- @Reducer 構造を実装してください
- State: filesList, recording, selectedTab
- Action: filesList, recording, selectTab
- body: Reduce でルート管理を処理してください

## App/MemoraApp.swift
```markdown
# App/MemoraApp.swift での実装指示

# 指示
- @main 構造体でアプリのエントリーポイントを実装してください
- ModelContainer を初期化して環境に渡す構成にしてください
- TabView を追加して基本ナビゲーションを構築してください
- Files タブをデフォルト選択にしてください

## テスト戦略

### 単体テスト
- Repository レベルのテスト
- Service レベルのテスト
- UI コンポーネントのテスト
- 統合テスト

### エラー処理
- 統一されたエラーハンドリング
- 適切なエラーメッセージ
- ユーザーフレンドリーな報告

## ドキュメント更新
- 実装完了後のドキュメントを更新
- 問題・解決の記録
```

## 使用方法

### Windows 側での使用
```bash
# Memora プロジェクトで Claude Code を使用
cd C:/Users/KENICHI HASHIMOTO/OneDrive/デスクトップ/Memora
claude --prompt "FilesListReducer を実装して"

# ドキュメントの参照
claude --prompt # see docs/claude/prompts/development.md
```

### macOS 側での使用
```bash
# Xcode での作業
claude --prompt "FilesListReducer を実装して"

# プロジェクトの確認
claude --prompt "現在の FilesListReducer の実装状況を確認して"
```

## 注意点

- **明確な指示**: どの環境で何をするかを常に明確にする
- **段階的な指示**: 大きな機能は複数の小さな指示に分ける
- **フィードバック**: 定期的に進捗状況を確認して、指示の調整
- **エラー対処**: エラーが発生したら適切な対処を行う

## 次のステップ

1. **プロンプトの作成**: この指示プロンプトを `.claude/prompts/development.md` に保存
2. **テスト**: Windows 側で指示プロンプトのテスト
3. **展開**: macOS 側での開発開始
