# Memora - Project Structure

## Directory Organization

```
Memora/
├── App/
│   ├── MemoraApp.swift          # アプリエントリーポイント
│   └── AppDelegate.swift        # AppDelegate（必要に応じて）
├── Core/
│   ├── Models/                   # SwiftData データモデル
│   │   ├── AudioFile.swift      # 録音ファイル
│   │   ├── Transcript.swift     # 文字起こしデータ
│   │   ├── MeetingNote.swift    # 議事録
│   │   └── Project.swift        # プロジェクト
│   ├── ViewModels/              # MVVM ビューモデル
│   │   ├── HomeViewModel.swift
│   │   ├── RecordingViewModel.swift
│   │   └── ProjectDetailViewModel.swift
│   ├── Services/                # 各種サービス
│   │   ├── AudioRecorder.swift  # 録音サービス
│   │   ├── AudioPlayer.swift    # 再生サービス
│   │   ├── TranscriptionEngine.swift  # 文字起こしエンジン
│   │   └── SummarizationEngine.swift  # 要約エンジン
│   └── Utilities/              # ユーティリティ
│       └── Extensions.swift
├── Views/                       # SwiftUI ビュー
│   ├── HomeView.swift          # メイン画面（Filesタブ）
│   ├── RecordingView.swift     # 録音画面
│   ├── ProjectDetailView.swift # プロジェクト詳細
│   └── FileDetailView.swift    # ファイル詳細
└── Resources/                   # リソース
    ├── Assets.xcassets         # 画像、カラー
    └── Info.plist              # アプリ情報
```

## Code Patterns

### Model Definition (SwiftData)
```swift
import SwiftData

@Model
final class AudioFile {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioURL: URL

    init(title: String, audioURL: URL) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.createdAt = Date()
        self.duration = 0
    }
}
```

### ViewModel Pattern
```swift
import Observation

@Observable
final class RecordingViewModel {
    var isRecording = false
    var duration: TimeInterval = 0

    private let audioRecorder: AudioRecorder

    init(audioRecorder: AudioRecorder) {
        self.audioRecorder = audioRecorder
    }

    func startRecording() {
        // 録音開始ロジック
    }

    func stopRecording() {
        // 録音停止ロジック
    }
}
```

### View Pattern (SwiftUI)
```swift
import SwiftUI

struct RecordingView: View {
    @State private var viewModel = RecordingViewModel()

    var body: some View {
        VStack {
            // UI コンポーネント
        }
    }
}
```

## Naming Conventions

### Swift Naming
- **Types**: PascalCase (e.g., `AudioFile`, `RecordingViewModel`)
- **Properties/Methods**: camelCase (e.g., `isRecording`, `startRecording()`)
- **Constants**: lowercase with underscores or static properties (e.g., `maxDuration`)
- **File names**: PascalCase matching type name (e.g., `AudioFile.swift`)

### Views
- Suffix with `View` (e.g., `HomeView`, `RecordingView`)

### ViewModels
- Suffix with `ViewModel` (e.g., `HomeViewModel`, `RecordingViewModel`)

### Services
- Noun naming for services (e.g., `AudioRecorder`, `AudioPlayer`)

## File Organization Rules
1. Each type in its own file
2. File name matches type name
3. Group related files in appropriate directories
4. No circular dependencies between modules
5. Models don't depend on ViewModels or Views
6. Views depend on ViewModels, not directly on Services
