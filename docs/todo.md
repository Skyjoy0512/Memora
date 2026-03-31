# Memora - 開発タスク（2026-03-31 更新）

> **仕様書**: `Memora仕様書.txt`
> **アーキテクチャ**: SwiftUI + SwiftData + MVVM（TCA は除去済み）

---

## 完了済み

| TASK | 内容 |
|------|------|
| TASK-001 | プロジェクト初期構成 |
| TASK-002 | デザインシステム トークン定義 + View 適用（PR #28） |
| TASK-003 | 共通 UI コンポーネント + View 統合（PR #30） |
| TASK-004 | SwiftData モデル定義 |
| TASK-005 | Repository 層（7エンティティ）+ 全 View 移行（PR #29） |
| TASK-010 | AudioRecorder |
| TASK-011 | 録音画面 |
| TASK-014 | AudioPlayer |
| TASK-016 | TranscriptionEngine（SpeechAnalyzer + SFSpeechRecognizer） |
| TASK-017 | AudioChunker |
| TASK-019 | PipelineCoordinator（文字起こし→要約→ToDo抽出） |
| — | CI/CD, ViewModel/Model/Repository テスト, iOS 26 ガード |

## Open PR（レビュー待ち）

| PR | 内容 |
|----|------|
| #15 | CI workflows |
| #27 | PipelineCoordinator 安定化 |
| #28 | デザイントークン化 |
| #29 | Repository 移行（全View） |
| #30 | 共通UIコンポーネント統合 |

---

## P1 — コア機能（次にやる）

### TASK-012: インポート
- [ ] UIDocumentPickerViewController ラップ
- [ ] ファイルコピー + AudioFile エンティティ生成
- [ ] HomeView FAB「インポート」ボタンに接続

### TASK-013: Files 一覧画面 仕様適合
- [ ] FilesRowView レイアウト（タイトル/日時/サマリー行）
- [ ] LiveRecordingBanner / FABMenu 統合（済み）
- [ ] コンテキストメニュー（名前変更/Project追加/共有/削除）
- [ ] EmptyStateView 統合（済み）

### TASK-015: ファイル詳細画面 仕様適合
- [ ] AudioPlayerView 仕様書デザイン適合
- [ ] Upload image ボタン
- [ ] 「議事録を生成」導線

### TASK-018: LLMRouter + Provider 本実装
- [ ] LLMProviderProtocol 定義
- [ ] OpenAIProvider（gpt-4o / gpt-4o-mini）
- [ ] GeminiProvider（gemini-2.0-flash）
- [ ] DeepSeekProvider（deepseek-chat）
- [ ] LocalProvider（Apple Foundation Models）
- [ ] SummarizationEngine のプロンプト最適化

### TASK-020: 生成フロー UI 仕様適合
- [ ] GenerationFlowSheet（方式→テンプレート→モデル選択）
- [ ] SkeletonView 統合（済み）

### TASK-021: 生成結果表示 仕様適合
- [ ] FileDetailView フルレイアウト（Player→画像→Summary→Decisions→Actions→Transcript→Ask AI）
- [ ] TranscriptView 全文画面（話者セグメント表示）

### TASK-022: エラー表示
- [ ] ToastOverlay でエラー表示（済み）

---

## P2 — 拡張機能

### TASK-006: タブ構成
- [ ] ContentView フロー管理（オンボーディング→認証→タブ）
- [ ] BottomFloatingBar 仕様適合

### TASK-007: オンボーディング
- [ ] 4ページ ページングスクロール
- [ ] 各ページ イラスト + タイトル + 説明

### TASK-008: 認証
- [ ] AuthService（Sign in with Apple + Google）

### TASK-009: Paywall
- [ ] SubscriptionService（StoreKit 2）

### TASK-024: ToDo 抽出
- [ ] PipelineCoordinator ToDo 抽出強化

### TASK-025: ToDo 画面
- [ ] TodoListView / TodoRowView / TodoEditSheet

### TASK-026/027: Projects 画面
- [ ] ProjectsRowView / ProjectDetailView 仕様適合

### TASK-028/029: Ask AI
- [ ] AskAIView / ChatBubbleView / SuggestionCardView

### TASK-030〜033: Provider UI / 制限 / 広告

---

## P3 — 将来

| TASK | 内容 |
|------|------|
| 034 | APIキー管理（Keychain） |
| 035 | iCloud 同期 |
| 036 | PLAUD Bluetooth 状態管理 |
| 037 | Slack / Notion / Google Docs 連携 |
