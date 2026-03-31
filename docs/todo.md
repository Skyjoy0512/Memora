# Memora - 開発タスク（2026-03-31 更新）

> **仕様書**: `Memora仕様書.txt`（2790行 / TASK-001〜037）
> **現状**: TCA を廃止し SwiftUI + SwiftData + MVVM に移行済み。仕様書の TASK 分割は TCA 前提だが、機能要件は同じ。

---

## 完了済み

| TASK | 内容 | PR |
|------|------|----|
| TASK-001（一部） | プロジェクト初期構成 | — |
| TASK-004（一部） | SwiftData モデル定義（AudioFile, Project, TodoItem, Transcript, MeetingNote, ProcessingJob） | — |
| TASK-010 | AudioRecorder サービス | — |
| TASK-011（一部） | 録音画面（RecordingView） | — |
| TASK-014 | AudioPlayer サービス | — |
| TASK-016（一部） | TranscriptionEngine（SpeechAnalyzer + SFSpeechRecognizer） | #22 |
| TASK-017 | AudioChunker | — |
| TASK-019（一部） | PipelineCoordinator（文字起こし→要約→ToDo抽出パイプライン） | #22 |
| TASK-002（一部） | デザインシステム トークン定義（MemoraColor, Typography, Spacing, Radius, Opacity, Frame, Height）＋ View のハードコード値置換 | #28 |
| TASK-005（一部） | Repository 層（AudioFile, Transcript, TodoItem, WebhookSettings, Project, MeetingNote, ProcessingJob）＋ FileDetailViewModel 移行 | #29 |
| — | CI/CD（GitHub Actions） | #15 |
| — | ViewModel/Model/Repository 単体テスト | #26 |
| — | FileDetailViewModel リファクタリング | #23 |
| — | PipelineCoordinator currentStep 追加 + CoreError 対応 | #27 |
| — | Omi/Plaud デバイス連携基礎 + Settings UI | #24 |

---

## Open PR（レビュー待ち）

| PR | ブランチ | 内容 | CI |
|----|----------|------|----|
| #15 | feat/11-task-automation | CI workflows + iOS 26 ガード | pass |
| #27 | feat/phase1-core-stabilization | PipelineCoordinator 安定化 | pass |
| #28 | feat/task-002-design-system-tokens | デザイントークン化 | pass |
| #29 | feat/task-005-repository-migration | Repository 移行 | pass |

---

## 仕様書との乖離サマリ

| 分類 | 仕様書にある | 実装済 | 未実装 |
|------|-------------|--------|--------|
| **DesignSystem/** | Colors, Typography, Spacing, LiquidGlass, Theme | ✅ トークン定義済み、View 適用済み | LiquidGlass 独自3層モディファイア、Theme 切替 |
| **共通コンポーネント** | FABMenu, ToastOverlay, EmptyStateView, SkeletonView, PillButton, LiveRecordingBanner | ❌ BottomFloatingBar のみ | 5コンポーネント未実装 |
| **Onboarding** | 4ページのページング | ❌ なし | 未着手 |
| **Auth** | Sign in with Apple + Google | ❌ なし | 未着手 |
| **Paywall** | StoreKit 2 月額/年額 | ❌ なし | 未着手 |
| **Repository 層** | 全エンティティの Repository パターン | ✅ 7エンティティ + FileDetailViewModel 適用済み | 残りの View 移行 |
| **LLMRouter** | 複数 Provider | ❌ AIService プレースホルダのみ | 未着手 |
| **GenerationFlowSheet** | 方式→テンプレート→モデル選択 | ✅ 基本実装済み | 仕様適合 |
| **Ask AI** | チャット UI + スコープ別コンテキスト | ❌ なし | 未着手 |
| **Import** | ドキュメントピッカー | ❌ なし | 未着手 |
| **AdService** | バナー + インタースティシャル | ❌ なし | 未着手 |
| **APIKeyStore** | Keychain 管理 | ❌ なし | 未着手 |
| **テスト** | Unit + Snapshot | ✅ ViewModel/Model/Repository 単体テストあり | Snapshot テスト未着手 |

---

## P0 — 残基盤（TASK-003, 005 続き）

### TASK-003: 共通 UI コンポーネント
- [ ] FABMenu — 扇状展開アニメーション（spring 0.35/0.75）
- [ ] ToastOverlay — 上部下降バナー、4秒自動消去
- [ ] EmptyStateView — アイコン + タイトル + 説明 + ボタン
- [ ] SkeletonView — shimmer アニメーション
- [ ] PillButton — pill 形状のボタン
- [ ] LiveRecordingBanner — 赤ドット点滅 + 経過時間 + 波形

### TASK-005 続き: 残りの View 移行
- [ ] HomeView — @Query → Repository 経由
- [ ] ProjectsView — @Query → Repository 経由
- [ ] ProjectDetailView — @Query → Repository 経由
- [ ] ToDoView — @Query → Repository 経由
- [ ] SettingsView — @Query → Repository 経由

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
- [ ] FilesRowView の仕様書レイアウト適合
- [ ] LiveRecordingBanner / FABMenu 統合
- [ ] コンテキストメニュー（名前変更/Project追加/共有/削除）
- [ ] EmptyStateView 統合

### TASK-015: ファイル詳細画面（仕様適合）
- [ ] AudioPlayerView の仕様書デザイン適合
- [ ] Upload image ボタン
- [ ] 「議事録を生成」導線

### TASK-018: LLMRouter + LocalProvider
- [ ] LLMProviderProtocol 定義
- [ ] LocalLLMProvider（Apple Foundation Models）
- [ ] SummarizationEngine 本実装

### TASK-019 続き: PipelineCoordinator 高度化
- [ ] ProcessingJob / ProcessingChunk の状態管理
- [ ] チャンク単位のリトライ（指数バックオフ）

### TASK-020: 生成フロー UI
- [ ] GenerationFlowSheet（方式 → テンプレート → モデル選択）仕様適合
- [ ] SkeletonView 統合（ステップ名表示付き）

### TASK-021: 生成結果表示
- [ ] FileDetailView のフルレイアウト仕様適合
- [ ] TranscriptView 全文画面の仕様適合（話者セグメント表示）

### TASK-022: 失敗トースト統合
- [ ] PipelineCoordinator エラー → ToastOverlay 表示

---

## P2 — 拡張機能（TASK-023〜033）

### TASK-023: 添付ファイル
- [ ] 画像/PDF 保存・プレビュー
- [ ] AttachmentGalleryView（80x80 横スクロールサムネイル）

### TASK-024: ToDo 抽出統合
- [ ] PipelineCoordinator の ToDo 抽出ステップ強化
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
- [ ] OpenAIProvider / AnthropicProvider / GeminiProvider / DeepSeekProvider

### TASK-031: モデル切替 UI
- [ ] ファイル詳細のモデル選択シート
- [ ] Ask AI 入力欄のモデル切替チップ
- [ ] Free ユーザーのロック表示

### TASK-032: 使用回数制限
- [ ] 無料ユーザー向け LLM 使用回数カウント・制限

### TASK-033: 広告表示
- [ ] AdService（Google Mobile Ads）
- [ ] Files 一覧バナー / 生成後インタースティシャル

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
| デザイントークン | DesignSystem/ で一元管理 | ✅ トークン定義 + View 適用済み |
| データアクセス | Repository パターン | ✅ Repository 層実装済み、移行進行中 |
| Liquid Glass | 独自3層モディファイア | .glassEffect()（iOS 26 API）使用 |
| iOS target | 18+ | 17+ |

> **注意**: 仕様書は TCA 前提で書かれているが、TCA は既に除去済み。
> 機能要件（画面仕様・データモデル・サービス仕様）はそのまま参考にでき、
> Reducer 部分は ViewModel に読み替えて実装する。

---

## 優先順位の考え方

| 優先度 | 目標 | 対象 TASK |
|--------|------|-----------|
| **P0** | 共通コンポーネント + Repository 移行完了 | 003, 005続き |
| **P1** | コア機能（生成パイプライン + 画面仕様適合） | 006〜022 |
| **P2** | 拡張機能（Ask AI, ToDo, Projects, 広告） | 023〜033 |
| **P3** | 将来構想（APIキー, クラウド, 外部連携） | 034〜037 |
