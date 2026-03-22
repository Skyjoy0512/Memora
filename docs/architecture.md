# Memora - アーキテクチャ設計

## 基本方針

### iOS First
- プラットフォームは iOS を第一優先
- iOS ネイティブの機能を最大限活用
- iPad のサポートも将来的に検討

### SwiftUI Center
- UI フレームワークは SwiftUI を中心に
- UIKit は必要な場合にのみ使用（例：カスタムビュー）
- iOS 17+ をターゲットに最新機能を活用

### 小さく保守しやすい構成
- 1つのファイルは1つの責任に絞る
- フォルダ構造はわかりやすく
- 過度な抽象化を避ける

### モックデータ優先
- 初期段階ではモックデータで開発を進める
- API 統合は後から実装可能な構造にする
- データモデルは変更に強く設計

## プロジェクト構成

```
Memora/
├── Memora/                    # メインアプリソース
│   ├── App/                   # アプリエントリポイント
│   │   └── MemoraApp.swift    # App 構造体
│   │
│   ├── Views/                 # SwiftUI ビュー
│   │   ├── Home/              # ホーム画面
│   │   │   ├── FilesView.swift
│   │   │   └── ProjectListView.swift
│   │   ├── Recording/         # 録音機能
│   │   │   ├── RecordingView.swift
│   │   │   └── RecordingControls.swift
│   │   ├── Transcription/     # 文字起こし
│   │   │   ├── TranscriptionView.swift
│   │   │   └── SpeakerLabelView.swift
│   │   ├── Summary/           # 要約
│   │   │   └── SummaryView.swift
│   │   ├── AskAI/             # AI チャット
│   │   │   └── AskAIView.swift
│   │   └── Components/        # 再利用可能コンポーネント
│   │       ├── FileCard.swift
│   │       ├── ToastView.swift
│   │       └── LoadingView.swift
│   │
│   ├── Models/                # データモデル
│   │   ├── Recording.swift    # 録音データ
│   │   ├── Project.swift      # プロジェクトデータ
│   │   ├── Transcription.swift # 文字起こしデータ
│   │   └── Speaker.swift      # 話者情報
│   │
│   ├── ViewModels/            # MVVM ビューモデル
│   │   ├── RecordingViewModel.swift
│   │   ├── TranscriptionViewModel.swift
│   │   └── SummaryViewModel.swift
│   │
│   ├── Services/              # 各種サービス
│   │   ├── AudioService.swift        # 録音・再生
│   │   ├── TranscriptionService.swift # 文字起こし（モック→API）
│   │   ├── SummaryService.swift       # 要約（モック→API）
│   │   └── StorageService.swift       # データ保存
│   │
│   └── Utilities/             # ユーティリティ
│       ├── Extensions/         # Swift 拡張
│       ├── Helpers/           # 補助関数
│       └── Constants/         # 定数定義
│
├── MemoraTests/               # テストコード
└── docs/                      # ドキュメント
    ├── architecture.md         # このファイル
    ├── todo.md                # タスク管理
    └── handoff.md             # 引き継ぎ情報
```

## データモデル

### Recording（録音）
```swift
struct Recording {
    let id: UUID
    let title: String
    let date: Date
    let duration: TimeInterval
    let audioURL: URL
    var transcription: Transcription?
    var summary: String?
}
```

### Project（プロジェクト）
```swift
struct Project {
    let id: UUID
    let title: String
    let createdAt: Date
    var recordings: [Recording]
}
```

### Transcription（文字起こし）
```swift
struct Transcription {
    let id: UUID
    let recordingId: UUID
    let text: String
    let segments: [TranscriptionSegment]
    let timestamp: Date
}
```

### TranscriptionSegment（文字起こしセグメント）
```swift
struct TranscriptionSegment {
    let speaker: Speaker
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}
```

### Speaker（話者）
```swift
struct Speaker {
    let id: UUID
    let name: String  // "Speaker 1", "Speaker 2", ...
    var color: Color?
}
```

## サービス構成

### AudioService
- 録音の開始・停止
- 音声データの保存
- 音声再生

### TranscriptionService
- 文字起こし処理
- 初期はモックデータ
- 将来的には API 連携（Whisper API、Speech-to-Text API）

### SummaryService
- 要約生成
- 初期はモックデータ
- 将来的には AI API 連携（OpenAI、Anthropic など）

### StorageService
- データの永続化
- CoreData または SwiftData
- ファイル管理

## UI フロー

### メインフロー
1. **ホーム画面** → プロジェクト・ファイル一覧
2. **新規録音** → 録音画面
3. **録音完了** → 自動文字起こし開始
4. **文字起こし完了** → 要約生成開始
5. **結果表示** → 文字起こし・要約を確認

### 追加機能
- 既存音声ファイルのインポート
- プロジェクト管理
- テキスト編集・修正
- エクスポート（テキスト、PDF など）

## 段階的実装計画

### Phase 1: 基礎構築
- プロジェクト構築
- 基本的な UI 構築
- モックデータによる動作確認

### Phase 2: 録音機能
- 音声録音の実装
- ファイル保存
- 基本的な UI 連携

### Phase 3: 文字起こし（モック）
- 文字起こし UI の実装
- モックデータでの動作確認
- 話者分離の UI

### Phase 4: 要約（モック）
- 要約 UI の実装
- モックデータでの動作確認

### Phase 5: API 統合
- 文字起こし API の連携
- 要約 API の連携
- エラーハンドリング

### Phase 6: 拡張機能
- Ask AI 機能
- 添付資料管理
- エクスポート機能

## 技術スタック

### 言語・フレームワーク
- Swift 5.9+
- SwiftUI
- iOS 17+

### データ永続化
- SwiftData（iOS 17+）
- または CoreData

### 音声処理
- AVFoundation
- Speech Framework（ローカル文字起こし）

### ネットワーク
- URLSession
- async/await

## 将来の拡張性

### マルチプラットフォーム
- iPad 対応
- macOS 対応（Mac Catalyst）

### 高度な機能
- リアルタイム文字起こし
- 高度な話者分離
- AI チャット機能
- 協同編集

### 統合
- iCloud 同期
- カレンダー連携
- ノートアプリ連携
