# Memora Claude-First Autodrive Execution Design

## 0. Goal
この文書は、Memora の次フェーズ開発を **Claude Code 主体 / Codex 補助 / 並列稼働前提** で自走させるための実行設計書です。
最優先は **文字起こしクラッシュの解消** です。新機能よりも先に、STT を「落ちない・詰まらない・状態が見える」形に安定化します。

この計画は、いまの codebase の実態を前提にしています。
- `docs/v1-product-design.md` が current truth
- `CLAUDE.md` が current rules
- STT コアは `docs/transcription-core-boundary.md` の保護対象

## 1. Current Truth Audit（この plan が前提にする現在地）

### 1-1. すでに揃っているもの
- `FileDetailViewModel` は `PipelineCoordinator` と `KnowledgeIndexingService` を持っており、パイプライン委譲と知識インデックス更新の基盤がある
- `PhotoAttachment` モデルが存在し、`ownerType / ownerID / localPath / thumbnailPath / caption / ocrText` を保持できる
- `MeetingMemo` モデルが存在し、Markdown と `plainTextCache` を保持できる
- `KnowledgeChunk` と `KnowledgeIndexingService` が存在し、`transcript / summary / memo / todo / photoOCR / referenceTranscript` を index できる

### 1-2. まだ product path になっていないもの
- `FileDetailView` は「文字起こし結果を表示」「要約結果を表示」ボタン導線で、Summary / Transcript / Memo の常設タブ導線になっていない
- `AskAIView` は `.file / .project / .global` の scope UI を持つが、取得ヘルパーは `fetchTranscript(for fileId:)` が visible truth で、project/global retrieval は未完成前提で扱う
- `AudioFileImportService` はまだ `repositoryFactory: RepositoryFactory? = nil` を受けており、SwiftData 一本化が終わりきっていない
- `MemoraApp` は ModelContainer 初期化 5 秒タイムアウト時に in-memory store へフォールバックする

### 1-3. いま最優先で潰すべき危険箇所
- `STTSupportTypes.swift` に **SpeechAnalyzer はデフォルト OFF（EXC_BREAKPOINT 回避）** と明記されている
- `STTService` は `SpeechAnalyzerFeatureFlag` が ON のときのみ SpeechAnalyzer を試し、その後 fallback で `SFSpeechURLRecognitionRequest.requiresOnDeviceRecognition = true` を強制している
- つまり今の local STT は **SpeechAnalyzer は危険、legacy も強め制約** という状態で、クラッシュ・失敗・端末差異に弱い

## 2. Non-Negotiables
- 最優先は STT crash stabilization
- broad rewrite 禁止
- 1 PR = 1責務
- 依存関係を超えて先走らない
- STT コア変更は `docs/transcription-core-boundary.md` の制約を守る
- Local mode では勝手にサーバー STT に切り替えない
- free/local 前提を壊さない

## 3. Claude-First Parallel Operating Model

### 3-1. 役割
**Claude Code**
- アーキテクチャ、STT、起動性能、状態機械、RAG/Memory、Pipeline/Recovery を担当
- 触る量が多く、依存関係の中心にいるタスクを優先
- 進められる ready task がある限り、同一セッションで連続実行してよい

**Codex**
- UI コンポーネント、診断 UI、テスト、軽量 integration、ドキュメント追従を担当
- STT コアを直接変更しない
- Claude が定義した service contract / state contract に乗る

### 3-2. 並列セッション想定
- Claude-A: STT / SpeechAnalyzer hardening lane
- Claude-B: Launch performance / app initialization lane
- Claude-C: File detail tab experience lane
- Codex-S: diagnostics UI / tests / support lane

### 3-3. タスク選択ルール
1. `docs/agent-status-board.md` を読む
2. 自分の owner のうち `READY` な最上位タスクを claim する
3. claim 前に touched files が他タスクと衝突していないか確認する
4. 実装前に「現状理解 / 変更対象 / 変更しない対象 / 実装方針」を宣言する
5. 実装後に status board を更新する

## 4. Active Sprint Queue（自走対象）

### CL-01 — SpeechAnalyzer Hardening and Safe Fallback
- Owner: Claude
- Priority: P0
- Status: READY
- Parallel lane: Claude-A
- Depends on: none
- Main files:
  - `Memora/Core/Services/STTService.swift`
  - `Memora/Core/Services/STTSupportTypes.swift`
  - `Memora/Core/Services/TranscriptionEngine.swift`（必要最小限）
  - `docs/transcription-core-boundary.md`（必要なら補足）

#### 目的
文字起こし実行時クラッシュを止める。SpeechAnalyzer を「使える端末だけ安全に使う」構成へ変更する。

#### 実装要件
- SpeechAnalyzer 実行前に preflight を入れる
  - `SpeechTranscriber.isAvailable`
  - locale 正規化 / `supportedLocale(equivalentTo:)`
  - `AssetInventory.reserve(locale:)`
  - `AssetInventory.status(forModules:)`
  - `assetInstallationRequest(supporting:)` を使った assets install flow の設計
- `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:considering:)` を使って analyzer 対応フォーマットを選ぶ
- analyzer に投げる音声が非対応 format の場合は offline re-encode / convert を行う
- `prepareToAnalyze(in:)` を呼び、初回遅延を減らす
- SpeechAnalyzer 失敗時は **structured diagnostics を残して** fallback する
- Local mode では server path に勝手に逃がさない
- feature flag は残してよいが、「flag ON = いきなり crash risk」状態を解消する

#### 受け入れ条件
- SpeechAnalyzer パスが preflight なしで走らない
- unsupported locale / missing assets / bad audio format で hard crash しない
- structured diagnostic reason が UI/ログに出せる
- fallback 条件がコード上で読める

#### 補足
このタスクでは UI まで作らなくてよい。状態と error surface を整えることが主目的。

---

### CL-02 — Launch Performance and Lazy Initialization
- Owner: Claude
- Priority: P0
- Status: READY
- Parallel lane: Claude-B
- Depends on: none
- Main files:
  - `Memora/App/MemoraApp.swift`
  - `Memora/App/ContentView.swift`
  - `Memora/Core/Services/DebugLogger.swift`
  - `Memora/Core/Services/OmiAdapter.swift`（必要なら初期化の遅延のみ）
  - `Memora/Core/Services/BluetoothAudioService.swift`（必要なら初期化の遅延のみ）

#### 目的
初回起動時の重さを減らし、ModelContainer タイムアウト → 一時ストアフォールバックの発生率を下げる。

#### 実装要件
- launch path で必須ではない service を lazy init / on-demand init に寄せる
- app 起動直後に不要な device scan / adapter init / heavy index rebuild をしない
- 5 秒タイムアウトの前に何が重いか計測できる logging / timing を入れる
- 永続ストアが正常なら in-memory fallback に落ちにくい構成にする

#### 受け入れ条件
- 起動直後の main-thread work が減る
- デバイス連携系が home 起動時に必ず初期化されない
- どこが遅いか追えるログが残る

---

### CL-03 — File Detail Tab Architecture (Summary / Transcript / Memo)
- Owner: Claude
- Priority: P1
- Status: READY
- Parallel lane: Claude-C
- Depends on: none
- Main files:
  - `Memora/Views/FileDetailView.swift`
  - `Memora/Core/ViewModels/FileDetailViewModel.swift`
  - `Memora/Core/Models/MeetingMemo.swift`（必要最小限）
  - `Memora/Core/Models/PhotoAttachment.swift`（必要最小限）

#### 目的
録音ファイル詳細を PLAUD Note 的な常設タブ体験に寄せる。

#### 実装要件
- 詳細ページに `Summary / Transcript / Memo` の top-level tab state を追加
- 現在の「結果を表示」ボタン遷移を減らし、同ページ内で切り替える
- `Memo` は既存 `MeetingMemo.markdown` を truth にする
- `Memo` は autosave / leave-on-save / index rebuild を壊さない
- `Photos` はこのタスクでは別タブにしなくてよい。Memo 面に photo strip を置くか、後続タスクまで placeholder でも可

#### 受け入れ条件
- FileDetail で Summary / Transcript / Memo を即時切り替えできる
- memo 保存・未保存検知・index 更新が維持される
- 画面遷移の往復が減る

---

### CO-01 — STT Diagnostics & Backend Settings UI
- Owner: Codex
- Priority: P1
- Status: BLOCKED_BY(CL-01 contract freeze)
- Parallel lane: Codex-S
- Depends on: CL-01
- Main files:
  - `Memora/Views/SettingsView.swift`
  - `Memora/Views/DebugLogView.swift`
  - `Memora/Views/Components/STTDiagnosticsCard.swift`（new）

#### 目的
SpeechAnalyzer / legacy fallback の状態を user-visible にする。

#### 実装要件
- 現在の backend choice / availability / locale status / asset status / last failure reason を表示
- SpeechAnalyzer feature toggle を settings/debug から触れるようにする
- STT 実行前に「この端末では analyzer 不可」等を見える化する

#### 受け入れ条件
- STT の状態が UI から確認できる
- crash した/失敗した理由が再現しやすくなる

---

### CO-02 — Launch Diagnostics / Smoke Tests
- Owner: Codex
- Priority: P1
- Status: READY
- Parallel lane: Codex-S
- Depends on: none
- Main files:
  - `MemoraTests/**`
  - 必要なら lightweight debug/perf view

#### 目的
起動性能と STT preflight の破壊を早く検知する。

#### 実装要件
- STT preflight の pure logic 部分に unit test を追加しやすい shape にする（必要なら protocol/mock だけ）
- FileDetail tabs 導入に合わせた smoke test or view model test を追加
- 起動性能計測の lightweight helper test を追加できるなら行う

#### 受け入れ条件
- 今回の主要変更に対する最低限の regression test が増える

---

### CL-04 — Knowledge Query Service for AskAI (file/project/global)
- Owner: Claude
- Priority: P1
- Status: BLOCKED_BY(CL-03 merge)
- Parallel lane: Claude-A or Claude-C
- Depends on: CL-03
- Main files:
  - `Memora/Core/Services/KnowledgeQueryService.swift`（new）
  - `Memora/Core/Services/KnowledgeIndexingService.swift`
  - `Memora/Views/AskAIView.swift`
  - `Memora/Core/Models/KnowledgeChunk.swift`

#### 目的
AskAI の file/project/global を app-owned retrieval で成立させる。

#### 実装要件
- file: direct transcript + summary + memo + photoOCR を束ねる
- project: project に属する file の chunk を rank して top-N context を作る
- global: 全 chunk から軽量 retrieval する
- 返答用 context builder を `AskAIView` から分離する

#### 受け入れ条件
- AskAIView が file 以外でも意味のある context を作れる
- retrieval ロジックが View から外れる

---

### CL-05 — Personal Memory Store for AskAI Personalization
- Owner: Claude
- Priority: P2
- Status: BLOCKED_BY(CL-04)
- Parallel lane: Claude-A
- Depends on: CL-04
- Main files:
  - `Memora/Core/Models/PersonalMemory.swift`（new）
  - `Memora/Core/Services/PersonalMemoryService.swift`（new）
  - `Memora/Views/AskAIView.swift`

#### 目的
AskAI を使うほど app 内メモリでパーソナライズされる構造を作る。

#### 実装要件
- 保存対象は app-owned memory に限定する（OpenAI/ChatGPT の外部メモリ前提にしない）
- 保存候補:
  - よく使う言い回し
  - 要約の好み
  - タスク分解の粒度
  - 好みの出力フォーマット
  - 明示 pin された user preference
- free は local SwiftData
- paid/cloud は後続 task で sync 可能な model shape に留める

#### 受け入れ条件
- Memory の保存/参照/update policy が service に切り出される
- AskAI が次回回答時に memory を参照できる

---

### CO-03 — AskAI UI Integration for Scope & Memory Signals
- Owner: Codex
- Priority: P2
- Status: BLOCKED_BY(CL-04)
- Parallel lane: Codex-S
- Depends on: CL-04
- Main files:
  - `Memora/Views/AskAIView.swift`
  - `Memora/Views/Components/AskAIScopeHeader.swift`（new）
  - `Memora/Views/Components/AskAIMemoryHintView.swift`（new）

#### 目的
AskAI の scope / context / memory 利用状態を UI でわかりやすくする。

#### 受け入れ条件
- file/project/global の区別が UI 上で明確
- どの文脈を使って答えたか説明できる
- personal memory 参照時に soft indicator を出せる

---

### CL-06 — ProcessingJob Integration and Retry/Resume Skeleton
- Owner: Claude
- Priority: P2
- Status: READY
- Parallel lane: Claude-B
- Depends on: none
- Main files:
  - `Memora/Core/Models/ProcessingJob.swift`
  - `Memora/Core/Services/PipelineCoordinator.swift`
  - `Memora/Core/ViewModels/FileDetailViewModel.swift`

#### 目的
文字起こし・要約の失敗点と再試行を見える化し、将来のバックグラウンド再開の土台を作る。

#### 受け入れ条件
- Pipeline 実行時に ProcessingJob が更新される
- stage / status / progress / error を追える
- FileDetail か Home が再試行導線を持てる状態になる

## 5. Backlog Queue（今 sprint の外）
- BL-01 Online meeting coverage
  - EventKit based calendar awareness
  - post-meeting artifact import
  - macOS helper / web recorder strategy
  - meeting bot は最後
- BL-02 Apple Watch recording
  - phase 1: iPhone remote record control
  - phase 2: standalone watch recording + transfer
- BL-03 Notion / ChatGPT / external export connectors
  - summary export
  - context accumulation via app-owned sync/export
- BL-04 Sign in / onboarding v2 / paywall
- BL-05 Cloud sync tier for paid users

## 6. File Conflict Matrix
- CL-01 conflicts with: any task touching `STTService.swift`, `STTSupportTypes.swift`, `TranscriptionEngine.swift`
- CL-02 conflicts with: tasks touching `MemoraApp.swift`, `ContentView.swift`
- CL-03 conflicts with: tasks touching `FileDetailView.swift`, `FileDetailViewModel.swift`
- CL-04 conflicts with: tasks touching `AskAIView.swift`, `Knowledge*`
- CL-06 conflicts with: tasks touching `PipelineCoordinator.swift`, `ProcessingJob.swift`
- Codex tasks must not claim a task if touched files overlap with an in-progress Claude task

## 7. Ready-Now Execution Order

### 今すぐ開始してよい並列セット
1. **Claude-A → CL-01**
2. **Claude-B → CL-02**
3. **Claude-C → CL-03**
4. **Codex-S → CO-02**

### 次の段階
- CL-01 merge 後 → CO-01
- CL-03 merge 後 → CL-04
- CL-04 merge 後 → CL-05 と CO-03
- いつでも並行で進められる → CL-06

## 8. Done Criteria for This Sprint
この sprint は以下が揃えば成功。
- 文字起こし実行で hard crash しない
- 起動で一時ストアフォールバックが出にくくなる
- FileDetail が Summary / Transcript / Memo の常設タブになる
- AskAI を file/project/global へ伸ばす service の入り口ができる
- ProcessingJob が pipeline truth として動き始める

