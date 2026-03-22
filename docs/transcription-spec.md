# 文字起こし仕様書

## 概要

Memora アプリの文字起こし機能は、ローカル（iOS ネイティブ）およびクラウド API（OpenAI、Gemini、DeepSeek）の両方に対応しています。

## 対応環境

- iOS 17.0 以上
- Xcode 15 以上

## 機能一覧

### 1. 文字起こしモード選択

| モード | 説明 |
|--------|--------|
| ローカル | iOS ネイティブの Speech フレームワークを使用した無料の文字起こし |
| API | OpenAI Whisper、Gemini 1.5 Flash、DeepSeek（要約のみ）を使用したクラウド文字起こし |

### 2. 対応言語

- 日本語（ja_JP）

### 3. サービスプロバイダー

#### OpenAI

- **文字起こし**: Whisper-1 API
- **要約**: GPT-4o-mini API
- **料金目安**:
  - 文字起こし: $0.006 / 分
  - 要約: $0.00015 / 1K tokens
- **API キー**: 必須

#### Gemini

- **文字起こし**: 1.5 Flash API（音声入力対応）
- **要約**: 1.5 Flash API
- **料金目安**:
  - 文字起こし: $0.0025 / 15秒
  - 要約: $0.000075 / 1K tokens（無料枠あり）
- **API キー**: 必須
- **制限事項**: 要約のみ

#### DeepSeek

- **文字起こし**: 未対応（ローカル推奨）
- **要約**: DeepSeek Chat API
- **料金目安**:
  - 要約: $0.00014 / 1K tokens（かなり安価）
- **API キー**: 必須

## iOS バージョン対応

### iOS 10 - iOS 25（SpeechRecognizer）

- SFSpeechRecognizer を使用
- オンデバイス認識別（`requiresOnDeviceRecognition = true`）
- 完全な結果のみ報告（`shouldReportPartialResults = false`）

### iOS 26（SpeechAnalyzer）

- SpeechAnalyzer を使用（iOS 26 SDK がリリースされた場合）
- TranscriptionRequest API を使用
- より高度な言語コンテキスト（`requiresLanguageContext = true`）
- 最終化対応（`supportsFinalization = true`）

**注**: iOS 26 はまだ正式リリースされていません。リリース時に正式 API を実装に置換える必要があります。

## UI フロー

1. **ファイル一覧画面** → 録音ファイルを表示
2. **詳細画面** → ファイルの再生・文字起こし・要約
3. **設定画面** → プロバイダー・API キー設定

### 文字起こしフロー

1. 詳細画面で「文字起こし」ボタンをタップ
2. 選択中のモードで文字起こしを実行
3. 文字起こし中はプログレスバーを表示
4. 文字起こし完了後、結果を表示

### 要約フロー

1. 文字起こし完了後に「要約」ボタンが有効化
2. 「要約」ボタンをタップして要約を開始
3. 要約中はプログレスバーを表示
4. 要約完了後、要約・重要ポイント・アクションアイテムを表示

## アーキテクチャ

```
┌─────────────────────────────────────────────────────┐
│              設定画面                   │
│              (SettingsView)              │
├─────────────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐    │
│  │   AIService (Unified)            │    │
│  │   - LocalTranscriptionService      │    │
│  │   - SpeechAnalyzerService      │    │
│  │   - SpeechRecognizerService      │    │
│  │   - OpenAIService              │    │
│  │   - GeminiService               │    │
│  │   - DeepSeekService            │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
              │                 │
              ┌─────────────────────┴──────────────────┐
              │  ファイル詳細画面                   │
              │  (FileDetailView)                  │
              └──────────────────────────────────────────────┘
```

## データモデル

### LocalTranscriptionService

```swift
protocol LocalTranscriptionService {
    var isTranscribing: Bool { get }
    var progress: Double { get }
    func transcribe(audioURL: URL) async throws -> String
}
```

### AIProvider

```swift
enum AIProvider: String, CaseIterable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case deepseek = "DeepSeek"
}
```

### TranscriptionMode

```swift
enum TranscriptionMode: String {
    case local = "ローカル"
    case api = "API"
}
```

## エラーハンドリング

- ネットワーク接続エラー
- API 認証エラー
- 文字起こしエラー
- 要約エラー
- ローカル文字起こしエラー（Speech フレームワーク）

## 今後の検討事項

### iOS 26 SpeechAnalyzer API

- iOS 26 が正式リリースされた場合、SpeechAnalyzerService を正式 API に置換え
- TranscriptionRequest、SpeechAnalyzer クラスの実際 API を使用
- 文字起こしの精度と速度の評価

### マルチモーダル対応

- 音声ファイルのマルチ選択と一括文字起こし
- 話者分離の検討

### オフライン対応強化

- 完全オフラインでの文字起こしと要約履歴のキャッシュ
- 一括処理（バックグラウンドタスク）の改善
