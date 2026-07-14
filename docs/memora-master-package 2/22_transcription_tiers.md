# 22. 文字起こし・要約の無料/有料2系統 設計

対象: iOS + macOS 共通の Core 層 / 依存: 既存 AIService
出典: Google Gemini API 公式(ai.google.dev/gemini-api/docs/pricing)、各種価格調査(2026-07 時点)

> ⚠️ **用語の訂正**: 「Gemini in Chrome」はブラウザの UI 機能であり、アプリから叩ける公開 API ではない。プログラムから Gemini を使うのは **Gemini API(Google AI Studio のキー)**。Web/Electron なら Chrome 組み込み AI(`window.ai` Prompt API)も一部使えるが、STT 用途には現状不向き。§4 参照。

---

## 1. 全体方針: 2系統(無料 / 有料高品質)をユーザーが選べる

| 系統 | 文字起こし | 要約 | データ扱い | コスト |
|---|---|---|---|---|
| **無料** | ① オンデバイス(iOS SpeechAnalyzer/SFSpeech、macOS Speech)② Gemini API 無料枠(Flash) | Gemini Flash 無料枠 / DeepSeek 低額 | ①は完全ローカル。②はGoogleの学習対象 | ¥0(①)/ ¥0 だが枠と学習(②) |
| **有料・高品質** | OpenAI `gpt-4o-transcribe`/`whisper-1`、Gemini 有料 Flash/Pro | Claude / GPT / Gemini Pro | ゼロ保持契約(有料) | 従量 |

既存 `AIProvider`(`openai/gemini/deepseek/local`)を活かしつつ、**Gemini を文字起こしにも対応**させる(現状 `supportsTranscription` は openai のみ true)。

## 2. 調査に基づく価格・可用性(2026-07 時点、要再確認)

### 2.1 無料枠
- **iOS/macOS オンデバイス STT**: 完全無料・ローカル・オフライン可。既存実装。**機微データの第一選択**。
- **Gemini API 無料枠**: Flash 系(2.5/3/3.1 Flash・Flash-Lite)が **1,500 リクエスト/日、~15 RPM、1M TPM**。音声入力対応(mp3/wav/flac、文字起こし・要約に使える)。**ただし入力が Google の学習に使われる**(機微データ不可)。Pro は無料枠から除外済み。
- **DeepSeek**: 低額。要約用途で安価な選択肢。文字起こしは非対応(要確認)。

### 2.2 有料・高品質
- **OpenAI 文字起こし**: `gpt-4o-transcribe`(既存)、`whisper-1`(タイムスタンプ verbose 対応、先の同期設計 03 で採用)。
- **Gemini 有料**: Flash($0.30/$2.50 per M、音声入力は別レート ~$1/M)、Pro(高品質・高額)。**Gemini Flash はオンデバイス STT より高品質な文字起こしを安価に**できる可能性(音声理解が LLM ネイティブ)。調査では「基本的な文字起こしは Gemini Flash が Google Cloud Chirp より ~16倍安い」との試算あり。
- **要約**: Claude / GPT / Gemini Pro を品質重視で選択。

### 2.3 重要な注意
- 価格・無料枠・モデル名は**頻繁に変わる**(2026年に入って Pro が無料枠から除外、2.0 系が非推奨化等)。実装時に **ai.google.dev/gemini-api/docs/pricing と AI Studio の実際のレート表示を必ず確認**。
- 無料枠は地域・アカウント認証状態で変動。EEA/英国/スイスのユーザーには有料必須の規約あり(要確認)。

## 3. 実装: Gemini を文字起こしプロバイダに追加

### 3.1 `AIProvider.supportsTranscription` の変更(`AIService.swift`)

```swift
var supportsTranscription: Bool {
    switch self {
    case .openai: return true
    case .gemini: return true      // ← 追加(Gemini 音声理解で対応)
    case .deepseek: return false
    case .local: return false
    }
}
```

### 3.2 Gemini 文字起こし実装

Gemini API は音声ファイルを input として渡し、プロンプトで「文字起こしして。タイムスタンプ付き JSON で」と指示する方式。REST の `generateContent` に inline_data(base64 音声)または File API でアップロードした参照を渡す。

```swift
// AIService の Gemini 実装に追加
func transcribeWithGemini(audioURL: URL, apiKey: String, model: String = "gemini-2.5-flash") async throws -> TimedTranscription {
    let audioData = try Data(contentsOf: audioURL)
    let base64 = audioData.base64EncodedString()
    let mime = "audio/wav"   // ファイルに応じて

    let body: [String: Any] = [
        "contents": [[
            "parts": [
                ["inline_data": ["mime_type": mime, "data": base64]],
                ["text": """
                この音声を文字起こししてください。話者ごとに区切り、各セグメントに開始秒・終了秒を付け、
                次の JSON のみを返してください(前置き・コードブロック不要):
                {"language":"ja","segments":[{"start":0.0,"end":3.2,"speaker":"1","text":"..."}]}
                """]
            ]
        ]],
        "generationConfig": ["temperature": 0, "responseMimeType": "application/json"]
    ]

    // POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}
    // レスポンスの candidates[0].content.parts[0].text を JSON デコード → TimedTranscription
    ...
}
```

■確認せよ:
- **25MB 超の音声は inline_data 不可 → File API(`/upload/v1beta/files`)でアップロード**してから参照する。会議録音は長いので File API 経路が基本。
- Gemini のタイムスタンプ精度は Whisper verbose ほど高くない場合がある。SRT 用途では OpenAI `whisper-1` を、内容把握用途では Gemini を、と使い分ける設計にする(03 の `isEstimatedTiming` と整合)。
- 長時間音声はチャンク分割(既存 AudioChunker)して各チャンクを Gemini に投げ、オフセット加算でマージ(既存 merge 流用)。

### 3.3 TranscriptionMode / プロバイダ選択 UI

設定に「文字起こしエンジン」の選択を追加(既存 `TranscriptionMode` を拡張、または provider 選択と統合):

```
文字起こしエンジン:
 ○ オンデバイス(無料・オフライン・非共有)      ← 既定・推奨
 ○ Gemini 無料枠(無料・要ネット・Google が学習に利用)  ← 警告バッジ
 ○ OpenAI(有料・高品質・ゼロ保持)
 ○ Gemini 有料(高品質)
```

無料枠選択時は「この音声は Google の AI 改善に使われる可能性があります。機微な内容には使わないでください」の警告を必須表示。

## 4. 「Chrome 内蔵 AI」について(デスクトップが Web/Electron の場合のみ)

- Chrome には組み込み AI(Gemini Nano ベースの `window.ai` / Prompt API / Summarizer API / Translator API)がある。**完全オンデバイス・無料・オフライン**。
- ただし: **STT(音声→テキスト)は現状 Prompt API のスコープ外**(テキスト/画像中心)。要約(Summarizer API)や翻訳には使える。
- macOS ネイティブ(推奨構成)では `window.ai` は使えない(ブラウザ限定)。
- **結論**: デスクトップが macOS ネイティブなら Chrome 内蔵 AI は対象外。要約の無料ローカル手段としては、macOS も **Apple の on-device モデル(Foundation Models、macOS 26+ の Writing Tools 系 API)** や オンデバイス STT を使う。Electron 採用時のみ Chrome 組み込み AI を要約・翻訳の無料手段として検討。

■確認せよ: 実装時点での Chrome 組み込み AI(Prompt/Summarizer API)の音声対応状況と、Apple Foundation Models framework(オンデバイス要約)の macOS 可用性。

## 5. 要約の2系統

| 系統 | 手段 |
|---|---|
| 無料 | オンデバイス(Apple Foundation Models / 既存ローカル)、Gemini Flash 無料枠、DeepSeek 低額 |
| 高品質 | Claude / GPT-5 系 / Gemini Pro |

既存の要約パイプライン(`SummarizationEngine` + `AIProvider`)はプロバイダ切替に対応済みなので、**Gemini/DeepSeek のキー設定と model 選択を UI に足すだけ**で2系統が成立する。

## 6. AC

1. 設定で文字起こしエンジンを4択から選べる。無料枠選択時に学習利用の警告が出る。
2. Gemini を選んで音声を文字起こしできる(短尺 inline、長尺 File API)。
3. 25MB 超の音声が File API 経由で通る。
4. 要約プロバイダを無料(Gemini Flash/DeepSeek)と高品質(Claude/GPT/Gemini Pro)で切替できる。
5. オンデバイス経路は従来どおりオフラインで完結する。
6. 価格・モデル名がハードコードでなく、更新しやすい定数/設定にまとまっている。

## 7. コスト設計の指針(UI に反映)
- 既定は**オンデバイス(無料・非共有)**。ユーザーが明示的に高品質 API を選ぶ。
- API 選択時は概算コストの目安を表示できるとよい(音声長 × モデル単価)。
- 機微データ判定は自動化せず、ユーザーにエンジン選択を委ねる+警告表示。
