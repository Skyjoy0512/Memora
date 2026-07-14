# Memora デバイス連携 & デスクトップ拡張 設計パッケージ

作成日: 2026-07-05 / 対象: `Skyjoy0512/Memora`
対象読者: 実装エージェント(Claude Code / Codex / DeepSeek)+ 人間レビュアー

この2つの要望を、調査に基づいて実装可能な設計に落としたものです:

1. **AI レコーダーのペアリング** — PLAUD / Omi / その他 BLE レコーダーを BLE・Wi-Fi で Memora に接続
2. **デスクトップアプリ** — PLAUD デスクトップのように Zoom 等のオンライン会議を PC で録音 → クラウド同期 → 文字起こし・要約(無料/有料の2系統)

---

## ドキュメント一覧

| # | ファイル | 概要 |
|---|---|---|
| 00 | `00_README.md` | 本ファイル。全体像と重要な調査結論 |
| 10 | `10_device_pairing_overview.md` | デバイス連携の全体設計。BLE/Wi-Fi 接続アーキテクチャ、対応方針、法的注意 |
| 11 | `11_omi_ble_integration.md` | **Omi デバイス連携の完全実装**(UUID・パケット形式・Opus デコード・Swift 実装) |
| 12 | `12_plaud_integration.md` | PLAUD 連携。公式 SDK 経由(正規)と既存「参照 transcript」方式の設計 |
| 13 | `13_generic_recorder_and_wifi.md` | 汎用 BLE レコーダー + Wi-Fi/インポート経路、デバイス抽象化レイヤ |
| 20 | `20_desktop_app_overview.md` | デスクトップアプリのアーキテクチャ選定(macOS ネイティブ vs Electron)とクラウド同期 |
| 21 | `21_desktop_meeting_capture.md` | Zoom 等の会議音声キャプチャの技術実装(ScreenCaptureKit / システム音声) |
| 22 | `22_transcription_tiers.md` | 文字起こし・要約の無料/有料2系統(Gemini・Chrome内蔵AI・ローカル・API) |
| 23 | `23_cloud_sync.md` | クラウド同期の設計(CloudKit / 自前バックエンド)とデバイス間整合 |
| 30 | `30_roadmap_and_phasing.md` | 実装フェーズ・優先度・PR 分割・工数感 |

---

## 最重要の調査結論(設計の前提)

### デバイス連携について

1. **Omi は完全にオープン**。BLE UUID・パケット形式・コーデックが公式ドキュメントと GitHub(`BasedHardware/omi`)で公開されている。**そのまま実装できる**(11 に完全な仕様)。
   - Audio Service: `19B10000-E8F2-537E-4F6C-D104768A1214`
   - Audio Data 特性: `19B10001-...`(notify)/ Codec Type 特性: `19B10002-...`(read)
   - コーデックは Opus が主流(要 Opus デコーダ)。PCM/µ-law のデバイスもある。
   - 標準 Battery Service(`0x180F`)/ Device Info(`0x180A`)対応。

2. **PLAUD はクローズド**。利用規約(dev.plaud.ai/terms)で **リバースエンジニアリング・競合 AI ノートアプリ開発での SDK 利用を明示的に禁止**。したがって:
   - ⚠️ PLAUD の BLE プロトコルを解析して直接繋ぐのは規約違反リスク。**推奨しない**。
   - ✅ 正規ルートは **PLAUD Embedded SDK(B2B)**(`Plaud-AI/plaud-sdk-public`)。ただし競合アプリ制限があるため利用可否は要確認。
   - ✅ 現実的な当面の解: 既存 Memora が持つ「参照 transcript(Plaud)」インポート方式の維持・強化(12 参照)。
   - この判断は 12 に詳述。実装エージェントは PLAUD 直接 BLE 解析を**やってはいけない**。

3. **その他 AI レコーダー**は Omi の統合手法(BLE スニッフィング → UUID 特定 → コーデック判定)がそのまま応用可能。汎用デバイス抽象化レイヤを設ければ順次追加できる(13)。既存 `BluetoothAudioService.swift` は「汎用 BLE デバッグパス」として実装済みで、これを土台にできる。

### デスクトップアプリについて

4. **会議音声のキャプチャ**は OS レベルのシステム音声取り込みが必要。macOS は **ScreenCaptureKit**(macOS 13+)でアプリ音声を合法的に取得できる。Omi 自身も macOS アプリ(Swift/Rust)を持つ。
5. **クラウド同期**は2案: (a) Apple **CloudKit**(iOS と同一 Apple ID、追加バックエンド不要、無料枠大)、(b) 自前バックエンド(既存 bot-server 資産、プラットフォーム自由だが運用コスト)。**iOS が SwiftData 主体なので CloudKit + SwiftData 同期を第一候補**とする(23)。
6. **文字起こし・要約の無料/有料**:
   - 無料: iOS 26 SpeechAnalyzer / SFSpeechRecognizer(オンデバイス、既存)、**Gemini Flash 系 API 無料枠**(1,500 req/日、音声入力対応。ただし入力がGoogleの学習に使われる)。
   - 有料・高品質: OpenAI `gpt-4o-transcribe` / `whisper-1`(既存)、Gemini 有料 Flash/Pro、要約は Claude/GPT/Gemini Pro。
   - ⚠️ **「Gemini in Chrome」= ブラウザの AI 機能であり、アプリから叩ける公開 API ではない**。プログラムから使うのは **Gemini API(AI Studio のキー)**。デスクトップが Electron/Web なら Chrome の組み込み AI(`window.ai` / Prompt API)も選択肢になるが STT 用途には非対応が多い。詳細は 22。

### 現状コードの重要事実(確認済み)

- `BluetoothAudioService.swift`(636行)実装済み。汎用スキャン・接続・全特性 notify 購読・WAV 保存まで動く。ただし Omi/PLAUD 固有プロトコル(コーデック判定・パケットヘッダ処理)は未実装。デバイス種別は名前文字列での推定のみ。
- `AIProvider`: `openai / gemini / deepseek / local`。**`supportsTranscription` は openai のみ true**(Gemini/DeepSeek は要約のみ)。→ 22 で Gemini 文字起こし対応を追加する。
- `TranscriptionMode`: `local / api`。
- 「参照 transcript(Plaud)」は `AudioFile.referenceTranscript` / `referenceSpeakerCount` として実装済み(Plaud Toolkit 互換 API 経由)。

## 法的・倫理的注意(全ドキュメント共通)

- **PLAUD 独自 BLE の解析・偽装接続は行わない**(規約違反)。正規 SDK かインポート方式のみ。
- **会議録音は各地域の通話・会議録音法**(一方当事者同意/全当事者同意)に従う必要がある。アプリは録音前に同意取得を促す UI を持つべき(21 に記載)。
- Zoom 等の**利用規約**でボット/自動録画が制限される場合がある。システム音声キャプチャ(画面共有系)は比較的中立だが、参加者への録音通知は実装する。
- Gemini 無料枠は入力データが Google の学習に使われる。**機微な会議には無料枠を使わない**警告を UI に出す(22)。
