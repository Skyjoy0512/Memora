# Memora バックエンド改善 実装計画（2026-07）

全20テーマをフェーズ分割し、worktree × セッション並列開発（CLAUDE.md §3）で実行するための正本。
各項目は「1セッションで完了できる粒度」に分割済み。進捗の正本はPRとIssueに置き、このドキュメントは計画と設計判断のみを保持する。

## 運用ルール（全セッション共通）

- 1セッション = 1項目（P番号）。worktreeは `../Memora-<slug>` に作成する。
- ブランチ名は各項目に記載。PRは Squash merge + auto-merge。
- **STTコア保護（CLAUDE.md §8）**: 🔒マークの項目はコアファイル変更の明示依頼を本計画で与える。ただしPR本文に §8 の報告（バックエンド選択順への影響 / SpeechAnalyzer・SFSpeechRecognizer・APIへの影響 / 話者分離・保存フォーマットへの影響 / build・test結果）を必須とする。
- SwiftDataスキーマを変更する項目は、既存データのマイグレーション確認をPR内で報告する。
- レーン別検証（CLAUDE.md §3.3）に従う。下記の各項目にも必須コマンドを記載。

## フェーズ構成と依存関係

```
Phase 0（足場固め）: P0-1 → P0-2, P0-3   ※P0-1完了までSTTコア変更(🔒)着手禁止
Phase 1（即効）:     P1-1, P1-2, P1-3, P1-4   ※相互依存なし・全並列可
Phase 2（精度）:     P2-1, P2-2, P2-3, P2-4, P2-5   ※P2-5はP1-4完了後
Phase 3（BG/OS統合）: P3-1, P3-2, P3-3
Phase 4（大型）:     P4-1, P4-2, P4-3, P4-4, P4-5   ※P4-3はP3-3完了後
```

同時並行の上限はレーン重複で決まる。**同一レーンの項目を2セッションに同時割当しない**こと。
推奨並列組（例）: `P0-1(B/E) + P1-1(A) + P1-2(C)` → `P0-2(B) + P1-4(C) + P3-2(D)` のように、B/A/C/Dを1本ずつ走らせる。

---

## Phase 0: 足場固め（機能追加より先に実施）

### P0-1 🔒 STT回帰テスト基盤

- **ブランチ**: `test/stt-regression-suite` / **レーン**: E（+ Bの読み取りのみ）
- **目的**: STTコア変更の安全網。以降の🔒項目の前提。
- **内容**:
  1. `Packages/MemoraSharedData/Tests/` にチャンクマージ・チェックポイント再開・キャンセル・タイムアウトのユニットテストを追加（`STTService` はDI済みなのでモックバックエンドで検証可能。`STTServiceDependencyContracts.swift` 参照）。
  2. 固定の日本語短尺音声フィクスチャ（10〜30秒、リポジトリに同梱、合成音声で可）＋期待テキストを用意し、CER（文字誤り率）閾値チェックをシミュレータテストとして追加。CI必須にはせず、コア変更PRで手動実行を義務化。
- **変更しない**: STTコア本体（テスト追加のみ。テスタビリティのための最小限のアクセス修飾変更は可、その場合§8報告）。
- **検証**: `swift test --package-path Packages/MemoraSharedData` / SwiftUI側ビルド。
- **受け入れ**: マージ・再開・キャンセルのテストが緑。フィクスチャCERテストの実行手順がテストファイル冒頭コメントに記載されている。

### P0-2 🔒 録音の堅牢性（データ喪失ゼロ化）

- **ブランチ**: `feat/recording-resilience` / **レーン**: B
- **対象**: `Memora/Core/Services/AudioRecorder.swift`（§8対象外だがレーンB）
- **内容**:
  1. `AVAudioSession` interruption（着信・Siri）後の自動再開。route change（BT切替）での録音継続。
  2. セグメント分割録音: 5分ごとにファイルを閉じて次を開く方式に変更し、クラッシュ時の損失を直近セグメントに限定。既存の1ファイル前提の再生・STT投入経路は、セグメント連結ビュー（複数URLを順再生・順STT）で吸収する。`AudioFile` モデルに `segmentPaths: [String]` を追加（既存データは単一パスのまま動くこと）。
  3. 録音開始前＋録音中のディスク残量監視。閾値（500MB）割れで警告、100MB割れで安全停止。
- **PR分割**: (a) interruption/route対応 → (b) セグメント分割保存 → (c) ディスク監視 の3PR。(b)はスキーマ変更を含むため単独PR必須。
- **検証**: SwiftUI側ビルド + 手動確認（録音中に着信シミュレート、機内モード切替、Bluetooth切替）。手動確認結果をPRに記載。
- **受け入れ**: 録音中にアプリをkillしても、直近セグメント以外が再生・文字起こし可能。

### P0-3 可観測性とパイプライン計測

- **ブランチ**: `feat/pipeline-metrics` / **レーン**: C（DebugLogger/ProcessingStatusCenter拡張。STTコアには触れずフック経由）
- **内容**:
  1. MetricKit導入（クラッシュ・ハング・電力のペイロードをローカル保存、設定画面の診断ページで閲覧・共有）。
  2. STT計測: 実時間比（RTF）、バックエンド別成功/失敗、チャンク再試行回数を `DebugLogger` に構造化記録。計測点は `STTCheckpointHooks` / `ProcessingStatusCenter` 等の既存フックに寄せ、コアに新規コードを入れない。入れざるを得ない場合は最小フック追加のみ＋§8報告。
  3. サーマル監視: `ProcessInfo.thermalState` が `.serious` 以上でSTTチャンク並行数を1に落とす設定値を `STTExecutionConfiguration` 経由で供給。
- **検証**: SwiftUI側ビルド + 診断ページで計測値が表示されることのスクリーンショット。
- **受け入れ**: 1回の文字起こしでRTF・バックエンド名・再試行数が診断ページに出る。

---

## Phase 1: 即効（全並列可）

### P1-1 トランスクリプト タップ→再生ジャンプ

- **ブランチ**: `feat/transcript-tap-to-seek` / **レーン**: A
- **前提資産**: `Transcript.segmentStartTimes/segmentEndTimes` 保存済み、`AudioPlayer.seek(to:)` 実装済み。**UI結線のみ**。
- **内容**:
  1. セグメントタップで `seek(to: startSec)` ＋再生開始。
  2. 再生位置に追従して現在セグメントをハイライト＋自動スクロール（`currentTime` の既存プログレスストリームを購読）。
  3. 自動スクロールはユーザーが手でスクロール中は一時停止（3秒後に再追従）。
- **検証**: SwiftUI側ビルド + シミュレータで動作GIF/スクショをPRに添付。
- **受け入れ**: タップ位置の音声が±1秒以内で再生される。デザイントークン（§9）準拠、タップ領域44pt以上。

### P1-2 整形パイプライン: フィラー除去＋ユーザー辞書

- **ブランチ**: `feat/transcript-postprocessor` / **レーン**: C（新規ファイルのみ、STTコア外）
- **内容**:
  1. 新規 `Memora/Core/Services/TranscriptPostProcessor.swift`: ルールベースの日本語フィラー除去（えー/あのー/まあ/なんか等の辞書＋連続重複語正規化）。**元テキストは必ず保持**（`Transcript` に `cleanedText: String?` と `cleanedSegmentTexts: [String]` を追加。表示はトグルで raw/cleaned 切替）。
  2. 新規SwiftDataモデル `CustomVocabulary`（`pattern`, `replacement`, `reading`, `enabled`）。保存時置換に適用。
  3. 辞書をSTT認識ヒントへ供給: `contextualStrings`（SFSpeechRecognizer）/ `prompt`（Whisper API）への受け渡しは **インターフェースだけ** `STTExecutionConfiguration` に `vocabularyHints: [String]` として追加し、コア内での配線は P4-1 と同時に🔒PRで行う（本PRではコア未変更）。
  4. 設定画面に辞書管理UI（追加・編集・削除・有効化）。
- **PR分割**: (a) PostProcessor+cleanedText → (b) CustomVocabulary+設定UI の2PR。
- **検証**: SwiftUI側ビルド + PostProcessorのユニットテスト（フィラー除去の入出力ペア10件以上）。
- **受け入れ**: 既存transcriptに後から整形を適用でき、元に戻せる。

### P1-3 🔒 録音ビットレート最適化

- **ブランチ**: `feat/recording-bitrate` / **レーン**: B
- **内容**: `AudioRecorder` の設定を音声向けに変更: AAC-HE（`kAudioFormatMPEG4AAC_HE`）モノラル 32kbps・サンプルレート48kHz入力。設定画面に「録音品質: 標準（推奨）/ 高音質（現行AAC 44.1kHz）」の選択を追加（既定=標準）。
- **注意**: STT精度への影響確認が必須。同一音源を新旧設定で録音→文字起こしし、結果差分をPRに記載（P0-1のフィクスチャ手順を流用）。
- **検証**: SwiftUI側ビルド + 1時間録音相当のファイルサイズ比較を報告（目標: 従来比 1/4 以下）。
- **受け入れ**: 新規録音が既定で約14MB/時以下。既存ファイルの再生・STTに影響なし。

### P1-4 要約: テンプレート＋モデル選択

- **ブランチ**: `feat/summary-template-config`（基盤） → `feat/summary-template-ui`（UI） / **レーン**: C → A
- **前提資産**: `MeetingNoteTemplate` enum（6種）は `CoreDTOs.swift` に定義済み。プロバイダー抽象（Local FM / OpenAI / Gemini / DeepSeek）完成済み。
- **内容**:
  1. 基盤PR（C）: `SummaryGenerationConfig` を拡張 — `template: MeetingNoteTemplate?` / `providerOverride: AIProvider?` / `modelID: String?` / `detailLevel: 短・標準・詳細` / `outputLanguage`。`SummarizationEngine` でテンプレート別プロンプトを組み立て。新規SwiftDataモデル `SummaryTemplate`（ユーザー定義: 名前・プロンプト・出力セクション）を組み込み6種と同列に扱う。`Summary` を1:N化して再要約履歴を保持（スキーマ変更、マイグレーション報告必須）。
  2. 基盤PR（C）: ローカル（Foundation Models）経路は `@Generable` 構造化出力に置換。FMのコンテキスト約4Kトークン制約のため、長文transcriptは map-reduce（区間要約→統合）を `SummarizationEngine` 内に実装。
  3. UI PR（A）: 要約実行時のテンプレート＋モデル選択シート、ファイル単位の選択記憶、再要約と履歴切替UI、ユーザーテンプレート編集画面。
- **検証**: SwiftUI側ビルド + parseJSON系のユニットテスト + 各テンプレートの出力例をPRに添付。
- **受け入れ**: 同一transcriptに対しテンプレートを変えて再要約でき、過去の結果に切り替えられる。

---

## Phase 2: 精度・パーソナライズ

### P2-1 AskAI: ハイブリッド検索＋UserMemory

- **ブランチ**: `feat/askai-hybrid-retrieval` → `feat/askai-user-memory` / **レーン**: C
- **内容**:
  1. `NLContextualEmbedding`（iOS 17+、オンデバイス、日本語対応）で `KnowledgeChunk` をベクトル化。埋め込みは `KnowledgeIndexingService` のインデックス時に計算し、チャンクに `[Float]` として保存。`LocalRetrievalEngine` のスコアを `キーワードスコア × 0.4 + コサイン類似度 × 0.6` のハイブリッドに（係数は定数化して調整可能に）。既存インデックスは初回起動時にバックグラウンド再構築。
  2. `MemoryExtractionService` を本稼働: 要約完了時に事実候補（役職・プロジェクト名・人名・固有名詞）を抽出→新規SwiftDataモデル `UserMemory`（内容・出典fileID・確度・作成日）に保存。設定画面に記憶の一覧・削除UI（プライバシー配慮で全削除も）。AskAIのシステムプロンプトに上位N件を注入。
  3. AskAI回答への 👍/👎 フィードバックを保存し、👎の多い記憶を注入から除外。
- **PR分割**: (a) 埋め込み+ハイブリッド検索 → (b) UserMemory+抽出 → (c) フィードバック の3PR。
- **検証**: SwiftUI側ビルド + 検索スコアのユニットテスト + 「キーワード一致しないが意味が近い質問」がヒットする実例をPRに記載。

### P2-2 🔒 話者分離: enrollment＋修正学習

- **ブランチ**: `feat/speaker-enrollment` / **レーン**: B
- **対象**: `SpeakerProfileStore.swift`, `FluidAudioDiarizationService.swift`, `SpeakerDiarizationService.swift`（§8報告必須）
- **内容**:
  1. 自分の声登録: 10〜20秒の読み上げ音声からFluidAudioの話者埋め込みを抽出し `SpeakerProfileStore` に保存。ダイアライゼーション結果とコサイン類似でマッチングし「自分」を自動ラベル付け（boundary doc「Omi参照の導入方針」1〜4に対応）。
  2. 修正フィードバック: UIで話者ラベルを手修正したら該当セグメントの埋め込みをプロファイルへ追記（移動平均）。次回以降のマッチング精度を向上。
  3. 短セグメントスムージング: 1.5秒未満の孤立話者ターンを前後にマージ。
  4. `isEstimatedTiming == false`（実タイムスタンプあり）のセグメントは比例配分でなくタイムスタンプ優先で割当。
- **PR分割**: (a) enrollment+マッチング → (b) 修正学習 → (c) スムージング+割当改善 の3PR。話者登録のSwiftDataモデル確定はboundary docの制約どおり(a)で埋め込み仕様を固めてから。
- **検証**: SwiftUI側ビルド + 2〜3名の実会話サンプルでDER改善をbefore/afterでPRに記載 + §8報告。

### P2-3 🔒 VAD＋音声前処理

- **ブランチ**: `feat/stt-vad-preprocess` / **レーン**: B
- **内容**:
  1. FluidAudio同梱のVADでチャンク分割位置を無音に合わせる（`AudioChunker.swift` = 共有パッケージ側）。無音区間はSTT投入をスキップし処理時間短縮。
  2. STT投入前のラウドネス正規化（小音量音声の底上げ）。
  3. 録音経路に `AVAudioEngine` voice processing（ノイズ抑制）のオプション追加（既定OFF、設定でON）。
- **注意**: チャンク境界変更はマージロジックに影響 → P0-1のテストが緑であることを確認してから着手。§8報告必須。
- **検証**: `swift test --package-path Packages/MemoraSharedData` + SwiftUI側ビルド + 同一音源の処理時間before/after。

### P2-4 機能別ルーティング設定（BYOK/ローカル切替）

- **ブランチ**: `feat/per-feature-provider-routing` / **レーン**: C（基盤）→ A（設定UI）
- **内容**:
  1. `AIServiceProviderFactory` に用途enum `AIUseCase { stt, summary, askAI, postprocess }` を追加し、用途ごとに `ローカル / BYOK(プロバイダー+モデル)` を独立指定。UserDefaultsではなく設定用SwiftDataモデルに保存。
  2. 設定画面: 用途×プロバイダーのマトリクス1画面。各行に可用性バッジ（FM非対応端末・APIキー未設定・モデル未DL）とフォールバック順を表示。
  3. プリセット3種: プライバシー優先（全ローカル）/ 品質優先（全BYOK）/ バランス。
- **検証**: SwiftUI側ビルド + 各用途で異なるプロバイダーを指定して動作することを手動確認しPRに記載。

### P2-5 TODO抽出の強化（P1-4完了後）

- **ブランチ**: `feat/todo-structured-extraction` / **レーン**: C
- **内容**:
  1. `TaskPlannerService` のキーポイント正規表現パースを構造化出力（`@Generable` / JSON schema）に置換。
  2. 担当者抽出: 話者ラベルと紐付け（「田中さんが対応」→ assignee候補）。
  3. 重複検知: 既存TODOとタイトル類似度で照合し、二重登録を確認ダイアログで防止。
  4. EventKitでリマインダー/カレンダーへワンタップ登録（権限リクエスト含む）。
  5. 抽出時に出典セグメントIDを保持し「発言箇所へジャンプ」（P1-1の機構を流用）。
- **検証**: SwiftUI側ビルド + パースのユニットテスト + 抽出例をPRに添付。

---

## Phase 3: バックグラウンド・OS統合

### P3-1 🔒 バックグラウンド文字起こし

- **ブランチ**: `feat/background-transcription` / **レーン**: B（+ D: Info.plist/entitlements変更は基盤PRに分離）
- **内容**:
  1. 基盤PR（D）: Background Modes（processing）の宣言、`BGTaskScheduler` の識別子登録。
  2. 録音中の並行文字起こし: audioセッションがアクティブな間に録音済みチャンクを逐次STT（ライブ文字起こし）。録音停止時には大半が処理済みの状態を目指す。
  3. `BGProcessingTask`: 未処理キューを充電中・夜間に処理。チェックポイント機構（`TranscriptionCheckpointStore`）で途中打ち切りから再開。
  4. `TranscriptionActivity`（Live Activity）を拡張し進捗をDynamic Island/ロック画面に表示。処理完了のローカル通知。
  5. **制約**: Foundation ModelsはBGでレート制限が厳しいため、BG処理はSTTまで。要約はフォアグラウンド復帰時にキュー実行。
- **PR分割**: (a) D基盤 → (b) 録音中並行STT → (c) BGProcessingTask → (d) Live Activity+通知 の4PR。§8報告必須。
- **検証**: SwiftUI側ビルド + 実機での BG 実行ログ（`start_sim_log_cap` またはConsole）をPRに記載。

### P3-2 OS統合（App Intents / Spotlight / 共有シート / 通知）

- **ブランチ**: `feat/os-integration` / **レーン**: D（target/plist変更）+ C（インデックス）
- **内容**:
  1. App Intents: 「録音開始」「録音停止」「最後の録音を要約」。Siri・ショートカット・Action Button・コントロールセンターウィジェット（iOS 18+）対応。
  2. Spotlight: `CSSearchableIndex` にtranscript/要約を登録（P2-1のチャンクを流用）。削除時のインデックス除去も。
  3. 共有シート拡張: 他アプリの音声ファイルを受け取り `AudioFileImportService` へ渡すShare Extension。
- **PR分割**: (a) App Intents → (b) Spotlight → (c) Share Extension の3PR（それぞれtarget追加を含むためLane D管理）。
- **検証**: SwiftUI側ビルド + 各入口の動作スクショ。

### P3-3 データ保全とバックアップ

- **ブランチ**: `feat/data-backup-export` / **レーン**: C
- **内容**:
  1. `PersistentStoreSafetyService` を拡張し、スキーマ移行前の自動スナップショット＋失敗時ロールバック。
  2. 完全エクスポート/インポート: 全録音＋transcript＋要約＋設定をzip一括書き出し・読み込み（`ExportService` 拡張）。機種変更・P4-3前の暫定バックアップ手段。
  3. `LocalDataDeletionService` とエクスポートを対にした「データ管理」設定画面。
- **検証**: SwiftUI側ビルド + エクスポート→全削除→インポートで復元されるラウンドトリップを手動確認しPRに記載。

---

## Phase 4: 大型機能

### P4-1 🔒 WhisperKitバックエンド＋言語自動検出

- **ブランチ**: `feat/whisperkit-backend`（複数PR） / **レーン**: B + D（パッケージ追加）
- **内容**:
  1. 基盤PR（D）: WhisperKit をSwiftPMで追加。モデル（large-v3-turbo、日本語特化候補として kotoba-whisper も評価）は初回オンデマンドDL（`ModelStoreService` の枠組みを流用。DL進捗UI・Wi-Fi限定オプション・削除UI）。
  2. コアPR（B/🔒）: `STTService` のバックエンド選択に `whisperKit` を追加。位置づけはboundary docどおり「SpeechAnalyzer非対応端末向け高精度バックエンド」＋全端末向け「高精度モード」。選択順の真実は `STTService.swift` にのみ置く。
  3. 語彙ヒント配線（🔒）: P1-2で用意した `vocabularyHints` を `contextualStrings` / Whisper `prompt` へ配線。
  4. 言語自動検出: 冒頭30秒を先行STTして言語判定→本処理。日英混在はWhisper系に自動ルーティング。
  5. 電力・発熱: P0-3のサーマル制御をWhisperKit経路にも適用。
- **前提**: P0-1のテストが緑。§8報告必須（バックエンド選択順の変更を含むため特に詳細に）。
- **検証**: `swift test` + SwiftUI側ビルド + フィクスチャCER比較（SpeechAnalyzer vs WhisperKit）+ RTF・発熱の実測をPRに記載。

### P4-2 ライフログ: カレンダー複合情報

- **ブランチ**: `feat/lifelog-calendar-fusion` / **レーン**: C → A
- **内容**:
  1. 録音開始時刻とEventKit予定の突き合わせ→自動タイトル・プロジェクト自動振り分け（`CalendarService` 拡張）。
  2. 予定の参加者リストを話者ラベル候補としてサジェスト（P2-2のプロファイルと接続）。
  3. 要約プロンプトへ会議名・アジェンダを文脈注入。
  4. 録音時にCLLocationを1回取得し場所を記録（許可はwhen-in-use、設定でOFF可）。
  5. 日次ビュー: 予定＋録音＋TODOの時系列合成画面（UI PR、Lane A）。
- **検証**: SwiftUI側ビルド + カレンダー突き合わせのユニットテスト。

### P4-3 CloudKit同期＋課金（P3-3完了後）

- **ブランチ**: `feat/cloudkit-sync`（複数PR） / **レーン**: D + H
- **設計判断**: クラウドは **CloudKit private database**（開発者側の保管・転送コスト0円、容量はユーザーのiCloud枠）。STT/要約はオンデバイスでサーバー処理不要のため成立する。Android展開が確定した時点でR2移行を再検討。
- **内容**:
  1. 基盤PR（D）: iCloud capability・コンテナ設定。
  2. 同期PR（H）: `Packages/MemoraSharedData` のストア契約にCloudKit同期レイヤーを追加（transcript/要約/メタデータ）。競合はlast-writer-wins＋ローカル履歴保持。
  3. 音声PR: 音声はアップロード時にAAC-HE 24kbpsモノに再圧縮した `CKAsset` として保存。原本はローカル保持（設定で「クラウドのみ」も選択可）。
  4. 課金PR: StoreKit 2サブスクリプション「クラウド同期＋バックアップ」。無課金はローカルのみ（現行動作）。
- **検証**: `swift test --package-path Packages/MemoraSharedData` + 2台実機（またはシミュレータ+実機）での同期確認 + Sandbox課金テスト。

### P4-4 BYOKコスト可視化

- **ブランチ**: `feat/byok-cost-tracking` / **レーン**: C
- **内容**: プロバイダー別トークン使用量の記録（`RemoteLLMProvider` のレスポンスusage欄から取得）と月次概算コスト表示。同一transcript×同一テンプレートの要約キャッシュ（P1-4の履歴機構を流用）で再課金防止。APIキーのiCloud Keychain同期を有効化。
- **検証**: SwiftUI側ビルド + 使用量記録のユニットテスト。

### P4-5 AskAI音声会話モード

- **ブランチ**: `feat/askai-voice-mode` / **レーン**: A + C
- **内容**:
  1. 入力: SpeechAnalyzerライブ認識をAskAI入力欄に接続。
  2. 出力: `AVSpeechSynthesizer`＋拡張音声を既定に。BYOK時はOpenAI TTS / Gemini TTSを選択可（P2-4のルーティングに `tts` 用途を追加）。
  3. 回答ストリーミングと文単位TTSの組み合わせ（生成完了前に読み上げ開始）。
  4. ハンズフリーモード: 読み上げ終了→自動でマイク再開。
- **検証**: SwiftUI側ビルド + 会話デモの動画/GIF。

---

## Codexセッション キックオフプロンプト（テンプレート）

各セッション開始時に以下を渡す:

```
docs/backend-improvement-plan.md の <P番号> を実装する。

1. git fetch origin && git worktree add ../Memora-<slug> -b <ブランチ名> origin/main
2. レーン宣言: <レーン>。他レーンのファイルには触らない。
3. 計画記載の「内容」を、記載の「PR分割」単位で実装する。1PR=1目的。
4. 計画記載の「検証」を実行し、結果をPR本文に記載する。
5. 🔒項目の場合はCLAUDE.md §8の報告をPR本文に必ず含める。
6. push → PR作成 → auto-merge設定。完了報告はCLAUDE.md §6の形式で。

スコープ外の変更（ついでリファクタ・他テーマの先取り）は禁止。
計画と実装が食い違う場合は、実装を優先せず理由をPRに書いて判断を仰ぐ。
```

## 進捗管理

- 各P番号をGitHub Issue化する場合は `/pm-breakdown` を使用（Issue番号をブランチ名に含める: `feat/<issue>-<slug>`）。
- このドキュメントには**設計判断の変更のみ**追記する。進捗・完了状況はPR/Issueが正本。
