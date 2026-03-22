# Memora Windows側準備作業

## 目的

macOS側でXcodeプロジェクトを作成する前に、Windows側で準備作業を完了する。

## 準備リスト

### 1. 仕様書の整理

#### 仕様書の構造確認
- **第1部: プロジェクト基盤**
  - 開発環境: iOS 18+, Xcode 16, Swift 6, Strict Concurrency
  - ディレクトリ構造: 仕様書通りに実装
  - 依存パッケージ: TCA 1.17+, AuthenticationServices, StoreKit 2, GoogleSignIn 7.x, Speech, GoogleMobileAds 11.x

- **第2部: デザインシステム**
  - カラートークン: Semantic Tokenとして定義
  - タイポグラフィ: Dynamic Typeに対応
  - Liquid Glass: 3層構造（背景ブラー + 半透明オーバーレイ + ストローク）
  - 間隔トークン: xxxs から xxxxl

- **第3部: データ層**
  - SwiftDataモデル: AudioFile, Transcript, MeetingNote, Project, TodoItem, Attachment, ProcessingJob, ProcessingChunk, ChatScope
  - Repositoryパターン: Protocol + 実装 + DependencyKey

- **第4部: 認証・課金・広告**
  - 認証: Apple + Google（Firebase統合）
  - 課金: StoreKit 2（Product ID定義済み）
  - 広告: Google Mobile Ads（バナー + インタースティシャル）

- **第5部: 画面別実装仕様**
  - オンボーディング: 4ページスクロール
  - サインイン: Apple + Google ボタン
  - Paywall: 機能比較 + プラン選択
  - Files一覧: 一覧表示 + 空状態 + ライブバナー + FABメニュー
  - 録音: 全画面モーダル + 波形ビジュアライザー
  - 他: Project, Todo, Settings の詳細仕様

### 2. 実装に必要なファイルの確認

#### 現在のファイル状況
```
Memora/
├── .git/
├── .claude/
│   ├── settings.json
│   └── settings.local.json
├── CLAUDE.md
├── README.md
├── docs/
│   ├── architecture.md
│   ├── todo.md
│   └── handoff.md
└── Memora仕様書.txt
```

#### 不足しているファイル
- **App/**: Xcodeプロジェクト作成時に自動生成
  - MemoraApp.swift
  - AppDelegate.swift
  - AppReducer.swift

- **Core/**: データモデルとリポジトリ
  - Models/: AudioFile.swift, Project.swift, TodoItem.swift
  - Persistence/: SwiftDataStack.swift, AudioFileRepository.swift
  - Services/: AudioRecorder.swift（モック）
  - Utilities/: FileManager+Memora.swift

- **Features/**: TCAベースの画面実装
  - Files/FilesList/: FilesListReducer.swift, FilesListView.swift, FilesRowView.swift
  - Files/Recording/: RecordingReducer.swift, RecordingView.swift
  - Import/: ImportReducer.swift, ImportView.swift
  - Settings/: SettingsReducer.swift, SettingsView.swift

- **DesignSystem/**: デザインシステム
  - Theme/Colors.swift
  - Theme/Typography.swift
  - Components/LiquidGlassModifier.swift, EmptyStateView.swift

### 3. 基本的なコード例の準備

#### TCAの基本パターン
```swift
// Reducerの基本構造
@Reducer
struct FeatureReducer {
    @ObservableState
    struct State: Equatable {
        var items: [ItemType] = []
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }

    enum Action {
        case onAppear
        case itemsLoaded([ItemType])
        case loadError(String)
    }

    @Dependency(\.repository) var repository
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let items = try await repository.fetchAll()
                    await send(.itemsLoaded(items))
                }
            case .itemsLoaded(let items):
                state.items = items
                return .none
            case .loadError(let message):
                state.errorMessage = message
                return .none
            }
        }
    }
}
```

#### SwiftDataモデルの基本構造
```swift
// SwiftDataモデルの基本構造
import Foundation
import SwiftData

@Model
final class AudioFile {
    @Attribute(.unique) var id: UUID
    var title: String
    var recordedAt: Date
    var durationSec: Double
    var localPath: String
    var sourceType: SourceType

    enum SourceType: String, Codable {
        case iphoneRecording = "iphone_recording"
        case importedFile = "imported_file"
    }

    init(
        id: UUID = UUID(),
        title: String,
        recordedAt: Date = Date(),
        durationSec: Double,
        localPath: String,
        sourceType: SourceType
    ) {
        self.id = id
        self.title = title
        self.recordedAt = recordedAt
        self.durationSec = durationSec
        self.localPath = localPath
        self.sourceType = sourceType
        self.createdAt = Date()
    }
}
```

### 4. ドキュメントの整理

#### CLAUDE.mdの内容確認
- ✅ すべての回答は日本語
- ✅ 専門用語はできるだけわかりやすく説明する
- ✅ 実装前に、何をするかを日本語で短く整理する
- ✅ 大きな変更の前は以下の順で進める
- ✅ iOS first / SwiftUI / シンプルで保守しやすい構成 / 低コスト実装優先
- ✅ モノトーンベース / iOS ネイティブらしい操作感
- ✅ Windows / macOS の両方で継続しやすい構成

#### README.mdの内容確認
- ✅ プロジェクト概要
- ✅ 想定される機能の説明
- ✅ 開発状況の記載
- ✅ クイックスタートガイド

#### docs/architecture.mdの内容確認
- ✅ iOS First
- ✅ SwiftUI Center
- ✅ 小さく保守しやすい構成
- ✅ モックデータで進められる構造

### 5. GitHub リポジトリの確認

#### 現在のブランチ構成
```
* origin/main  (初期コミット: "Initial commit")
* master (現在の作業ブランチ)
```

#### GitHub連携の確認
- ✅ リモートリポジトリ: https://github.com/Skyjoy0512/Memora
- ✅ origin/master と同期完了
- ✅ iPhone からのリモート承認設定済み

## 準備完了後の次ステップ

1. **macOS側でXcodeプロジェクト作成**
   - 手順は計画書に従う
   - Windows側から指示を受けながら実装

2. **並行開発の開始**
   - macOS: Xcodeでの実装
   - Windows: ドキュメント更新・計画調整

3. **基本構築の完了確認**
   - プロジェクト初期化
   - SwiftDataセットアップ
   - 基本的なUI実装
   - モック録音機能

## 注意点

- **実装範囲**: 基本構築のみ（Filesタブ、空のFiles一覧画面、基本ナビゲーション）
- **除外項目**: AI生成、課金、広告動的表示はPhase 2
- **優先順位**: 計画書のフェーズ1〜6に従う
- **コード品質**: Swift 6のStrict Concurrency、TCAのベストプラクティスに従う
