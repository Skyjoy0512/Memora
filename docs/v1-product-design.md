# Memora v1 Product Design — Single Source of Truth

> **この文書が current truth です。**
> Claude / Codex は迷ったらここを最初に読むこと。
> 最終更新: 2026-04-03

---

## 1. v1 対象機能

| # | 機能 | ステータス |
|---|------|-----------|
| 1 | アプリ内録音 | done |
| 2 | 音声ファイルインポート（m4a/wav/mp3/aiff） | done |
| 3 | ローカル文字起こし（SFSpeechRecognizer / iOS 26 SpeechAnalyzer） | done |
| 4 | API 文字起こし（OpenAI Whisper / Gemini） | done |
| 5 | AI 要約（OpenAI / Gemini / DeepSeek） | done |
| 6 | 話者分離（オンデバイス voice clustering） | done |
| 7 | 話者サンプル登録（自分の声） | done |
| 8 | エクスポート（TXT / Markdown / JSON / SRT / VTT） | done |
| 9 | プロジェクト管理 | done |
| 10 | Plaud エクスポートファイルインポート（JSON/TXT） | done |
| 11 | Omi デバイス連携（scan / connect / live preview / audio import） | done |
| 12 | Plaud OAuth 同期（開発者機能） | done（deprioritized） |
| 13 | ToDo 管理 | done |

## 2. 非対象機能（v1 スコープ外）

- iCloud 同期
- カレンダー双方向連携（calendarEventId は保存のみ）
- リアルタイムストリーミング文字起こし（Omi preview は別）
- Webhook 外部送信
- Ask AI チャット（UI あり、pipe は今後）
- macOS / iPad ネイティブ対応
- オンデバイス Whisper（WhisperKit 等）
- 多言語 UI（現状日本語 + 英語混在）

## 3. 入力経路

```
┌──────────────┐   ┌──────────────┐   ┌─────────────┐   ┌───────────────┐
│  App Recording│   │  File Import │   │  Omi Device │   │ Plaud Export  │
│  (FAB → 録音) │   │  (FAB →     │   │  (Settings  │   │ (FAB → Plaud) │
│              │   │   インポート) │   │   → Scan)   │   │  JSON / TXT   │
└──────┬───────┘   └──────┬───────┘   └──────┬──────┘   └───────┬───────┘
       │                  │                   │                   │
       ▼                  ▼                   ▼                   ▼
  AudioRecorder    AudioFileImport     OmiAdapter          PlaudImport
       │            Service                │               Service
       │                  │               │                   │
       └──────────┬───────┴───────────────┴───────────────────┘
                  ▼
            AudioFile (SwiftData)
            sourceType: recording | import | plaud
```

### 経路詳細

| 経路 | トリガー | 保存先 | sourceType |
|------|---------|--------|------------|
| App Recording | FAB → 録音 → RecordingView | Documents/ | `recording` |
| File Import | FAB → インポート → fileImporter | Documents/ | `import` |
| Omi Device | Settings → Omi Scan → Connect → Live Audio | Documents/ | `import` |
| Plaud Export | FAB → Plaud → fileImporter (JSON/TXT) | referenceTranscript のみ（音声なし可） | `plaud` |

## 4. 処理パイプライン

```
AudioFile
    │
    ▼
STTService（orchestration 中心）
    ├── backend selection: SpeechAnalyzer → SFSpeechRecognizer → API
    ├── chunking（AudioChunker）で長時間対応
    ├── SpeakerDiarizationService（話者分離）
    └── Transcript → SwiftData 保存
    │
    ▼
SummarizationEngine
    ├── AIProvider: OpenAI / Gemini / DeepSeek
    ├── summary / keyPoints / actionItems 生成
    └── AudioFile プロパティに保存
    │
    ▼
PipelineCoordinator（Transcription → Summary → Todo 抽出 を統括）
```

### 文字起こしバックエンド選択順

1. iOS 26+ → SpeechAnalyzer（ベータ、設定で有効化）
2. iOS 17+ → SFSpeechRecognizer（デフォルト）
3. API モード → OpenAI Whisper / Gemini

### AI プロバイダー

| Provider | 文字起こし | 要約 | 料金目安 |
|----------|-----------|------|---------|
| OpenAI | Whisper API ($0.006/分) | GPT-4o-mini ($0.00015/1K) | 中 |
| Gemini | 1.5 Flash ($0.0025/15s) | 1.5 Flash ($0.000075/1K) | 安 |
| DeepSeek | 未対応 | Chat ($0.00014/1K) | 最安 |

## 5. 出力

| 形式 | 内容 | 実装 |
|------|------|------|
| Transcript（SwiftData） | 話者ラベル付き全文 + セグメント | Transcript model |
| Summary（AudioFile プロパティ） | summary / keyPoints / actionItems | AudioFile model |
| Reference Transcript | Plaud 側文字起こし（参照用） | AudioFile.referenceTranscript |
| Export | TXT / Markdown / JSON / SRT / VTT | ExportService |

## 6. 現在の Repo Truth

### 技術スタック
- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI
- **Persistence**: SwiftData（ModelContext 直書き、repositoryFactory は残存するが非推奨）
- **Architecture**: MVVM
- **iOS Target**: 17.0（project.yml）
- **Xcode**: 26.3
- **Project Generation**: xcodegen（project.yml → Memora.xcodeproj）
- **Package**: OmiSDK（omi_lib、optional canImport）

### ディレクトリ構造（実装済み）

```
Memora/
├── App/
│   ├── MemoraApp.swift          # App entry, ModelContainer schema
│   ├── AppDelegate.swift        # UIKit delegate
│   └── ContentView.swift        # Main tab + FAB overlay
├── Core/
│   ├── Models/
│   │   ├── AudioFile.swift      # @Model — sourceType, referenceTranscript
│   │   ├── Transcript.swift     # @Model — speaker segments
│   │   ├── Project.swift        # @Model
│   │   ├── MeetingNote.swift    # @Model
│   │   ├── TodoItem.swift       # @Model
│   │   ├── ProcessingJob.swift  # @Model
│   │   ├── WebhookSettings.swift # @Model
│   │   ├── PlaudSettings.swift  # @Model — OAuth tokens
│   │   ├── PlaudRecording.swift  # Codable — API response
│   │   └── PlaudExportModels.swift # Codable — export file parser
│   ├── Services/
│   │   ├── AudioRecorder.swift
│   │   ├── AudioPlayer.swift
│   │   ├── AudioChunker.swift
│   │   ├── AudioFileImportService.swift
│   │   ├── STTService.swift          # ★ STT orchestration 中心
│   │   ├── STTSupportTypes.swift     # ★ config / timeout / feature flag
│   │   ├── TranscriptionEngine.swift # ★ UI facade over STTService
│   │   ├── SpeakerDiarizationService.swift
│   │   ├── SpeakerProfileStore.swift
│   │   ├── SummarizationEngine.swift
│   │   ├── PipelineCoordinator.swift
│   │   ├── ExportService.swift
│   │   ├── PlaudService.swift        # OAuth API sync
│   │   ├── PlaudImportService.swift  # File-based import
│   │   ├── OmiAdapter.swift          # Official SDK adapter
│   │   ├── OmiSupportTypes.swift     # Omi connection/device models
│   │   ├── BluetoothAudioService.swift # Generic BLE (experimental)
│   │   ├── WebhookService.swift
│   │   └── DebugLogger.swift
│   ├── ViewModels/
│   │   ├── RecordingViewModel.swift
│   │   ├── FileDetailViewModel.swift
│   │   └── HomeViewModel.swift
│   ├── Contracts/            # DTOs
│   └── Networking/
│       └── AIService.swift   # ★ AI provider routing
├── Views/
│   ├── HomeView.swift
│   ├── FileDetailView.swift
│   ├── RecordingView.swift
│   ├── SettingsView.swift
│   ├── ProjectsView.swift
│   ├── ProjectDetailView.swift
│   ├── CreateProjectView.swift
│   ├── ToDoView.swift
│   ├── TranscriptView.swift
│   ├── SummaryView.swift
│   ├── GenerationFlowSheet.swift
│   ├── ExportOptionsSheet.swift
│   ├── AskAIView.swift
│   ├── ShareSheet.swift
│   ├── DeviceConnectionView.swift
│   ├── RealtimeTranscriptionView.swift
│   ├── FilterSheet.swift
│   ├── ProjectPickerSheet.swift
│   ├── OnboardingView.swift
│   ├── DebugLogView.swift
│   └── Components/
│       └── BottomFloatingBar.swift  # MainTab, MorphingTabBar
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── Preview Content/
```

### 主要ナビゲーション

```
TabView (MainTab)
├── Files    → HomeView → FileDetailView
├── Projects → ProjectsView → ProjectDetailView
├── ToDo     → ToDoView
└── Settings → SettingsView
                  ├── DeviceConnectionView (Omi)
                  └── DebugLogView

FAB Overlay (ContentView)
├── 録音     → HomeView.showRecordingView → RecordingView
├── インポート → fileImporter (audio)
└── Plaud    → fileImporter (JSON/TXT) → PlaudImportService
```

## 7. 責務境界の方針

### STT コア保護（docs/transcription-core-boundary.md が current truth）

以下ファイルは明示依頼なしに変更しない：
- `STTService.swift`
- `STTSupportTypes.swift`
- `TranscriptionEngine.swift`
- `SpeakerDiarizationService.swift`
- `SpeakerProfileStore.swift`
- `AIService.swift`
- `CoreDTOs.swift`

### レーン責務（CLAUDE.md が current truth）

| Lane | 対象 | 備考 |
|------|------|------|
| A | `Views/**` | UI |
| B | STT / Audio services | 保護ルール適用 |
| C | Models / ViewModels / Contracts | |
| D | App / project.yml / CI | |
| E | Tests / CI / logs | |

### Omi 境界
- production path = `OmiAdapter`（official SDK）
- `BluetoothAudioService` = generic BLE experimental path
- Omi live transcript は preview 用。final transcript の truth は Memora STT pipeline

### Plaud 境界
- v1 primary path = file-based import（`PlaudImportService`）
- OAuth sync（`PlaudService`）は開発者機能として残すが推奨しない

## 8. 今後の実装順（優先度順）

| 優先度 | 項目 | 概要 |
|--------|------|------|
| P0 | Plaud 音声同時インポート | Plaud エクスポートに音声ファイルが含まれる場合の importFromExport 本格利用 |
| P1 | Ask AI 実装 | 文字起こし結果に対する Q&A（RAG or context-window） |
| P1 | Webhook 送信 | 文字起こし/要約完了時の外部通知 |
| P2 | オフライン安定性 | バックグラウンド復帰後の再開、ネットワーク断時キューイング |
| P2 | Omi 話者分離強化 | Omi 参照で話者埋め込みマッチング、自分の声自動ラベル |
| P3 | iCloud 同期 | CloudKit 経由のデバイス間同期 |
| P3 | カレンダー双方向連携 | EventKit で予定 → 録音トリガー |
| P3 | macOS / iPad 対応 | ウィンドウサイズ対応、Catalyst or native |

---

## Document Status

| ドキュメント | Status | 備考 |
|-------------|--------|------|
| **docs/v1-product-design.md** | **CURRENT TRUTH** | この文書 |
| CLAUDE.md | CURRENT | 開発運用ルール（本書と矛盾時は本書優先） |
| docs/transcription-core-boundary.md | CURRENT | STT 保護ルール |
| docs/architecture.md | OUTDATED | 初期設計時の仮定。モデル・構造が実装と乖離 |
| docs/development-workflow.md | OUTDATED | TCA 採用前提。現在は MVVM |
| docs/transcription-spec.md | PARTIAL | サービス一覧は参考になるが、アーキテクチャ図は旧情報 |
| docs/transcription-implementation.md | OUTDATED | TranscriptionEngine が facade 化される前の記述 |
| README.md | OUTDATED | 初期フェーズ表記。機能一覧は参考 |
| その他 docs/*.md | REFERENCE | agent-teams, pm-agent, parallel-development 等は運用ガイド |
