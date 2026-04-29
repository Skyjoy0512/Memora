# Memora vNext Current Truth & Claude-First Execution Plan

> この文書が **vNext の current truth** です。  
> 以後、Claude はまずこの文書を読み、次に `CLAUDE.md`、必要なら `docs/transcription-core-boundary.md` を読むこと。  
> 旧 docs は参考程度とし、この文書と矛盾したら **この文書を優先** する。

最終更新: 2026-04-28

---

## 1. いま何を作っているか

Memora は **PLAUD NOTE ライクな、iOS-first / local-first の meeting OS** である。

### コア体験
1. 録音・取込
2. 落ちない高速文字起こし
3. 読みやすい詳細画面（Summary / Transcript / Memo）
4. Ask AI でファイル / プロジェクト / 全体に質問
5. 必要なら外部へ共有・エクスポート

### vNext の最重要テーマ
- **P0: 文字起こしの安定化と高速化**
- **P1: iOS 26 / HIG 準拠の UI 再設計**
- **P2: Ask AI を “使える” 状態にする**
- **P3: ローカル LLM 実行基盤（Gemma 系）**

### いまはやらない / 後回し
- サインイン
- ペイウォール
- 本格クラウド同期
- オンライン会議 bot
- Apple Watch 単体録音
- Web / macOS 専用最適化

---

## 2. 現在の repo から確認できる進捗

### できていること
- 録音 / 音声インポート / Plaud import / Omi integration / 要約 / ToDo / Export は v1 docs 上で概ね done 扱い。
- File Detail は Summary / Transcript / Memo の 3 タブ構造が入っている。
- `MeetingMemo` は Markdown 保存を前提にしたモデルになっている。
- `PhotoAttachment` は caption / OCR text を持つ。
- `KnowledgeChunk` と `KnowledgeIndexingService` があり、summary / memo / todo / photo OCR / reference transcript を検索文脈化できる土台がある。
- Ask AI は file / project / global の 3 scope UI と、`KnowledgeQueryService` ベースの context assembly をすでに持つ。
- Notion export と OpenAI Files upload は File Detail の export 導線から到達できる。

### まだ危ないところ
- `SpeechAnalyzerFeatureFlag` は「実機での EXC_BREAKPOINT クラッシュ回避のためデフォルト OFF」になっている。
- `STTService` の legacy path は `SFSpeechURLRecognitionRequest.requiresOnDeviceRecognition = true` を強制している。
- `MemoraApp` は `ModelContainer` 生成を 5 秒で打ち切り、一時ストアへフォールバックする。
- Ask AI の prompt 生成は service 側へ寄っているが、View から provider 呼び出しまでの orchestration はまだ太い。

### 現状の判断
機能の数は増えているが、**プロダクト価値を決めるのは STT と UI**。  
この2つが不安定 / 見づらいままだと、Ask AI や Gemma を足しても評価は上がらない。

---

## 3. vNext の設計判断

### 3.1 文字起こし
- **第一選択**: Apple Speech (`SpeechTranscriber` / `SpeechAnalyzer`) を安全に使う
- **第二選択**: `DictationTranscriber` / `SFSpeechRecognizer` 系 fallback
- **第三選択**: API transcription
- **将来候補**: WhisperKit は実験バックエンドとして保持可だが、vNext の主軸ではない

### 3.2 Ask AI
- file scope: 直接コンテキスト + 軽い retrieval
- project/global scope: `KnowledgeChunk` ベース retrieval
- View が prompt を組む構造は縮小し、**retrieval service + provider service** に寄せる

### 3.3 ローカル LLM
- `LLMProvider` abstraction を作る
- remote provider と local provider を同じ契約で扱う
- **production path** は iOS で現在ドキュメント化されている on-device LLM path から入る
- **Gemma 4** は最終目標だが、実装は「抽象化 → documented local path → Gemma 4 experimental profile」の順で進める

### 3.4 デザイン
- iOS 26 / Liquid Glass を採用する
- ただし **Liquid Glass はバー・検索・アクション導線中心** に使う
- 本文面（要約、文字起こし、メモ）は可読性優先で solid surface を使う
- “全部をガラスにする” は禁止

---

## 4. デザイン原則（HIG / iOS 26 反映）

### 絶対ルール
- Content first
- 標準コンポーネント優先
- バーやツールバーに独自背景色を足しすぎない
- 階層は色ベタではなく、余白・グルーピング・タイポ・tint で表現
- FAB は 1つに絞る
- 1画面に主目的は 1つ

### Home 画面
- 上部: 検索 + フィルタ
- 本文: 録音ファイルの一覧
- 下部: 録音 / インポート / Plaud の主アクション
- カードは「タイトル / 日時 / 長さ / project / state」が一目で読めること

### File Detail 画面
- 上部: タイトル / 日時 / source / project
- 中段: Summary / Transcript / Memo の segmented tabs
- 下段: context-aware actions
  - Transcript タブなら再文字起こし / speaker rename
  - Summary タブなら再要約 / export
  - Memo タブなら markdown edit / photo attach
- 写真は Memo タブ文脈に溶け込ませる

### Ask AI
- scope picker は上部で明示
- 参照ソース badge を常時見せる
- 回答には citation badge を表示
- project/global は「何を見て答えたか」が見えること

---

## 5. 実行ルール（Claude 用）

1. 変更前に以下を宣言する
   - 現状理解
   - 変更するファイル
   - 変更しないファイル
   - 実装方針
2. 1回で触るのは **1タスクだけ**
3. broad rewrite 禁止
4. UI とコアを同時に大改修しない
5. STT コアに触る場合は `docs/transcription-core-boundary.md` を守る
6. 旧 docs が多くても迷わない。この文書を優先する
7. 完了したらこの文書の checklist を更新する

---

## 6. Claude 自走用 Execution Board

> ルール: **A 系を B/C より優先**。  
> A が全部 DONE になるまで、B/C は「並列でも安全なものだけ」にする。

### Track A — Reliability / Performance（最優先）
- [x] **A1. SpeechAnalyzer preflight と backend resolver を導入する**
- [x] **A2. File transcription pipeline を harden する** → 実機検証 OK（2026-04-14）
- [x] **A3. 起動時の重さと temporary store fallback を改善する** → 実機検証 OK（2026-04-14）
- [x] **A4. STT diagnostics と recovery UX を完成させる** → 実機検証 OK（2026-04-14）

### Track B — iOS 26 Design Refresh
- [x] **B1. App shell を HIG / Liquid Glass に合わせて再設計する** → 実機検証 OK（2026-04-14）
- [x] **B2. Home / Project 一覧を content-first に整理する** → 実機検証 OK（2026-04-14）
- [x] **B3. File Detail を完成形 UI に寄せる** → 実機検証 OK（2026-04-14）

### Track C — Ask AI / Local LLM
- [x] **C1. Ask AI を retrieval service ベースへ移行する** → 実機検証 OK（2026-04-14）
- [x] **C2. `LLMProvider` abstraction と local provider slot を追加する** → 実機検証 OK（2026-04-14）
- [x] **C3. iOS local LLM provider を実装する（documented path から）** → 実機検証 OK（2026-04-14）
- [x] **C4. Gemma 4 experimental profile を追加する** → 実機検証 OK（2026-04-14）

### Later / Parking Lot
- [x] D1. Notion / external knowledge export → Notion export + OpenAI Files upload 導線を確認（2026-04-28）
- [ ] D2. Online meeting capture
- [ ] D3. Apple Watch remote recording
- [ ] D4. Sign in / paywall / cloud sync

---

## 7. 各タスクの仕様

### A1. SpeechAnalyzer preflight と backend resolver を導入する

#### 目的
SpeechAnalyzer を「使えたら使う」ではなく、**使ってよい条件を満たした時だけ使う**形にする。

#### 実装方針
- `SpeechTranscriber.isAvailable` を確認する
- `supportedLocale(equivalentTo:)` で locale を正規化する
- `AssetInventory.status(forModules:)` で asset 状態を確認する
- `.supported` の場合は installation request を通して導入する
- `SpeechAnalyzer.bestAvailableAudioFormat(...)` で入力フォーマットを決める
- preflight 不成立なら **SpeechAnalyzer を呼ばずに** fallback する
- backend 選択結果を diagnostics に残す

#### 主変更候補
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- 新規: `Memora/Core/Services/SpeechPreflightService.swift`（必要なら）

#### 受け入れ条件
- SpeechAnalyzer path に入る前に availability / locale / asset / format が判定される
- preflight 不成立時にクラッシュせず fallback する
- diagnostics に backend / asset / locale / format / fallback reason が残る

---

### A2. File transcription pipeline を harden する

#### 目的
長時間音声でも UI freeze / stop / crash しにくくする。

#### 実装方針
- 文字起こし処理を MainActor から切り離す
- 長時間ファイルは chunking を徹底する
- 中間結果 / 進捗 / 失敗理由をジョブ状態として持つ
- legacy path の `requiresOnDeviceRecognition = true` 強制は見直す
- `shouldReportPartialResults` は用途に応じて最適化する
- volatile / final の扱いを整理する
- cancel / retry / timeout / cleanup を明示する

#### 主変更候補
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Models/ProcessingJob.swift`
- `Memora/Core/Services/PipelineCoordinator.swift`

#### 受け入れ条件
- 30〜60分音声でも処理中に UI が固まらない
- cancel / retry が効く
- 失敗時に stage と reason がわかる
- partial/final の責務が読める

---

### A3. 起動時の重さと temporary store fallback を改善する

#### 目的
cold start を軽くし、「起動はしたが永続保存されていない」を減らす。

#### 実装方針
- 起動時に重い初期化を後ろへ逃がす
- `ModelContainer` 初期化の計測ログを入れる
- 5秒固定タイムアウトの妥当性を見直す
- fallback 時は UI で強く伝える
- 必要なら一部 service を lazy 化する

#### 主変更候補
- `Memora/App/MemoraApp.swift`
- `Memora/Core/Services/DebugLogger.swift`
- 依存注入ポイント

#### 受け入れ条件
- 起動シーケンスが可視化される
- temporary store への自動移行が減る、または説明可能になる
- ユーザーが保存されていない状態を認識できる

---

### A4. STT diagnostics と recovery UX を完成させる

#### 目的
「何で失敗したか」をユーザーにも開発者にも見える化する。

#### 実装方針
- DebugLogView に backend diagnostics を見せる
- locale unsupported / asset not installed / format mismatch / timeout を分類する
- recovery action を付ける
  - asset 導入
  - fallback 再実行
  - API mode 提案
  - locale 変更提案

#### 受け入れ条件
- 文字起こし失敗時に、再試行可能な理由が出る
- DebugLog で backend path を追える

---

### B1. App shell を HIG / Liquid Glass に合わせて再設計する

#### 目的
見た目を “カスタムUIの寄せ集め” から “iOS 26 ネイティブ” に寄せる。

#### 実装方針
- Tab / Navigation / Search / Toolbar は標準コンポーネント優先
- バーの custom background を減らす
- FAB / bottom action を整理し 1 主導線に絞る
- Liquid Glass は標準要素中心で採用する

#### 主変更候補
- `Memora/App/ContentView.swift`
- `Memora/Views/HomeView.swift`
- `Memora/Views/ProjectsView.swift`
- `Memora/Views/Components/**`

#### 受け入れ条件
- 主要導線が整理される
- custom chroming が減る
- content が主役になる

---

### B2. Home / Project 一覧を content-first に整理する

#### 目的
録音ファイルやプロジェクトが一目で理解できるようにする。

#### 実装方針
- カードの情報密度を最適化する
- タイトル / 日付 / duration / status / source / project を固定順で見せる
- Filter / Search は上部に寄せる
- decorative UI を減らす

#### 受け入れ条件
- 一覧の読解コストが下がる
- Home と Project の card language が揃う

---

### B3. File Detail を完成形 UI に寄せる

#### 目的
Memora の最重要画面を、読む・聞く・直す・質問する、の中心画面にする。

#### 実装方針
- Summary / Transcript / Memo タブを最優先にする
- タブごとに action を最適化する
- memo と photo attachment を自然に統合する
- transcript は speaker / timestamps / searchability を損なわない

#### 主変更候補
- `Memora/Views/FileDetailView.swift`
- `Memora/Core/ViewModels/FileDetailViewModel.swift`

#### 受け入れ条件
- 詳細画面だけで主要作業が完結しやすい
- タブ切り替えの意味が明確

---

### C1. Ask AI を retrieval service ベースへ移行する

#### 目的
View 直組み prompt から脱却し、file/project/global を安定化する。

#### 実装方針
- `KnowledgeChunk` を一次ソースにする retrieval service を作る
- file: transcript / summary / memo / photoOCR / todo を rank 付きで取る
- project/global: scope + keyword + rankHint で top-N を返す
- AskAIView は service 呼び出し中心へ縮小する

#### 主変更候補
- `Memora/Views/AskAIView.swift`
- `Memora/Core/Services/KnowledgeIndexingService.swift`
- 新規: `Memora/Core/Services/AskAIRetrievalService.swift`

#### 受け入れ条件
- project/global の回答元が source/citation として説明できる
- View 内の巨大な context 組み立てが減る

---

### C2. `LLMProvider` abstraction と local provider slot を追加する

#### 目的
OpenAI / Gemini / DeepSeek / Local を同じ契約で扱えるようにする。

#### 実装方針
- `LLMProvider` protocol を作る
- sync / stream 両対応を考慮する
- Ask AI と summary の両方から使えるようにする
- local provider を後から差し替えやすくする

#### 受け入れ条件
- local provider を差し込める
- UI が provider 固有実装に依存しない

---

### C3. iOS local LLM provider を実装する（documented path から）

#### 目的
ローカル推論の production path を作る。

#### 実装方針
- まずは iOS で現時点のドキュメントがある on-device LLM path を採用する
- 生成は background thread で行う
- streaming を UI に流せる形にする
- model download / availability / memory requirement を管理する

#### 主変更候補
- 新規: `Memora/Core/Services/LocalLLMProvider.swift`
- 新規: `Memora/Core/Services/ModelStoreService.swift`
- Settings / Ask AI 周辺

#### 受け入れ条件
- supported device で local Ask AI が動く
- current thread を block しない
- model 管理状態がわかる

---

### C4. Gemma 4 experimental profile を追加する

#### 目的
Gemma 4 をローカル実行できる将来形に備えつつ、実験フラグで段階導入する。

#### 実装方針
- feature flag で隠す
- device gating を入れる
- benchmark UI を用意する
- stable path を壊さない

#### 受け入れ条件
- supported device だけで試せる
- unsupported device で誤って有効化されない
- production path と実験 path が分離される

---

## 8. Claude の優先順

**常にこの順番で進める。**

1. A1
2. A2
3. A3
4. A4
5. B1
6. B2
7. B3
8. C1
9. C2
10. C3
11. C4

---

## 9. 完了報告テンプレート

- 変更概要
- 変更ファイル一覧
- なぜ必要か
- 受け入れ条件の達成状況
- 未確認事項
- 次に進むべき task
