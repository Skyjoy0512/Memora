# Fable5 Review Prompt: Memora x PLAUD Note Gap Review

あなたは senior product engineer / iOS architect / audio AI backend reviewer として、この GitHub repository をレビューしてください。

## Repository

- Repository: `https://github.com/Skyjoy0512/Memora`
- Branch: `main`
- Current goal: Memora を PLAUD Note アプリに限りなく近い体験へ寄せる。ただし単なる UI コピーではなく、録音、取り込み、文字起こし、要約、ファイル管理、AI 質問、外部共有までの user journey を実用品質に近づけたい。

## Important Context

Memora は「PLAUD Note ライクな個人向け meeting OS」を目指しています。

ユーザーは音声を録る、または取り込みます。その後アプリが、文字起こし、要約、メモ整理、AI 質問、外部共有まで一気通貫で支援することが理想です。

最重要優先度は次の順です。

1. 文字起こしがクラッシュせず安定すること
2. PLAUD Note に近い自然な画面構成、導線、状態遷移になること
3. File Detail が日常的に使えること
4. AskAI が file / project / global scope で実用になること
5. Notion / ChatGPT / Markdown / TXT / JSON / SRT / VTT などへ持ち出せること

## Files To Read First

まず以下を読んで、現在のプロダクト意図と制約を把握してください。

- `docs/Memora_Product_North_Star.md`
- `CLAUDE.md`
- `docs/transcription-core-boundary.md`
- `Memora/App/ContentView.swift`
- `Memora/Views/HomeView.swift`
- `Memora/Views/FileDetail/FileDetailView.swift`
- `Memora/Views/RecordingView.swift`
- `Memora/Views/TranscriptView.swift`
- `Memora/Views/SummaryView.swift`
- `Memora/Views/ProjectsView.swift`
- `Memora/Views/AskAIView.swift`
- `Memora/Core/Services/STTService.swift`
- `Memora/Core/Services/STTSupportTypes.swift`
- `Memora/Core/Services/TranscriptionEngine.swift`
- `Memora/Core/Services/SpeakerDiarizationService.swift`
- `Memora/Core/Networking/AIService.swift`
- `Memora/Core/Services/PlaudService.swift`
- `Memora/Core/Services/PlaudImportService.swift`
- `bot-server/README.md`

## Review Scope

レビュー対象は「実装の正しさ」だけではありません。以下を総合的に見てください。

### 1. PLAUD Note との体験差分

PLAUD Note の現在のアプリ体験を可能な範囲で調査または推定し、Memora との差分を整理してください。

見てほしい観点:

- ホーム画面の情報設計
- 録音開始から保存までの導線
- 音声ファイル一覧、検索、フィルタ、プロジェクト管理
- ファイル詳細画面の Summary / Transcript / Memo / Ask AI の扱い
- テンプレート、要約形式、AI 生成物の扱い
- 話者分離、話者ラベル編集、タイムスタンプ表示
- 共有、エクスポート、外部サービス連携
- デバイス連携、PLAUD / Omi 連携の見せ方
- 空状態、失敗状態、処理中状態、長時間処理状態
- 設定画面と高度な設定の出し方
- 画面遷移、戻る導線、sheet / push / tab の使い分け

出力では、PLAUD Note に「寄せるべき差分」と、Memora 独自性として「残してよい差分」を分けてください。

### 2. 画面遷移レビュー

現在の SwiftUI 画面構成を読み、ユーザーが次の目的を達成するまでに迷う箇所を洗い出してください。

- 今すぐ録音する
- 外部音声を取り込む
- PLAUD 由来の録音を同期または import する
- 文字起こしを実行する
- 文字起こしの失敗理由を理解する
- 要約を作る
- 要約テンプレートや AI モデルを選ぶ
- transcript / summary / memo を行き来する
- 話者ラベルを確認または修正する
- ファイル単位で AI に質問する
- Project 単位または Global に質問する
- Notion / ChatGPT / Markdown 等へ export する

必要なら Mermaid で現状の画面遷移図と、改善後の理想画面遷移図を出してください。

### 3. 文字起こし精度・安定性レビュー

STT 周りは最重要です。単に「動くか」ではなく、精度、安定性、失敗時 UX、将来拡張性をレビューしてください。

重点的に見てほしい観点:

- `SpeechAnalyzer` / `SFSpeechRecognizer` / API mode の backend selection が妥当か
- iOS 17 target と iOS 26 SpeechAnalyzer path の共存が安全か
- 長時間音声の chunking / merge / progress / cancellation が破綻しないか
- 音声前処理、サンプルレート、チャネル、無音区間、ノイズ、音量正規化の改善余地
- 日本語・英語混在会議への対応
- 話者分離の精度改善余地
- diarization と transcript 保存形式の整合
- タイムスタンプ、SRT/VTT export の品質
- reference transcript や Plaud import データをどう評価・比較に使えるか
- STT diagnostics のログ設計が十分か
- 失敗時にユーザーへ出す recovery action が適切か
- WhisperKit / OpenAI Whisper / Gemini / Deepgram / AssemblyAI 等を入れるなら、どの位置づけがよいか

注意:

- いきなり STT コアを書き換える提案だけにしないでください。
- `docs/transcription-core-boundary.md` の境界を守り、UI 改修、STT backend 改修、保存形式変更、話者登録機能を分離して提案してください。

### 4. バックエンド / サーバー設計レビュー

Memora は iOS アプリ中心ですが、PLAUD Note に近づけるにはバックエンド設計も重要です。現状の `bot-server` や import/export、将来のクラウド処理を踏まえてレビューしてください。

見てほしい観点:

- 今のままローカル中心で進めるべき範囲
- サーバー側に逃がすべき処理
- 長時間音声のアップロード、分割、キュー、リトライ、ジョブ状態管理
- STT / summarization / diarization の非同期 pipeline
- transcript / summary / memo / embedding / project memory のデータモデル
- Privacy、音声データ保持期間、削除、暗号化
- PLAUD 連携の API adapter 境界
- Notion / ChatGPT export の同期設計
- 将来の sign in / cloud sync / subscription を見据えた最小 backend architecture
- iOS offline-first と cloud-assisted の切り分け

### 5. 実装リスクと優先順位

最後に、次にやるべきことを P0 / P1 / P2 に分けてください。

P0 は「これを直さないと PLAUD Note ライク以前に使えない」もの。
P1 は「PLAUD Note に近づけるために重要」なもの。
P2 は「後からでもよいが競争力につながる」もの。

## Output Format

日本語で、以下の構成で出力してください。

1. Executive Summary
   - 3から7行で、今の Memora が PLAUD Note に対してどこまで近いか、最大の不足は何かを書く。

2. PLAUD Note Gap Table
   - Columns: Area / PLAUD Note expected behavior / Memora current state / Gap severity / Recommended action / Key files

3. Screen Flow Findings
   - 現状の導線で迷う箇所
   - 改善後の推奨導線
   - 必要なら Mermaid diagram

4. STT and Diarization Findings
   - 精度改善
   - 安定性改善
   - backend selection
   - diagnostics
   - tests

5. Backend Architecture Findings
   - local-first で残すもの
   - server-side に逃がすもの
   - job queue / storage / privacy / integration の提案

6. Prioritized Roadmap
   - P0 / P1 / P2
   - 各項目に、目的、変更対象、期待効果、リスク、確認方法を書く。

7. Concrete Issues To Create
   - GitHub Issue として切れる粒度で 10から20個。
   - title / scope / acceptance criteria / files likely touched を含める。

8. Questions / Unknowns
   - PLAUD Note の実機確認が必要な点
   - プロダクト判断が必要な点
   - 技術検証が必要な点

## Review Rules

- コードを変更しないでください。まずレビューと提案だけにしてください。
- 推測と確認済み事実を分けて書いてください。
- 重大な bug / crash risk / data loss risk があれば最初に明示してください。
- 画面や機能の提案は、PLAUD Note へ近づける観点と Memora 独自価値の観点を分けてください。
- 実装提案は巨大 PR ではなく、小さい PR に分割してください。
- STT コア、保存形式、バックエンド、UI を同じ PR に混ぜないでください。
- 日本語 UI copy の改善案があれば、自然な日本語で提案してください。
