# Memora PLAUDnote-style Product Blueprint & Execution Plan

最終更新: 2026-04-03

## 1. 目標プロダクト

Memora を **「PLAUD Note のように録るだけで整理される体験」** を中核にした、
**local-first の会議OS** に再定義する。

目標は以下の 4 本柱。

1. **Capture Anywhere**
   - iPhone 録音
   - 音声ファイル import
   - PLAUD export import
   - Omi import
   - オンライン会議 capture
   - Apple Watch recording

2. **Reliable Transcription**
   - local-first
   - SpeechAnalyzer 優先
   - 端末/locale/asset 非対応時は安全に fallback
   - クラッシュしないことを最優先

3. **Actionable Workspace**
   - 録音詳細ページは `要約 / 文字起こし / メモ` タブ
   - メモは Markdown
   - 写真添付
   - ToDo 自動抽出 + AI タスク分解
   - Notion / OpenAI 系への外部蓄積

4. **Personal AI**
   - AskAI は `file / project / global`
   - 使うほど個人化される memory
   - 無料ユーザーは local 保存
   - 有料ユーザーは CloudKit sync

---

## 2. current repo から見た現状

### 2.1 すでにある土台
- `docs/v1-product-design.md` は current truth として、録音、音声 import、ローカル/API 文字起こし、要約、話者分離、プロジェクト、Plaud import、Omi 連携、ToDo まで `done` 扱い。  
- `ContentView` には FAB、通常音声 import、Plaud import、Omi import 導線がある。  
- `AskAIView` は `.file / .project / .global` の scope を持つ。  
- `OnboardingView` は既に 4 ページの初期オンボーディング UI を持つ。  
- `ProcessingJob` モデルは存在する。  

### 2.2 まだ不足している product path
- `ContentView` はまだ `BluetoothAudioService` と `OmiAdapter` を起動時に生成し、`repositoryFactory` 経路も残る。起動時コストと保存経路のノイズがある。  
- `FileDetailView` は `SummaryView` / `TranscriptView` への別画面遷移中心で、`要約 / 文字起こし / メモ` のタブ構成ではない。  
- `AudioFile` は `summary / keyPoints / actionItems / referenceTranscript` は持つが、写真添付や Markdown メモ本体は持っていない。  
- `MeetingNote` は `summary / decisions / actionItems` だけで、Markdown note ではない。  
- `AskAIView` は scope UI を持つが、コード上見える取得関数は `fetchTranscript(for fileId:)` で、file context が中心。  
- `ProcessingJob` は存在するが、`PipelineCoordinator` 側には visible path でまだ結合されていない。  
- `MemoraApp` は `ModelContainer` 初期化に 5 秒タイムアウトを置き、タイムアウト時は in-memory の temporary store にフォールバックする。これは起動失敗耐性には効くが、初回起動の重さと「保存されたように見えて保存されない」体験の温床にもなる。  

---

## 3. 外部仕様と現実的な実装方針

### 3.1 SpeechAnalyzer を mainline にしたい
Apple の新しい Speech 系では、`SpeechAnalyzer` 利用前に `SpeechTranscriber.isAvailable` や locale 可否、`AssetInventory` による asset 状態確認、`bestAvailableAudioFormat(...)` による入力フォーマット整合を取るのが正しい。ここを飛ばすと不安定化しやすい。  
**方針:** `SpeechAnalyzer = 即使用` ではなく、**preflight 付きの安全な mainline** にする。  

### 3.2 オンライン会議を low-ops でカバーしたい
Google Calendar API の push 通知は通知チャネルの設定が必要で、サーバー寄りの構成になる。Google Meet REST API は会議後に録画・文字起こしアーティファクトを取得できるが、アーティファクトは会議終了前に有効化されている必要がある。  
**方針:**
1. **Phase 1**: EventKit で「端末に見えている予定」を読む。  
2. **Phase 2**: Google Meet の post-meeting artifact import。  
3. **Phase 3**: macOS companion / browser helper によるローカル録音。  
4. **Phase 4**: bot recorder は最後。  

### 3.3 Apple Watch 録音
`AVAudioRecorder` は watchOS 4.0+ で使え、`AVAudioSession` / `AVAudioEngine` も watchOS で利用できる。  
**方針:**
1. まず Watch から iPhone 録音を遠隔操作。  
2. その後 standalone watch recording。  
3. 文字起こしは watch 上ではなく iPhone 側 pipeline で行う。  

### 3.4 AskAI は RAG か
**結論:** `file` は厳密な RAG でなくてもよい。`project / global` は retrieval が必要。  
ただし最初から重い vector DB に行かない。  
**方針:**
- Phase 1: local lexical retrieval（chunk + keyword + metadata rank）
- Phase 2: optional embeddings（有料 / cloud sync ユーザー中心）

### 3.5 ChatGPT / OpenAI 連携
OpenAI の ChatGPT memory はユーザー管理の概念であり、ChatGPT には外部アプリから「ユーザー個人の memory を直接書き込むための一般的な公開手順」は見当たらない。OpenAI 公式には、ChatGPT 側で外部データを参照するための Apps/Connectors と、API 側で file inputs / MCP を使う道がある。  
**方針:**
- Notion: 正式 API 連携
- ChatGPT: 「個人 memory へ直接書く」のではなく、**OpenAI API export** か **Memora を MCP / ChatGPT app 的に参照させる** 方針にする

### 3.6 無料 local / 有料 cloud
SwiftData は CloudKit sync を扱え、CloudKit 側は `CKAsset` で音声や画像ファイルを持てる。  
**方針:**
- Free: SwiftData + local files（Application Support）
- Paid: SwiftData + CloudKit sync、音声/画像は asset 扱い
- 自前バックエンドは当面作らない

---

## 4. 情報設計（target IA）

## 4.1 メインタブ
- **Inbox**: すべての録音・import ファイル
- **Projects**: プロジェクト単位の整理
- **Tasks**: AI 抽出 + 手動作成 + AI 分解
- **Settings**: provider / integrations / account / sync / device

## 4.2 録音ファイル詳細ページ
**PLAUD Note 風の中心体験にする。**

ヘッダ:
- タイトル
- 日時 / 時間
- プロジェクト
- 参加者 / 話者サマリ
- カレンダーイベント link（ある場合）
- 写真プレビュー strip

本文:
- `Summary` タブ
- `Transcript` タブ
- `Memo` タブ

下部アクション:
- Ask AI
- Export
- Notion へ送る
- OpenAI へ送る
- タスク抽出

### Summary タブ
- 1画面で読める executive summary
- 決定事項
- action items
- AI 分解タスク候補
- 添付写真の OCR 要約（存在する場合）

### Transcript タブ
- speaker chips
- 検索
- クリックで再生位置ジャンプ
- Plaud reference transcript がある場合は比較トグル

### Memo タブ
- Markdown editor
- チェックリスト
- 見出し
- 引用
- 音声の現在再生位置から「この位置へのメモリンク」追加
- 写真をメモ内参照可能にする

## 4.3 Project 詳細
- Overview
- Files
- Tasks
- Ask AI（project scope）

## 4.4 Global Ask AI
- 全プロジェクト対象
- 直近会議横断の質問
- 個人 memory を反映

---

## 5. データモデル v2

既存モデルを全破壊しない。下記を追加中心で進める。

### 5.1 `MeetingMemo`
```swift
@Model
final class MeetingMemo {
    var id: UUID
    var audioFileID: UUID
    var markdown: String
    var plainTextCache: String
    var createdAt: Date
    var updatedAt: Date
}
```

用途:
- `Memo` タブの canonical source
- Markdown 本文
- retrieval / export / external sync の基点

### 5.2 `PhotoAttachment`
```swift
@Model
final class PhotoAttachment {
    var id: UUID
    var ownerType: String   // audioFile / project / memo
    var ownerID: UUID
    var localPath: String
    var thumbnailPath: String?
    var caption: String?
    var ocrText: String?
    var createdAt: Date
    var updatedAt: Date
}
```

用途:
- 音声ファイル単位の写真
- プロジェクト写真
- OCR による AskAI context 化

### 5.3 `KnowledgeChunk`
```swift
@Model
final class KnowledgeChunk {
    var id: UUID
    var scopeType: String   // file / project / global
    var scopeID: UUID?
    var sourceType: String  // transcript / summary / memo / todo / photoOCR / referenceTranscript
    var sourceID: UUID?
    var text: String
    var keywords: [String]
    var rankHint: Double
    var createdAt: Date
    var updatedAt: Date
}
```

用途:
- local-first retrieval
- 最初は embedding なしで運用可

### 5.4 `AskAISession` / `AskAIMessage`
```swift
@Model
final class AskAISession {
    var id: UUID
    var scopeType: String
    var scopeID: UUID?
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

@Model
final class AskAIMessage {
    var id: UUID
    var sessionID: UUID
    var role: String
    var content: String
    var citationsJSON: String?
    var createdAt: Date
}
```

用途:
- file / project / global chat の会話ログ
- 将来の memory 抽出入力

### 5.5 `MemoryProfile` / `MemoryFact`
```swift
@Model
final class MemoryProfile {
    var id: UUID
    var summaryStyle: String?
    var preferredLanguage: String?
    var roleLabel: String?
    var glossaryJSON: String?
    var createdAt: Date
    var updatedAt: Date
}

@Model
final class MemoryFact {
    var id: UUID
    var profileID: UUID
    var key: String
    var value: String
    var source: String
    var confidence: Double
    var lastConfirmedAt: Date?
}
```

用途:
- 「この人はこう要約してほしい」「よく使う用語」などを蓄積
- ユーザーが編集 / 削除可能にする

### 5.6 `CalendarEventLink`
```swift
@Model
final class CalendarEventLink {
    var id: UUID
    var provider: String     // eventkit / google
    var externalID: String
    var title: String
    var startAt: Date
    var endAt: Date
    var meetingURL: String?
    var conferenceProvider: String?
    var artifactState: String?
    var audioFileID: UUID?
}
```

### 5.7 `IntegrationDestination`
```swift
@Model
final class IntegrationDestination {
    var id: UUID
    var type: String     // notion / openaiExport / webhook
    var name: String
    var configJSON: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

### 5.8 `SubscriptionState` / `UserAccount`（後半）
- local-only / cloud-enabled の状態管理
- paid gating
- sign in state

---

## 6. アーキテクチャ方針

## 6.1 Speech / STT

### backend order
1. `SpeechAnalyzerBackend`（preflight 済み時のみ）
2. `SFSpeechRecognizerBackend`
3. `CloudSTTBackend`

### SpeechAnalyzer preflight 必須項目
- availability check
- locale equivalence check
- asset status / install request
- compatible audio format selection
- structured timeout / fallback reason logging
- crash-safe diagnostics

### diagnostics
- 使用 backend
- locale
- asset state
- audio format
- fallback reason
- 平均処理時間

## 6.2 Retrieval / AskAI

### file scope
- transcript
- summary
- memo markdown
- reference transcript
- photo OCR

### project scope
- project 配下のすべての files
- project tasks
- project memo chunks

### global scope
- 全 project + 全 file
- recency rank
- personal memory rank boost

### retrieval 方法
Phase 1:
- chunking
- keyword index
- metadata filters
- recency + scope + sourceType で rerank

Phase 2:
- embeddings optional
- paid/cloud users 向け

## 6.3 Memory
- AskAI の会話から「保存して良い preference / glossary / persona」を抽出
- 自動抽出は候補として提示
- ユーザー承認後に profile へ保存
- memory は常に編集 / forget 可能にする
- free は local, paid は cloud sync

## 6.4 Storage tier

### free
- SwiftData local
- 音声 / 画像 / OCR キャッシュは Application Support
- API key も local

### paid
- SwiftData + CloudKit sync
- 音声 / 画像は CKAsset
- account / subscription / sync status 追加

## 6.5 External integrations

### Notion
- 1 summary = 1 page
- transcript 折りたたみ block
- action items は checklist blocks
- memo は markdown → rich text 変換または code/plain block

### OpenAI / ChatGPT 側
- consumer ChatGPT memory へ直接書き込もうとしない
- 代わりに:
  - OpenAI API に file input として渡せる export
  - 将来的に Memora を MCP server / ChatGPT app 化

---

## 7. オンライン会議カバー戦略

## 7.1 原則
**「bot で全部録る」を最初にやらない。**
low-ops を優先する。

## 7.2 実装順

### Phase 1: EventKit
- 予定一覧
- 予定詳細から録音開始導線
- `calendarEventId` を活用
- 会議 URL を file に紐付け

### Phase 2: Google Meet artifact import
- Google Meet の録画 / transcript / transcript entries を会議後に取得
- 録画は organizer の Drive 側成果物を参照
- transcript entries は retention 制約があるので import 後すぐ保存

### Phase 3: macOS companion / browser helper
- system audio + mic capture
- Zoom / Meet / Teams の共通カバー
- server 不要で広く使える

### Phase 4: bot recorder（experimental）
- provider ごとに別実装
- 利用規約、権限、通知、運用コストが増える
- paid の上位機能候補

---

## 8. Apple Watch 方針

### Phase 1: Remote recording
- Watch で start / pause / stop
- レベルメータ
- 残時間
- 会議名 quick preset

### Phase 2: Standalone watch recording
- Watch 単体で録音
- iPhone へ転送
- iPhone で文字起こし

### Phase 3: Fast capture UX
- コンプリケーション
- 最近プロジェクトに即紐付け
- ワンタップ録音

---

## 9. TODO 機能方針

既存 `TodoItem` は保持しつつ、AI planner を追加する。

### 9.1 入口
- transcript から抽出
- summary から抽出
- memo から抽出
- AskAI 会話から抽出
- 手動作成

### 9.2 AI 分解
入力:
- タスク本文
- 会議コンテキスト
- プロジェクトコンテキスト
- メモリ（担当者や好み）

出力:
- 親タスク
- サブタスク
- 優先度
- 担当候補
- 期限候補
- 根拠 citations

### 9.3 UI
- 「AIで分解」ボタン
- 生成されたサブタスクを accept / edit / discard
- project / assignee / due date へ一括反映

---

## 10. 初回起動が重い問題の解決方針

### 現状の怪しい箇所
- `ContentView` で `BluetoothAudioService` と `OmiAdapter` を起動時生成している
- `ModelContainer` 初期化に 5 秒 timeout があり、遅いと in-memory fallback へ行く
- import / device / query が launch path に近い

### 方針
1. Omi / Bluetooth は Settings または DeviceConnection へ lazy init
2. launch screen では最新 20 件だけを読む軽量 query
3. waveform / audio duration / chunk index 再計算は背景処理へ送る
4. initial STT assets check は初回 render 後に background warm-up
5. home のサムネイル / summary 生成は遅延読み込み
6. temporary store fallback は維持するが、UI 上で強く警告し「保存されません」を明示

---

## 11. デザイン方針

目標は **Liquid Glass + Manus / ChatGPT ライクな落ち着いた AI ワークスペース**。

### 原則
- glass は chrome に使う
- content は可読性優先
- 情報密度は高いが空気感は軽く
- 白/黒のコントラストをベースに、accent は 1〜2 色
- FAB や segmented control は有機的な morph を使う

### ルール
- 上部ナビ、tab、floating controls に Liquid Glass
- transcript / summary / memo 本文面は solid surface 優先
- blur/transparency は「意味があるときだけ」
- dark mode 先行で設計し、light は後追いでもよい

### スクリーン優先度
1. Home / Inbox
2. File Detail
3. AskAI
4. Project Detail
5. Settings / Integrations
6. Onboarding / Paywall

---

## 12. 実行順（Claude Code / Codex）

## Phase A: 安定化と土台

### CL-A1 — SpeechAnalyzer hardening
**担当:** Claude Code
- SpeechAnalyzer preflight
- AssetInventory / locale / format / timeout 対応
- STT crash-safe path
- diagnostics logging

### CO-A2 — STT backend settings / diagnostics UI
**担当:** Codex
- backend status panel
- asset status panel
- last fallback reason
- test transcription diagnostics

### CL-A3 — launch performance refactor
**担当:** Claude Code
- lazy service init
- launch query 軽量化
- fallback UX 明示

### CO-A4 — File detail tabs shell
**担当:** Codex
- `Summary / Transcript / Memo` segmented tabs
- 既存 SummaryView / TranscriptView の中身を埋め込む
- Memo タブ placeholder

## Phase B: メモ・写真・知識基盤

### CL-B1 — Data model v2
**担当:** Claude Code
- `MeetingMemo`
- `PhotoAttachment`
- `KnowledgeChunk`
- `AskAISession` / `AskAIMessage`
- `MemoryProfile` / `MemoryFact`

### CO-B2 — Markdown memo + photo UI
**担当:** Codex
- Memo editor
- PhotosPicker
- photo gallery strip
- photo preview

### CL-B3 — OCR + chunk indexing pipeline
**担当:** Claude Code
- OCR service
- memo / summary / transcript / photoOCR の chunk 化
- local retrieval engine

### CO-B4 — AskAI file/project/global wiring
**担当:** Codex
- scope selector
- session list
- citations chips
- source badges

### CL-B5 — memory extraction + policy
**担当:** Claude Code
- memory candidate extraction
- user approval flow model
- memory rank boost

### CO-B6 — memory settings UI
**担当:** Codex
- saved memory list
- edit / delete / disable memory
- privacy modes

## Phase C: Task intelligence

### CL-C1 — AI task planner service
**担当:** Claude Code
- task extraction normalization
- task decomposition service
- citations / rationale 付き提案

### CO-C2 — Task breakdown UI
**担当:** Codex
- "AIで分解" UI
- accept / edit / discard
- parent / subtasks 表示

## Phase D: capture everywhere

### CL-D1 — Plaud audio + metadata import complete
**担当:** Claude Code
- 音声同時 import
- metadata merge
- reference transcript + audio 共存

### CO-D2 — photo on audio/project polish
**担当:** Codex
- attach from detail/project
- reorder / delete / caption edit

### CL-D3 — EventKit calendar link
**担当:** Claude Code
- `CalendarEventLink`
- event import
- audioFile <-> event association

### CO-D4 — Calendar UI
**担当:** Codex
- upcoming meetings list
- link/unlink UI
- meeting detail card

### CL-D5 — Google Meet artifact import
**担当:** Claude Code
- meet conference record import
- transcript / recording metadata save
- retention-aware ingest

### CO-D6 — online meeting inbox UI
**担当:** Codex
- imported meeting artifact cards
- pending / completed / failed states

### CL-D7 — Watch remote recording
**担当:** Claude Code
- WatchConnectivity
- remote start/stop/pause
- project preset handoff

### CO-D8 — Watch companion UI
**担当:** Codex
- big record button
- timer / level / recent project UI

### CL-D9 — standalone watch recording sync
**担当:** Claude Code
- watch local file save
- transfer to iPhone
- iPhone import hook

## Phase E: external sinks

### CL-E1 — Notion integration service
**担当:** Claude Code
- page create
- block append
- summary / transcript / todo export mapping

### CO-E2 — integrations UI
**担当:** Codex
- destination list
- connect / test / export now

### CL-E3 — OpenAI export / MCP spec
**担当:** Claude Code
- OpenAI API file export target
- future MCP server design
- user-facing limitations doc

### CO-E4 — OpenAI export UI
**担当:** Codex
- manual export
- export status
- failed retry UI

## Phase F: monetization / account

### CL-F1 — storage tier architecture
**担当:** Claude Code
- free local / paid cloud rules
- CloudKit model mapping
- asset sync policy

### CO-F2 — onboarding v2 / paywall shell
**担当:** Codex
- current onboarding refresh
- pricing sheet
- premium badge / locked features

### CL-F3 — auth flows
**担当:** Claude Code
- Sign in with Apple
- Google Sign-In
- account linking strategy

### CO-F4 — account & sync UI
**担当:** Codex
- sign-in screens
- sync status
- storage usage

## Phase G: design refresh

### CL-G1 — design system spec refresh
**担当:** Claude Code
- liquid glass usage rules
- layout tokens
- motion rules

### CO-G2 — screen-by-screen redesign
**担当:** Codex
- Home
- File Detail
- AskAI
- Projects
- Settings

---

## 13. Claude Code / Codex の運用ルール

### 共通
- 1 セッション 1 タスク
- 計画書を読み、**自分のレーンの次の未完了タスクだけ**実装する
- broad rewrite 禁止
- 変更前に対象ファイルと非対象ファイルを宣言
- 完了後は必ず `次に依存しているタスク` を報告する

### Claude Code に向いているもの
- architecture
- services
- model changes
- retrieval / memory / sync / auth / calendar / watch connectivity

### Codex に向いているもの
- views
- editor UI
- settings UI
- diagnostics UI
- tabs / cards / paywall / onboarding polish

---

## 14. 直近の実行開始点

### まず最初にやること
1. **Claude Code: CL-A1**
2. **Codex: CO-A2**（CL-A1 のブランチ内容を踏まえて調整）
3. **Claude Code: CL-A3**
4. **Codex: CO-A4**

### その次
5. **Claude Code: CL-B1**
6. **Codex: CO-B2**
7. **Claude Code: CL-B3**
8. **Codex: CO-B4**

ここまで終わると、
- STT crash 減少
- File detail が PLAUDnote ライクに寄る
- Markdown memo
- 写真
- file/project/global AskAI の基盤
までが揃う。

---

## 15. 受け入れ基準（product-level）

### A. 安定性
- 文字起こし開始で落ちない
- backend 切替理由が分かる
- 初回起動でフリーズ感が減る

### B. PLAUDnote 体験
- 1つのファイル画面で Summary / Transcript / Memo が切り替わる
- 写真を添付できる
- メモが Markdown で書ける

### C. AskAI
- file / project / global が本当に動く
- citations が見える
- メモリを使う / 消すをユーザーが管理できる

### D. 行動化
- 会議からタスク抽出できる
- AI がサブタスクに分解できる

### E. capture everywhere
- iPhone / import / Plaud / Omi / online meeting / watch の各導線が揃う

### F. 収益化
- free local / paid cloud の差が明確
- sign in / onboarding / paywall が自然に繋がる

