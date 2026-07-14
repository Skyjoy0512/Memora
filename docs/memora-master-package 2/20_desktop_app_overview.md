# 20. デスクトップアプリ 全体設計

対象: 新規デスクトップアプリ + 既存 iOS アプリとの同期
目的: PLAUD デスクトップのように PC で Zoom 等のオンライン会議を録音 → クラウド同期 → 文字起こし・要約

---

## 1. プラットフォーム選定

### 1.1 選択肢比較

| 案 | 技術 | 会議音声キャプチャ | iOS コード再利用 | 配布 | 難度 |
|---|---|---|---|---|---|
| **A. macOS ネイティブ** | Swift + SwiftUI + ScreenCaptureKit | ◎ 最良(SCK) | ◎ SwiftData/モデル/STT ロジック共有可 | Mac App Store / notarize | 中 |
| **B. Electron** | TS + Electron | ○(OS 別実装が必要) | △ 再実装 | 全 OS(Win/Mac/Linux) | 中〜高 |
| **C. Tauri** | Rust + Web | ○ | △ | 全 OS、軽量 | 高 |

### 1.2 推奨: **A(macOS ネイティブ)を第一段階**
理由:
- iOS が Swift + SwiftData 主体。**モデル層・STT ロジック・要約ロジックをそのまま共有**できる(コード重複を最小化)。
- macOS の **ScreenCaptureKit** が Zoom 等のアプリ音声を合法・高品質に取得できる(21 詳述)。
- Omi 自身も macOS ネイティブ(Swift/Rust)を採用しており、実績のある構成。
- CloudKit + SwiftData で iOS とシームレス同期(23)。

**Windows 対応が必須要件になった段階で B/C を検討**。その場合はコア(モデル・API クライアント)を共有可能な形に切り出しておく。本設計は macOS 優先で進め、将来の Windows 対応に備えてビジネスロジックを UI から分離する。

## 2. アーキテクチャ

```
┌─────────────────────── Memora macOS App ───────────────────────┐
│  SwiftUI UI 層                                                   │
│  ├─ 会議録音 UI(録音開始/停止、音源選択、レベルメーター)      │
│  ├─ ファイル一覧(iOS と同じ AudioFile を CloudKit 同期表示)  │
│  └─ 文字起こし/要約ビュー(iOS の Transcript/Summary を移植)  │
│                                                                 │
│  Capture 層(21)                                               │
│  ├─ ScreenCaptureKit: アプリ音声(Zoom/Meet/Teams)取得        │
│  ├─ AVCaptureDevice: マイク入力                                │
│  └─ AudioMixer: システム音声 + マイクをミックス                │
│                                                                 │
│  共有 Core 層(iOS と共通・SPM パッケージ化)                   │
│  ├─ Models(AudioFile, Transcript … SwiftData)                │
│  ├─ TranscriptionEngine 相当(macOS 版 STT)                   │
│  ├─ AIService(要約・API クライアント)                        │
│  └─ CloudSyncService(23)                                      │
└─────────────────────────────────────────────────────────────────┘
          │ CloudKit(SwiftData 同期)          │ AI API
          ▼                                     ▼
   iCloud(iOS ⇄ macOS 同期)          OpenAI / Gemini / DeepSeek
```

### 2.1 コード共有戦略
- iOS プロジェクトの **Core 層(Models / AIService / 要約 / 同期)を SPM ローカルパッケージに切り出す**。
- iOS と macOS の両ターゲットがこのパッケージに依存する。
- UI は各プラットフォーム別(SwiftUI だが macOS はウィンドウ/メニュー/サイズが異なる)。
- STT は分岐: iOS は SFSpeech/SpeechAnalyzer、macOS も同 API が使えるが、会議録音は長時間になりがちなので API 経路(22)を主軸に。

■確認せよ: 既存 iOS プロジェクトの Core 層が UIKit/iOS 依存をどれだけ含むか。`UIApplication`(STT の BG タスク等)は macOS で使えないため、プラットフォーム抽象化(`#if os(iOS)`)が必要。この切り出しは大きめの作業なので 30 でフェーズ化。

## 3. 主要機能

1. **会議録音**: Zoom/Meet/Teams の音声 + 自分のマイクを録音(21)。
2. **クラウド同期**: 録音・transcript・要約を iOS と双方向同期(23)。
3. **文字起こし・要約**: 無料/有料の2系統(22)。
4. **ファイル管理**: iOS と同じ一覧・プロジェクト・検索。

## 4. 配布・署名
- Developer ID + notarization(Mac App Store 外配布)か Mac App Store。
- ScreenCaptureKit / マイクは**ユーザー許可**(TCC)が必要。初回起動でオンボーディング。
- Sandbox 対応(App Store 配布時)。ScreenCaptureKit は sandbox 内でも entitlement で可。

## 5. フェーズ(詳細は 30)
- Phase D1: Core 層 SPM 切り出し + macOS の最小ファイル一覧(CloudKit 同期の read のみ)
- Phase D2: 会議音声キャプチャ + ローカル保存
- Phase D3: 文字起こし・要約(API 経路)
- Phase D4: 双方向クラウド同期の完成
