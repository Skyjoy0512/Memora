# Memora - 開発タスク（2026-03-31 更新）

> **仕様書**: `Memora仕様書.txt`（2790行 / TASK-001〜037）
> **現状**: TCA を廃止し SwiftUI + SwiftData + MVVM に移行済み。仕様書の TASK 分割は TCA 前提だが、機能要件は同じ。

---

## 仕様書との乖離サマリ

| 分類 | 仕様書にある | 実装済 | 未実装 |
|------|-------------|--------|--------|
| **DesignSystem/** | Colors, Typography, Spacing, LiquidGlass, Theme | ❌ なし | 全トークン未実装。View ごとにハードコード |
| **共通コンポーネント** | FABMenu, ToastOverlay, EmptyStateView, SkeletonView, PillButton, LiveRecordingBanner | ❌ 一部（BottomFloatingBar のみ） | 5コンポーネント未実装 |
| **Onboarding** | 4ページのページング | ❌ なし | 未着手 |
| **Auth** | Sign in with Apple + Google | ❌ なし | 未着手 |
| **Paywall** | StoreKit 2 月額/年額 | ❌ なし | 未着手 |
| **Repository 層** | 全エンティティの Repository パターン | ⚠️ 一部（9リポジトリ追加済み、View統合未完了） | View の @Query → Repository 置換が未完了 |
| **LLMRouter** | 複数 Provider（Local, OpenAI, Claude, Gemini, DeepSeek） | ❌ なし（AIService プレースホルダのみ） | 未着手 |
| **PipelineCoordinator** | 文字起こし→要約→決定抽出→ToDo抽出 | ⚠️ 一部（基礎実装あり、チャンクリトライ未実装） | ステップ完了、リトライ・UI連携未実装 |
| **GenerationFlowSheet** | 方式→テンプレート→モデル選択 | ❌ なし | 未着手 |
| **Ask AI** | チャット UI + スコープ別コンテキスト | ❌ なし | 未着手 |
| **Import** | ドキュメントピッカー | ❌ なし | 未着手 |
| **AdService** | バナー + インタースティシャル | ❌ なし | 未着手 |
| **APIKeyStore** | Keychain 管理 | ❌ なし | 未着手 |
| **テスト** | Unit + Snapshot | ⚠️ 一部（Model/Repository/ViewModel テストあり） | Snapshot テスト・カバレッジ拡大が必要 |

---

## 完了済み（仕様書対応）

| TASK | 内容 | 備考 |
|------|------|------|
| TASK-001（一部） | プロジェクト初期構成 | TCA は後に除去 |
| TASK-004（一部） | SwiftData モデル定義 | AudioFile, Project, TodoItem, Transcript, MeetingNote, ProcessingJob あり。Attachment, ProcessingChunk, ChatScope 未確認 |
| TASK-010 | AudioRecorder サービス | AVFoundation 実装済 |
| TASK-011（一部） | 録音画面 | RecordingView あり、Reducer なし |
| TASK-014 | AudioPlayer サービス | 実装済 |
| TASK-016（一部） | TranscriptionEngine | SpeechAnalyzer + SFSpeechRecognizer 実装済 |
| TASK-017 | AudioChunker | 実装済 |
| TASK-026（一部） | Project 一覧画面 | ProjectsView あり、Reducer なし |

### その他完了
- CI/CD（GitHub Actions）
- Omi/Plaud デバイス連携基礎
- CBUUID 修正によるクラッシュ解決
- スタートアップリカバリ強化
- Repository 層基礎（PR #21, 2026-03-29）
- PipelineCoordinator 基礎（PR #22, 2026-03-29）
- FileDetailViewModel 抽出（PR #23, 2026-03-29）
- Settings Plaud/Bluetooth UI（PR #24, 2026-03-29）
- Xcode プロジェクト設定更新（PR #25, 2026-03-29）
- ユニットテスト基盤（PR #26, 2026-03-29）

---

## WIP

### feat/phase1-core-stabilization（PR #27 OPEN）
- [x] PipelineCoordinator の currentStep 追加（エラー報告改善）

### Open PR
- PR #27: PipelineCoordinator エラー報告改善（feat/phase1-core-stabilization）
- PR #15: Task automation workflows（feat/11-task-automation）— CI ワークフロー整備

### Closed PR（参考）
- PR #17/#18: STT進捗表示（CLOSED）
- PR #20: Summary persistence（MERGED）

---

## P0 — デザインシステム + アーキテクチャ基盤（TASK-002, 003, 005）

### TASK-002: デザインシステム基盤
- [ ] `DesignSystem/Colors.swift` — MemoraColor トークン定義
- [ ] `DesignSystem/Typography.swift` — MemoraTypography トークン定義
- [ ] `DesignSystem/Theme.swift` — MemoraSpacing + テーマ統合
- [ ] `DesignSystem/Components/LiquidGlassModifier.swift` — 3層ブラー + オーバーレイ + ストローク
- [ ] 既存 View のハードコード値をトークン参照に置換

### TASK-003: 共通 UI コンポーネント
- [ ] FABMenu — 扇状展開アニメーション（spring 0.35/0.75）
- [ ] ToastOverlay — 上部下降バナー、4秒自動消去
- [ ] EmptyStateView — アイコン + タイトル + 説明 + ボタン
- [ ] SkeletonView — shimmer アニメーション
- [ ] PillButton — pill 形状のボタン
- [ ] LiveRecordingBanner — 赤ドット点滅 + 経過時間 + 波形

### TASK-005: Repository 層（PR #21 で基礎実装済み）
- [x] AudioFileRepository（protocol + SwiftData 実装）
- [x] TranscriptRepository
- [x] MeetingNoteRepository
- [x] ProjectRepository
- [x] TodoItemRepository
- [x] PlaudSettingsRepository
- [x] ProcessingJobRepository
- [x] WebhookSettingsRepository
- [x] RepositoryFactory（DI コンテナ）
- [ ] AttachmentRepository
- [ ] 各 View の @Query を Repository 経由に変更

---

## P1 — コア機能完成（TASK-006〜022）

### TASK-006: AppReducer + タブ構成
- [ ] ContentView のフロー管理（オンボーディング → 認証 → タブ）
- [ ] BottomFloatingBar の仕様書仕様への適合

### TASK-007: オンボーディング
- [ ] 4ページのページングスクロール（TabView + .page）
- [ ] 各ページのイラスト + タイトル + 説明
- [ ] 「次へ」「始める」ボタン

### TASK-008: 認証
- [ ] AuthService（Sign in with Apple + Google）
- [ ] AuthView（ロゴ + ボタン2つ + 利用規約リンク）

### TASK-009: Paywall
- [ ] SubscriptionService（StoreKit 2）
- [ ] PaywallView（機能比較 + プラン選択 + 購入ボタン）

### TASK-012: インポート機能
- [ ] ImportView（UIDocumentPickerViewController ラップ）
- [ ] ファイルコピー + AudioFile エンティティ生成

### TASK-013: Files 一覧画面（仕様適合）
- [ ] FilesRowView の仕様書レイアウト適合（タイトル/日時/サマリー行）
- [ ] LiveRecordingBanner 統合
- [ ] FABMenu 統合
- [ ] sparkle アイコン追加
- [ ] コンテキストメニュー（名前変更/Project追加/共有/削除）
- [ ] EmptyStateView 統合

### TASK-015: ファイル詳細画面（仕様適合）
- [ ] AudioPlayerView の仕様書デザイン適合
- [ ] Upload image ボタン（アウトライン + カメラアイコン）
- [ ] 「議事録を生成」導線

### TASK-018: LLMRouter + LocalProvider
- [ ] LLMProviderProtocol 定義
- [ ] LocalLLMProvider（Apple Foundation Models）
- [ ] SummarizationEngine 本実装

### TASK-019: PipelineCoordinator（PR #22 で基礎実装済み）
- [x] 文字起こし → 要約 → 決定抽出 → ToDo抽出のパイプライン基礎
- [x] currentStep 追加による正確なエラー報告（PR #27）
- [ ] ProcessingJob / ProcessingChunk の状態管理
- [ ] チャンク単位のリトライ（指数バックオフ）

### TASK-020: 生成フロー UI
- [ ] GenerationFlowSheet（方式 → テンプレート → モデル選択）
- [ ] SkeletonView 統合（ステップ名表示付き）

### TASK-021: 生成結果表示
- [ ] FileDetailView のフルレイアウト（Player → 画像 → Summary → Decisions → Actions → Transcript冒頭 → Ask AI 入力欄）
- [ ] TranscriptView 全文画面の仕様適合（話者セグメント表示）

### TASK-022: 失敗トースト統合
- [ ] PipelineCoordinator エラー → ToastOverlay 表示

---

## P2 — 拡張機能（TASK-023〜033）

### TASK-023: 添付ファイル
- [ ] 画像/PDF 保存・プレビュー
- [ ] AttachmentGalleryView（80x80 横スクロールサムネイル）

### TASK-024: ToDo 抽出統合
- [ ] PipelineCoordinator の ToDo 抽出ステップ
- [ ] TodoRepository への自動保存

### TASK-025: ToDo 画面
- [ ] TodoListView（未完了/完了済みセクション分割）
- [ ] TodoRowView（チェック + タイトル + 出典 + 期限）
- [ ] TodoEditSheet（タイトル/担当者/期限/出典）

### TASK-026/027: Projects 画面（仕様適合）
- [ ] ProjectsRowView の仕様書レイアウト適合
- [ ] ProjectDetailView（ファイル追加シート + Ask AI 導線）

### TASK-028/029: Ask AI
- [ ] AskAIView（スコープ別コンテキスト）
- [ ] ChatBubbleView（ユーザー右/AI 左）
- [ ] SuggestionCardView（2x2 グリッド）
- [ ] 入力欄（liquidGlass + 添付 + モデル切替 + 音声入力 + 送信）

### TASK-030: 外部 LLM Provider
- [ ] OpenAIProvider
- [ ] AnthropicProvider
- [ ] GeminiProvider
- [ ] DeepSeekProvider

### TASK-031: モデル切替 UI
- [ ] ファイル詳細のモデル選択シート
- [ ] Ask AI 入力欄のモデル切替チップ
- [ ] Free ユーザーのロック表示

### TASK-032: 使用回数制限
- [ ] 無料ユーザー向け LLM 使用回数カウント・制限

### TASK-033: 広告表示
- [ ] AdService（Google Mobile Ads）
- [ ] Files 一覧バナー（50pt / safeAreaInset）
- [ ] 生成後インタースティシャル

---

## P3 — 将来構想（TASK-034〜037）

### TASK-034: APIキー管理 UI
- [ ] Settings の APIKeySection（SecureField + Keychain）

### TASK-035: クラウド保存
- [ ] iCloud 同期設計

### TASK-036: PLAUD 接続状態管理
- [ ] Bluetooth 状態表示

### TASK-037: 外部サービス連携
- [ ] Slack / Notion / Google Docs 連携設計

---

## 現在の仕様書からの主要な「方針違い」

| 項目 | 仕様書 | 実際の実装 |
|------|--------|-----------|
| アーキテクチャ | TCA (Reducer) | SwiftUI + SwiftData (MVVM) |
| デザイントークン | DesignSystem/ で一元管理 | 各 View にハードコード |
| データアクセス | Repository パターン | @Query を View に直書き |
| Liquid Glass | 独自3層モディファイア | .glassEffect()（iOS 26 API）使用 |
| iOS target | 18+ | 17+ |

> **注意**: 仕様書は TCA 前提で書かれているが、TCA は既に除去済み。
> 機能要件（画面仕様・データモデル・サービス仕様）はそのまま参考にでき、
> Reducer 部分は ViewModel に読み替えて実装する。

---

## 優先順位の考え方

| 優先度 | 目標 | 対象 TASK |
|--------|------|-----------|
| **P0** | デザインシステム + Repository 基盤の確立 | 002, 003, 005 |
| **P1** | コア機能（生成パイプライン + 画面仕様適合） | 006〜022 |
| **P2** | 拡張機能（Ask AI, ToDo, Projects, 広告） | 023〜033 |
| **P3** | 将来構想（APIキー, クラウド, 外部連携） | 034〜037 |
