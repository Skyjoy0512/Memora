# 文字起こし実装仕様書

## 概要

Memora アプリの文字起こし機能は、ローカル（iOS ネイティブ）およびクラウド API（OpenAI、Gemini、DeepSeek）の両方に対応しています。

## 現在の実装

### ファイル構造

```
Memora/Core/Networking/
├── AIService.swift              # 統合 AI サービス
```

### 主なクラス

#### AIService（Unified Service）

アプリ全体の AI サービスを統合管理するクラス。

```swift
final class AIService: AIServiceProtocol, ObservableObject {
    private var provider: AIProvider = .openai
    private var transcriptionMode: TranscriptionMode = .local
    private var openAIService: OpenAIService?
    private var geminiService: GeminiService?
    private var deepSeekService: DeepSeekService?
    private var localTranscriptionService: LocalTranscriptionService?

    // プロバイダー設定
    func setProvider(_ provider: AIProvider)
    func setTranscriptionMode(_ mode: TranscriptionMode)

    // API 設定
    func configure(apiKey: String) async throws

    // 文字起こし
    func transcribe(audioURL: URL) async throws -> String

    // 要約
    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String])
}
```

#### LocalTranscriptionService プロトコル

ローカル文字起こしサービスの共通インターフェース。

```swift
protocol LocalTranscriptionService {
    var isTranscribing: Bool { get }
    var progress: Double { get }
    func transcribe(audioURL: URL) async throws -> String
}
```

#### SpeechAnalyzerService（iOS 26 用プレースホルダー）

iOS 26 SDK がリリースされるまでのプレースホルダー実装。

```swift
@available(iOS 10.0, *)
final class SpeechAnalyzerService: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja_JP"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var progressTimer: Timer?

    func transcribe(audioURL: URL) async throws -> String {
        // SFSpeechURLRecognitionRequest を使用した文字起こし
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        // タスクキャンセル対応
        return try await withTaskCancellationHandler(...)
    }
}
```

**注**: iOS 26 が正式リリースされた際、以下のように置換える予定です：

```swift
@available(iOS 26.0, *)
final class SpeechAnalyzerService: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private let analyzer = SpeechAnalyzer()

    func transcribe(audioURL: URL) async throws -> String {
        let request = TranscriptionRequest(source: URL(fileURLWithPath: audioURL.path))
        request.requiresLanguageContext = true
        request.supportsFinalization = true

        let result = try await analyzer.transcribe(request: request)
        return result.transcribedText
    }
}
```

#### SpeechRecognizerService（iOS 10+）

SFSpeechRecognizer を使用した文字起こしサービス。

```swift
@available(iOS 10.0, *)
final class SpeechRecognizerService: LocalTranscriptionService, ObservableObject {
    @Published var isTranscribing = false
    @Published var progress = 0.0

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var progressTimer: Timer?
    private let locale = Locale(identifier: "ja_JP")

    func transcribe(audioURL: URL) async throws -> String {
        // SFSpeechURLRecognitionRequest を使用
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        // withTaskCancellationHandler でキャンセル対応
        // withCheckedThrowingContinuation で非同期処理
        return try await withTaskCancellationHandler(...)
    }
}
```

#### OpenAIService

OpenAI Whisper API を使用した文字起こしと要約。

```swift
final class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession

    func transcribe(audioURL: URL) async throws -> String {
        // multipart/form-data で音声ファイルを送信
        let boundary = "Boundary-\(UUID().uuidString)"
        // ... リクエスト構築
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        // GPT-4o-mini で要約
        let prompt = "以下の会議 transcript から..."
        // ... API 呼び出し
    }
}
```

#### GeminiService

Gemini 1.5 Flash API を使用した文字起こしと要約。

```swift
final class GeminiService {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    func transcribe(audioURL: URL) async throws -> String {
        // 音声ファイルを Base64 エンコードして送信
        let audioData = try Data(contentsOf: audioURL)
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "audio/mp4a", "data": audioData.base64EncodedString()]]
                ]
            ]
        ]
        // ... API 呼び出し
    }

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        // ... API 呼び出し
    }
}
```

#### DeepSeekService

DeepSeek Chat API を使用した要約のみ（文字起こし未対応）。

```swift
final class DeepSeekService {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"

    func summarize(transcript: String) async throws -> (summary: String, keyPoints: [String], actionItems: [String]) {
        // deepseek-chat モデルで要約
        // ... API 呼び出し
    }
}
```

### データフロー

```
ユーザー操作
    │
    ▼
    ▼
┌──────────────┐   ┌───────────────────┐
│ SettingsView │   │  FileDetailView  │
│ (設定)      │   │  (詳細)         │
└──────────────┘   └───────────────────┘
        │                  │
        │    App State       │
        │    (保存された     │
        ▼   設定           ▼
    ┌───────────────────────────────────────────┐
    │              AIService                  │
    │         (Unified AI Service)           │
    │                                      │
    │  ┌────────────────────────────────────┐ │
    │  │  LocalTranscriptionService      │ │
    │  │  (抽象化された           │ │
    │  │  インターフェース            │ │
    │  └────────────────────────────────────┘ │
    │                                  │
    │  ┌────────────────────────────┐    │
    │  │  SpeechAnalyzerService      │    │
    │  │  (iOS 10+ 実装)      │    │
    │  │  - SFSpeechRecognizer      │    │
    │  │  を使用            │    │
    │  │  - 非同期処理      │    │
    │  │  - タスクキャンセル      │    │
    │  └────────────────────────────┘    │
    │                                  │
    │  ┌────────────────────────────┐    │
    │  │  SpeechRecognizerService      │    │
    │  │  (iOS 10+ 実装)      │    │
    │  │  - SFSpeechRecognizer      │    │
    │  │  を使用            │    │
    │  │  - 非同期処理      │    │
    │  │  - タスクキャンセル      │    │
    │  └────────────────────────────┘    │
    │                                  │
    │  ┌────────────────────────────────────────────┐
    │  │             API プロバイダー          │
    │  │   ┌──────────────────────────────────┐    │
    │  │   │        OpenAIService            │    │
    │  │   │   (Whisper + GPT-4o-mini)     │    │
    │  │   │   - multipart/form-data      │    │
    │  │   │   - 音声送信             │    │
    │  │   │   - JSON レスポンス          │    │
    │  │   └─────────────────────────────────┘    │
    │  │   ┌──────────────────────────────────┐    │
    │  │   │        GeminiService             │    │
    │  │   │   (1.5 Flash)             │    │
    │  │   │   - 音声入力対応            │    │
    │  │   │   - Base64 エンコード        │    │
    │  │   │   - JSON リクエスト           │    │
    │  │   └─────────────────────────────────┘    │
    │  │   ┌──────────────────────────────────┐    │
    │  │   │        DeepSeekService           │    │
    │  │   │   (deepseek-chat)           │    │
    │  │   │   - 要約のみ               │    │
    │  │   │   - 安価                 │    │
    │  │   │   - JSON リクエスト           │    │
    │  │   └─────────────────────────────────┘    │
    │  │   └────────────────────────────────────────────┘
    │
    └────────────────────────────────────────────┘
                  │
        ▼
        ▼
┌──────────────┐   ┌───────────────────┐
│ Files View    │   │  SwiftData DB     │
│ (ファイル一覧)  │   │   (永続化)       │
└──────────────┘   └───────────────────┘
        │                  │
        ▼   ▼
        ▼   録音結果の保存
```

## 使用している Swift 機能

- `async/await` - 非同期 API 呼び出し
- `@Published` - SwiftUI でのプロパティ監視
- `withTaskCancellationHandler` - タスクのキャンセル対応
- `withCheckedThrowingContinuation` - コールバックベースの非同期処理
- `@available` - iOS バージョン条件付きクラス・メソッド
- `multipart/form-data` - ファイルアップロード API リクエスト
- `Base64` エンコード - バイナデータのテキスト変換

## 設計上の考慮点

### 1. プロバイダーの切り替え

- `@AppStorage` で選択中のプロバイダーを保存
- 設定画面での変更は即時に反映
- 複数のプロバイダーを同時に設定可能

### 2. API キーの管理

- API キーはユーザーデバイスにのみ保存（キーチェインは使用せず）
- 実際の送信時に API キーを使用
- 設定画面での保存はローカルに限定

### 3. オフライン対応

- ローカル文字起こしモード時はインターネット接続不要
- 音声ファイルはアプリ内に保存済み
- SwiftData で文字起こし結果を永続化

### 4. エラーハンドリング

- 各サービスで個別のエラー型を定義
- `AIError` - 共通エラー
- `LocalTranscriptionError` - ローカル文字起こしエラー
- `OpenAIError` - OpenAI 固有のエラー

### 5. タスクキャンセル

- バックグラウンド移動時の文字起こし・要約をキャンセル
- `withTaskCancellationHandler` で適切にクリーンアップ

## 今後の拡張性

### iOS 26 SpeechAnalyzer API の正式対応

```swift
@available(iOS 26.0, *)
final class SpeechAnalyzerService: LocalTranscriptionService, ObservableObject {
    private let analyzer = SpeechAnalyzer()

    func transcribe(audioURL: URL) async throws -> String {
        let request = TranscriptionRequest(
            source: URL(fileURLWithPath: audioURL.path),
            features: [.speakerIdentification, .punctuation, .timestamps]
        )

        let result = try await analyzer.transcribe(request: request)
        return result.transcribedText
    }
}
```

### マルチファイル対応

```swift
// AIService.swift に追加
func transcribeMultiple(audioURLs: [URL]) async throws -> [String] {
    try await withThrowingTaskGroup(of: String.self) { group in
        for url in audioURLs {
            group.addTask {
                try await transcribe(audioURL: url)
            }
        }
    }
}
```

### 話者分離（Speaker Diarization）

```swift
struct SpeakerDiarization {
    let speakerId: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}
```

### プログレスバーの強化

```swift
// 現在は簡易なプログレス（0.0 - 1.0）
// 拡張して実際の進捗状況を表示
struct TranscriptionProgress {
    let stage: TranscriptionStage
    let progress: Double
    let message: String?
}

enum TranscriptionStage {
    case loadingAudio
    case initializingRecognizer
    case transcribing
    case postProcessing
    case completed
}
```

## トラブルシューティング

### 文字起こしが開始されない

1. **確認点**:
   - API キーが設定されているか
   - 音声ファイルが存在するか
   - 選択中のモード（ローカル/API）が正しいか

2. **対処**:
   - API キーが未設定の場合は設定画面へ誘導
   - 音声ファイルが見つからない場合はエラーメッセージを表示

### 文字起こしが途中で停止する

1. **原因**:
   - ネットワーク接続が切れた
   - API タイムアウト
   - アプリがバックグラウンドに移動してタスクがキャンセルされた

2. **対処**:
   - `withTaskCancellationHandler` で適切にリソースを解放
   - エラー状態をユーザーに通知
   - 再開可能な状態を保持

### API エラー発生時

1. **エラー分類**:
   - 認証エラー（401）
   - レート制限（429）
   - ネットワークエラー
   - API サーバーエラー（500+）

2. **対処**:
   - エラー種類に応じた適切なメッセージを表示
   - 再試行のオプションを提供
   - サポートセンターへの連絡案内を表示

## テスト計画

### 単体テスト

1. **ローカル文字起こし**:
   - iOS 10-25 実機で SpeechRecognizerService が動作するか確認
   - iOS 26 実機で SpeechAnalyzerService が正しく動作するか確認
   - 短い音声ファイル（10秒以下）と長い音声ファイル（5分以上）の両方でテスト

2. **API 文字起こし**:
   - OpenAI Whisper API で正しく文字起こしができるか確認
   - Gemini API で音声ファイルを送信して文字起こしができるか確認

3. **API 要約**:
   - 各プロバイダーで JSON レスポンスが正しくパースできるか確認
   - 日本語の要約が正しく生成されるか確認

### 統合テスト

1. **設定 → 文字起こし → 要約** のフローが正常に動作するか確認

2. **プロバイダー切り替え** 中に文字起こし中のタスクが正しくキャンセルされるか確認

3. **エラーハンドリング** が適切に機能するか確認
