# 24. デスクトップ並行開発 戦略設計

対象: iOS と macOS を並行で進めるためのプロジェクト構成
目的: 「デスクトップアプリも並行して作りたい」を、iOS 開発を止めずに実現する

---

## 1. 並行開発を可能にする鍵 = Core 層の共有パッケージ化

iOS と macOS を別々に作ると二重実装になる。**ビジネスロジックを1つの SPM パッケージ**にまとめ、iOS と macOS の両アプリがそれを使う構成にすると、片方の改善が両方に効く。

```
Memora (リポジトリ)
├── MemoraCore/                    ← 新規 SPM パッケージ(iOS/macOS 共有)
│   ├── Models/                    (AudioFile, Transcript, Project, ToDo … SwiftData)
│   ├── Transcription/             (STT ロジック、チャンカー、マージ器 … 14 の成果)
│   ├── AI/                        (AIService, 要約, プロバイダ … 22 の成果)
│   ├── Sync/                      (CloudSyncService … 23)
│   └── Devices/                   (RecorderDevice 抽象 … 10-13、iOS のみ有効な部分は #if os(iOS))
│
├── Memora-iOS/ (既存アプリ)        ← MemoraCore に依存、UI は iOS 専用
│   └── Views/, ViewModels/ …
│
└── Memora-macOS/ (新規)            ← MemoraCore に依存、UI は macOS 専用
    └── Views/, Capture/(21) …
```

## 2. 並行開発の進め方(iOS を止めない)

### 2.1 段階的な切り出し(ビッグバンにしない)
Core 全体を一気に切り出すと既存 iOS が長期間ビルド不能になる。**モジュール単位で少しずつ**移す:

| 順 | 切り出すモジュール | リスク | 備考 |
|---|---|---|---|
| 1 | Models(SwiftData) | 中 | 最初。CloudKit 対応(23)と同時にやると効率的 |
| 2 | AI(要約・プロバイダ) | 低 | UI 依存が薄い |
| 3 | Transcription(STT) | 高 | `UIApplication` 依存を `#if os(iOS)` で隔離。14/02 の改修後に |
| 4 | Sync / Devices | 低〜中 | 新規なので最初から Core に置く |

各ステップで iOS がビルド・動作することを確認してから次へ。

### 2.2 プラットフォーム差の隔離
Core 内で iOS/macOS が違う箇所は `#if os(iOS)` / `#if os(macOS)` で分岐。特に:
- STT のバックグラウンドタスク(`UIApplication.beginBackgroundTask`)→ iOS のみ。macOS は不要(プロセスが生きている)。
- `isIdleTimerDisabled` → iOS のみ。macOS は `IOPMAssertion`(スリープ防止)を使う。
- SpeechAnalyzer/SFSpeech → iOS/macOS 両方あるが可用性が違う。
- 音声キャプチャ → macOS は ScreenCaptureKit(21)、iOS は AVAudioSession。

```swift
// Core 内の抽象例
protocol BackgroundExecutionGuard {
    func begin(name: String) -> Any?
    func end(_ token: Any?)
    func preventSleep()
    func allowSleep()
}
// iOS 実装: UIApplication ベース / macOS 実装: IOPMAssertion ベース
```

### 2.3 チーム/エージェントの割り当て
- **トラック A(iOS 継続)**: 先の P0 改修(02/14)、画面遷移(01)、Gemini(22)。既存アプリで価値を出し続ける。
- **トラック B(Core 切り出し)**: 2.1 の順でモジュールを Core へ。A の改修が一段落したモジュールから移す(改修中のファイルを動かすと衝突するため)。
- **トラック C(macOS 新規)**: Core の Models が切り出せた時点で macOS アプリ雛形を開始。Capture(21)は Core 非依存で先行着手可能。

依存関係: **A(02/14) → B(Transcription 切り出し) → C(macOS で STT 利用)**。ただし macOS の会議キャプチャ(21)と UI 雛形は Core 完成を待たず並行できる。

## 3. macOS アプリ雛形の最小構成(先行着手可能な部分)

Core を待たずに始められるもの:
- macOS アプリのプロジェクト作成(XcodeGen で iOS と同一リポジトリに target 追加)。
- ScreenCaptureKit の音声キャプチャ実証(21)。これは Core 非依存で単体で作れる。
- ウィンドウ/メニュー/サイドバーの SwiftUI 骨格。

Core 完成後に接続するもの:
- ファイル一覧(Models 同期)、文字起こし・要約(Transcription/AI)、双方向同期(Sync)。

## 4. XcodeGen での macOS ターゲット追加

`project.yml` に macOS ターゲットと共有パッケージを追加(■確認: 既存 project.yml の構造)。

```yaml
packages:
  MemoraCore:
    path: ./MemoraCore

targets:
  Memora:               # 既存 iOS
    platform: iOS
    dependencies:
      - package: MemoraCore

  Memora-macOS:         # 新規
    platform: macOS
    deploymentTarget: "14.0"   # ScreenCaptureKit の音声は 13+、Core Audio Tap は 14.4+
    sources: [Memora-macOS]
    dependencies:
      - package: MemoraCore
    entitlements:
      # ScreenCapture, microphone, app sandbox, iCloud/CloudKit
```

## 5. 並行開発のリスクと緩和

| リスク | 緩和 |
|---|---|
| Core 切り出しが既存 iOS を壊す | モジュール単位で段階移行、各段でビルド確認。02/14 の改修完了後に着手 |
| iOS 依存(UIApplication 等)が macOS で壊れる | `#if os` 抽象化、Core は UIKit を直接 import しない設計 |
| SwiftData モデルが CloudKit 制約に非適合 | 23 の制約対応(optional/既定値)を Models 切り出しと同時に |
| 二重メンテの再発 | UI 以外は必ず Core に置くルール。ロジックを View に書かない |
| macOS 固有 API の学習コスト | ScreenCaptureKit(21)は独立実証から入る |

## 6. 「今すぐ並行で始められること」チェックリスト

- [ ] macOS ターゲットを project.yml に追加(空のウィンドウが起動)
- [ ] ScreenCaptureKit 音声キャプチャの単体実証(21 の SystemAudioCapturer)
- [ ] MemoraCore パッケージの器を作り、まず Models を移す(23 の CloudKit 対応と同時)
- [ ] iOS 側は 02/14(STT 安定化・長時間対策)を継続 — これが Core の Transcription 切り出しの前提

## 7. まとめ

- 並行開発の本質は **Core 層の共有パッケージ化**。二重実装を避ける。
- **段階移行**で iOS を止めない。02/14 の P0 改修 → Transcription 切り出し → macOS 接続、の順。
- **Core 非依存の部分(ScreenCaptureKit 実証、macOS 雛形)は今すぐ並行で着手できる**。
- 詳細な機能設計は 20〜23、実装順は 30 を参照。
