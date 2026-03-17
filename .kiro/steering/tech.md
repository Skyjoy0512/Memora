# Memora - Technical Stack

## Technology Stack

### Core
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel) - シンプルで保守しやすい
- **Platform**: iOS 17+
- **Development Environment**: Xcode 15+

### Dependencies
- **Package Manager**: Swift Package Manager (SPM)
- **Data Persistence**: SwiftData (iOS 17+)
- **Audio**: AVFoundation
- **No external dependencies** - まずは純正 SDK で実装

## Development Commands

### Build
```bash
# Xcode でビルド
xcodebuild -scheme Memora -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Test
```bash
# テスト実行
xcodebuild test -scheme Memora -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Run Simulator
- Xcode で Run ボタン (▶️) をクリック

## Ports & Configuration
- iOS アプリなので特定のポートは使用しない
- API サービスは将来実装予定

## Architecture Decisions

### MVVM Architecture
- 過度な抽象化を避ける
- まずは動くものを作る
- 将来の拡張性より現在のわかりやすさを優先

### SwiftUI + SwiftData
- iOS 17+ の最新機能を活用
- 型安全なデータモデル
- 宣言的な UI

### Directory Structure
```
Memora/
├── App/
│   ├── MemoraApp.swift          # アプリエントリーポイント
│   └── AppDelegate.swift        # AppDelegate（必要に応じて）
├── Core/
│   ├── Models/                   # SwiftData モデル
│   │   ├── AudioFile.swift
│   │   ├── Transcript.swift
│   │   ├── MeetingNote.swift
│   │   └── Project.swift
│   ├── ViewModels/              # ビューモデル
│   │   ├── HomeViewModel.swift
│   │   └── RecordingViewModel.swift
│   ├── Services/                # 各種サービス
│   │   ├── AudioRecorder.swift
│   │   ├── AudioPlayer.swift
│   │   ├── TranscriptionEngine.swift
│   │   └── SummarizationEngine.swift
│   └── Utilities/              # ユーティリティ
│       └── Extensions.swift
└── Views/                       # SwiftUI ビュー
    ├── HomeView.swift
    ├── RecordingView.swift
    ├── ProjectDetailView.swift
    └── FileDetailView.swift
```

## Testing Strategy
- ユニットテスト: ViewModels, Services
- UI テスト: 主要なユーザーフロー
- CI: GitHub Actions（将来実装）

## Code Style Guidelines
- Swift API Design Guidelines に従う
- シンプルで読みやすいコード
- 適切な命名規則
- コメントは必要最低限
