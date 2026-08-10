# Memora リリース準備監査（2026-08-10）— SwiftUI 削除後

## 1. 監査概要

| 項目 | 値 |
|---|---|
| 監査日 | 2026-08-10 |
| 対象 main SHA | `657a73def2726bf26cf991f47d3fec9d8b552329`（#181 SwiftUI 削除、origin/main 先端） |
| 実施 worktree | `../Memora-rn-post-audit`（branch `docs/rn-post-deletion-audit`、origin/main に対し ahead 0 / behind 0） |
| スコープ | read-only 監査。docs（`docs/**`）のみ変更し、コード・設定・CI は変更しない |
| 前提 | 2026-08-09 に #181（SwiftUI 削除）・#180（Tasks 実データ化）・#179（Git 整理）が完了。実機 QA は後回し。1.0 スコープ未確定のため、本監査を基に推奨をまとめる |

本監査の続きの正本: parity matrix の現在地は `docs/rn-full-cutover-execution-plan.md`、作業ログは
`docs/react-native-expo-migration-plan.md`。

## 2. 削除後の現状（2026-08-10 時点の main）

### 2.1 ルート構成

| パス | 状態 |
|---|---|
| `Memora/` | **存在しない**（#181 で削除済み） |
| `project.yml` | **存在しない**（#181 で削除済み。xcodegen 不要の RN 単独構成） |
| `apps/mobile-expo` | 残存（RN アプリ。Expo SDK 57 / RN 0.86 / TypeScript / Expo Router） |
| `Packages/MemoraSharedData` | 残存（共有スキーマ / STT core / summary / askai / store resolver） |
| `MemoraBroadcastExtension/` | 残存（ソース維持・RN ビルド対象外） |
| `MemoraWidget/` | 残存（ソース維持・RN ビルド対象外） |
| `bot-server/` | 残存 |
| `docs/` | 残存 |
| `MemoraTests/` | **削除済み（2026-08-10）**。旧 SwiftUI のテスト群（34 ファイル、`CreateProjectViewModelTests` 等）で RN の `MemoraRN.xcodeproj` には参照されない孤立残存だったため `git rm -r` で削除。xcodeproj 内の `MemoraTests` 文字列は RN テスト target（`MemoraRNTests`）の bundle ID `com.memora.MemoraTests` のみで、ディレクトリ参照ではない |

### 2.2 CI（`.github/workflows/ci.yml`）

`ios-build`（`-scheme Memora` + xcodegen）は**存在しない**。残存ジョブは次の 4 つ:

| ジョブ | 内容 |
|---|---|
| `shared-data` | `swift test --package-path Packages/MemoraSharedData` |
| `expo-check` | `npm ci` → `npm run typecheck` → `npx expo export --platform web` |
| `rn-ios-build` | `npm ci` → `pod install` → `npm run qa:ios:build`（`build-for-testing`。**テスト実行は含まない**） |
| `bot-server-build` | `npm ci` → `npm run build` |

注意: `qa:ios:test`（RN ホストテスト実行）は CI に含まれない。ADR-003 gate e の
「`qa:ios:test` pass」はローカル実行のみで担保する必要がある。

### 2.3 保持対象（native core / ADR-004 実装済みの確認）

| 対象 | 状態（コード根拠） |
|---|---|
| 共有 SwiftData ストア | **有効化済み**。`AppDelegate.application(_:didFinishLaunchingWithOptions:)` → `MemoraNativeBridgeBootstrap.configureSharedAudioStoreOrDefaults()` → `MemoraSharedStoreResolver.resolveSharedStoreURL`（legacy → app group `group.com.memora.shared` への単方向・原子・冪等移行、移行後も legacy 保持）。entitlements に `group.com.memora.shared` |
| bundle ID / Keychain | ADR-004 実装済み。`app.json` と xcodeproj の両方で `com.memora.Memora`。Keychain service は `com.memora.app`（`MemoraRNKeychainSecureCredentials.swift`） |
| STT core | 共有パッケージ `MemoraSharedCore`（`STTService.swift` 等）＋ RN ホスト `MemoraRNTranscriptionBridge.swift` |
| 録音 | RN ホスト `MemoraNativeFileRecordingImportHandler`（AVFoundation）＋ shared SwiftData 永続化 |
| Keychain | `MemoraRNKeychainSecureCredentials`（service `com.memora.app`） |
| Broadcast Extension / Widget | ソース保持（RN 同梱は未実施、§4 参照） |

## 3. RN 機能面の棚卸し

### 3.1 画面 / ルート（`apps/mobile-expo/app/**` と `src/screens/`）

| ルート | 画面 | 備考 |
|---|---|---|
| `(tabs)/index` | HomeScreen（一覧 / 検索 / セグメント / インポート / プロジェクト表示） | `useAudioFiles` + `MemoraNative` |
| `(tabs)/tasks` | TasksScreen（CRUD / 期限グループ / 完了折りたたみ） | `listTasks` / `createTask` / `toggleTask` |
| `(tabs)/ask-ai` | AskAIScreen（scope 切替 / 質問 / 回答表示） | `queryKnowledge` |
| `(tabs)/settings` | SettingsScreen（設定 / 辞書 / API キー / bridge 診断） | dev セクションは `__DEV__` のみ |
| `file/[id]` | FileDetailScreen（概要 / 文字起こし / メモ / 再生 / 共有 / 削除） | transcript は実データ表示（§4-12） |
| `auth` | AuthFlowScreen（onboarding / login / email / code / paywall） | **dev-gated**（`shouldExposeRoute('auth', __DEV__)`） |
| `preview` | PreviewIndexScreen | dev-gated |
| `dev-fonts` | DevFontPreviewScreen | dev-gated |

### 3.2 Native module 公開 AsyncFunction（`modules/memora-native/ios/MemoraNativeModule.swift`）

イベント: `onTranscriptionEvent`。

| カテゴリ | AsyncFunction |
|---|---|
| Audio file | `listAudioFiles` / `getAudioFile` / `renameAudioFile` / `moveAudioFile` / `deleteAudioFile` |
| Tasks | `listTasks` / `createTask` / `updateTask` / `toggleTask` / `deleteTask` |
| 診断 | `getBridgeInfo`（source 一覧 / persistenceScope / isRealDataConnected） |
| 設定 | `loadSettings` / `saveSettings` |
| 語彙 | `listCustomVocabulary` / `saveCustomVocabulary` / `deleteCustomVocabulary` / `setCustomVocabularyEnabled` |
| 資格情報 | `getSecureCredentialStatus` / `deleteSecureCredential` / `presentSecureCredentialInput` |
| 録音 / インポート | `startRecording` / `pauseRecording` / `resumeRecording` / `discardRecording` / `stopRecording` / `importAudio` |
| 検索 | `queryKnowledge` |
| 要約 | `generateSummary` |
| STT | `startTranscription` / `cancelTranscription` |
| 再生 | `loadPlayback` / `playPlayback` / `pausePlayback` / `seekPlayback` / `setPlaybackRate` / `getPlaybackStatus` |
| メモ / 写真 | `getMemoDraft` / `saveMemoDraft` / `listPhotoAttachments` / `addPhotoAttachment` / `deletePhotoAttachment` |
| retry queue | `enqueueProcessingRetry` / `listProcessingRetries` / `recordProcessingRetryFailure` / `completeProcessingRetry` |

### 3.3 facade（`src/native/MemoraNative.ts`）

- ネイティブ呼び出しをラップし、**未接続時は mock 配列へフォールバック**するプラットフォーム分岐（web は `MemoraNativeModule.web.ts`）。
- `MemoraNative.types.ts` に DTO 型（AudioFileDTO / TaskDTO / SettingsDTO / SummaryDTO 等）を定義。
- 契約の正本は `src/native/BRIDGE_CONTRACT.md`。

### 3.4 共有パッケージ提供物（`Packages/MemoraSharedData/Sources/`）

| ターゲット | 提供物 |
|---|---|
| `MemoraSharedSchema` | SwiftData モデル 30 ファイル（AudioFile / Transcript / TodoItem / TodoItemRepository / Project / MeetingMemo 等）+ `MemoraSharedStoreFactory` |
| `MemoraSharedCore` | `STTService` / `CoreDTOs` / `STTConfigurationTypes` / `STTHostContracts` / `AudioChunker` / `SpeechAnalyzerPreflight` / `SpeechAnalyzerService26` / `LLMProvider` / `FeatureDependencySurface` |
| `MemoraSharedSummary` | `AIService` / `SummarizationEngine` / `SummaryGenerationConfig` |
| `MemoraSharedAskAI` | `AskAIRetrievalService` / `KnowledgeIndexingService` / `KnowledgeQueryCore` / `LocalRetrievalEngine` / `AskAIMemoryPrivacyConfiguration` |
| `MemoraSharedData` | `MemoraSharedStoreResolver`（store 解決・legacy→共有移行）/ `MemoraSharedSwiftDataAudioFileStore` / `MemoraSharedSchemaExports` |

### 3.5 Tasks 実データ化（#180）の状態

- **実装済み**。`MemoraNativeBridgeBootstrap.configureSharedAudioStore` が `MemoraSharedStoreTaskBridgeAdapter` を
  `MemoraNativeTaskReaderRegistry` / `MemoraNativeTaskMutationRegistry` に登録
  （`MemoraSharedStoreBridgeAdapters.swift`、`TodoItemRepository(modelContext:)` 経由で共有 SwiftData へ永続化）。
- UI: TasksScreen が `listTasks` / `createTask` / `toggleTask` / `deleteTask` で CRUD。
  `sourceAudioFileId` を持つタスクは Home の録音タイトルと紐づけて表示し、タップで `file/[id]` へ遷移。
- 未接続: 「日付を選択」（Alert）、FileDetail の「タスクに追加」、AskAI の「タスク化」（いずれも Alert のみ）。

## 4. パリティ残差マトリクス

状態の凡例: **実装済み**（bridge/host 配線あり。実機 QA 待ちを含む）/ **一部**（主要経路は実装、残り未接続）/
**未接続**（UI のみ / placeholder）/ **削除により消滅**（SwiftUI 依存で維持対象外）。

| 項目 | 状態 | コード根拠 | 1.0 | 依存 |
|---|---|---|---|---|
| 録音 record | **実装済み** | `MemoraNativeRecordingImportHandler`（AVFoundation）＋ `CaptureFlowProvider`（start/pause/resume/stop/discard）＋ shared SwiftData 永続化。`UIBackgroundModes: audio` **追加済み（2026-08-10）**、`AVAudioSession.interruptionNotification` で割り込み終了後に録音を再開 | 必須 | 実機 QA（マイク権限・バックグラウンド継続の動作確認） |
| インポート import | **実装済み** | `expo-document-picker` → `MemoraNative.importAudio`（HomeScreen `handleImport`） | 必須 | 実機 QA |
| 再生 playback | **実装済み** | `MemoraAVAudioPlaybackController` + `PlayerBar`（FileDetail、seek / rate / transcript 連動） | 必須 | 実機 QA |
| STT | **実装済み** | `MemoraRNTranscriptionHandler` → `STTService`（`SpeechAnalyzerService26` / `SFSpeechRecognizer`）。shared SwiftData `Transcript` へ persist、`onTranscriptionEvent` を emit | 必須 | §8 保護対象、実機 QA（音声認識権限） |
| 要約 summary | **実装済み** | `MemoraSharedStoreSummaryGenerator`（bootstrap で接続）＋ `generateSummary` ＋ API キー（Keychain / Local は不要） | 必須 | API キー設定（実装済み）、provider 選択、実機 QA |
| 検索 search（Ask AI） | **実装済み** | `MemoraSharedStoreKnowledgeQuery`（bootstrap で接続）＋ `queryKnowledge` ＋ `LocalRetrievalEngine`。AskAIScreen は実 bridge を呼ぶ | 推奨 | retrieval 索引・モデル選択。1.0 必須か要判断 |
| 書き出し export | **一部** | Share sheet で title+summary+transcript を共有（FileDetail `handleShare`）。Notion / ChatGPT 行は「1.0対象（準備中）」表示（2026-08-10 文言更新） | **必須** | 契約は `docs/rn-export-contract-2026-08-10.md`（1.0 対象に決定 2026-08-10）、実装は別 PR |
| Tasks | **実装済み（#180）** | `TodoItem` + `MemoraSharedStoreTaskBridgeAdapter` + TasksScreen CRUD。残: 日付選択 / タスク化導線 | 必須 | タスク化導線（FileDetail・AskAI）の配線 |
| プロジェクト move | **一部** | HomeScreen のプロジェクトセグメント表示（`file.project`）+ `moveAudioFile` bridge。FileDetail「プロジェクトに移動」と Tasks シートのプロジェクトは未接続（Alert / 固定「個人タスク」） | 推奨 | move UI wiring（Lane F / G） |
| 設定（基盤） | **実装済み** | settings store（UserDefaults: summaryProvider / transcriptionMode / speechAnalyzerEnabled）、customVocabulary（SwiftData）、API キー（Keychain） | 必須 | なし |
| 設定（連携・未接続行） | **未接続** | Notion / ChatGPT 連携は「1.0対象（準備中）」（2026-08-10 決定・実装は別 PR）。PLAUD / Omi デバイス管理、プッシュ通知（Switch はローカル state のみ）、キャッシュ消去 / 全データ書き出し、ログアウト / アカウント削除、表示言語 / 文字起こし言語、要約テンプレート（固定「議事録」）— Notion / ChatGPT 以外は `notConnected` Alert | スコープ判断 | Notion / ChatGPT 以外は各バックエンド / 契約の決定 |
| 通知 / Widget / Broadcast Extension | **未接続（RN 同梱なし）** | `MemoraWidget/`・`MemoraBroadcastExtension/` はソース保持のみ。RN xcodeproj に target なし。`UIBackgroundModes` は `audio` のみ申告（widget / broadcast 用の申告なし）。Live Activity は SwiftUI 依存のため削除により消滅 | ソース保持は必須 / 同梱はスコープ判断 | 同梱可否・ライブ配信方針の決定 |
| STT transcript 表示 | **実装済み** | FileDetail の文字起こしタブは `file.transcript`（bridge 実データ）を表示。cleanedText 切替、`TranscriptionProgressCard` + `useTranscriptionTask` で実 STT 開始、segment tap で seek+play | 必須 | 実機 QA |
| 認証 / ペイウォール | **未接続（UI のみ・dev-gated）** | `AuthFlowScreen` は onboarding/login/email/code/paywall フローを実装するが、外部認証・コード送信・購入は「準備中」Alert。`releaseGate.ts` の `DEV_ONLY_ROUTES`（auth / preview / dev-fonts）で release ビルドから到達不能 | スコープ判断（要決定） | 認証バックエンド・IAP の契約 |
| Privacy / Info.plist | **一部** | `PrivacyInfo.xcprivacy` あり（UserDefaults CA92.1 / FileTimestamp C617.1 / SystemBootTime 35F9.1。CollectedDataTypes 空、Tracking false）。`ITSAppUsesNonExemptEncryption=false` **追加済み（2026-08-10）**。`UIBackgroundModes: audio` **追加済み（2026-08-10、app.json と RN ホスト Info.plist の両方）**。マイク / 音声認識 / フォトライブラリの usage description はあり | 必須（審査項目） | 実機でのバックグラウンド録音動作の確認 |
| 共有 SwiftData store | **実装済み** | ADR-004 実装（#172/#173）。`MemoraSharedStoreResolver` + `group.com.memora.shared` entitlements + `configureSharedAudioStoreOrDefaults` | 必須 | 実データ移行・rollback の実機検証（gate b）は未実施 |
| `MemoraTests/`（旧 SwiftUI テスト） | **削除済み（2026-08-10）** | RN ビルドに未参照の孤立残存だったため `git rm -r` で削除 | 対応済み | なし |

## 5. 1.0 スコープの推奨

1.0 スコープ未確定のため、以下は監査結果に基づく推奨（確定はオーナー判断）。

### 5.1 実装順（推奨）

1. **実機 QA 基盤（Lane E / G）**: 録音 → STT → 要約 → 再生の一連フローを実機で確認。マイク・音声認識の
   permission flow と `ITSAppUsesNonExemptEncryption` / Privacy 申告の最終確認（gate a / d / e）。
2. **release hardening（Lane D / F / G）**: `xcodebuild archive -scheme MemoraRN` 相当の release ビルド成立、
   auth / preview / dev-fonts の release 到達不能確認、`qa:ios:test` を CI へ組み込むかローカルで実施（gate c）。
3. **Tasks / export 導線の仕上げ（Lane F）**: FileDetail「タスクに追加」・AskAI「タスク化」の配線（`sourceAudioFileId`）、
   日付選択、Share sheet 書き出しの文言整理（gate a の一部）。
4. **プロジェクト move の UI wiring（Lane F / G）**: `moveAudioFile` の UI 接続（推奨枠）。
5. **検索（Ask AI）の 1.0 判定（Lane C）**: retrieval 品質と API モデル選択の成立確認（推奨枠）。

### 5.2 要ユーザー決定事項

- **「バックグラウンド録音」** → **2026-08-10 に「できるようにする」と決定**（`UIBackgroundModes: audio` を app.json / RN ホスト Info.plist に追加済み。割り込み終了時の録音再開も実装済み。実機確認は残課題）。
- **認証方式とペイウォールの有無**: Apple / Google / メール OTP のどれか、IAP（RevenueCat 等）を使うか。
- ~~Notion / ChatGPT 連携の 1.0 対象可否~~（export 契約）→ **2026-08-10 に 1.0 対象で決定**（契約: `docs/rn-export-contract-2026-08-10.md`、実装は別 PR）。
- **Widget / Broadcast Extension の RN 同梱**を 1.0 で行うか（Live Activity は SwiftUI 依存で消滅したため、動的アイランド方針の再決定を含む）。
- **検索（Ask AI）の 1.0 必須 / 推奨**の判定。
- **root `MemoraTests/`（孤立）は 2026-08-10 に削除済み**。

## 6. 実機 QA・rollback 手順の現状と未実施事項

### 6.1 実機 QA

- **未実施**（本監査時点。実機 QA は後回しと明記された前提）。
- 現状の検証は CI（`rn-ios-build` は `build-for-testing` のみで**テスト実行なし**）+ ローカル `qa:ios:test` +
  `swift test --package-path Packages/MemoraSharedData`。
- 未実施事項: 実録音のマイク権限フロー、実音声の STT 精度・話者分離、実ファイルの要約（API キー実接続）、
  共有ストア移行の実機確認、バックグラウンド時の録音継続の実機確認（`UIBackgroundModes: audio` 追加済み・2026-08-10）。

### 6.2 rollback 手順

- `docs/rn-full-cutover-execution-plan.md` §11 に段階別 rollback 表あり（M6 の SwiftUI 削除 rollback = 削除 PR の revert）。
- **未実施事項**: gate b の「実データ移行 → rollback の実機検証」、T8（rollback ドリル）は未実施。
  共有ストア移行は実装済みだが、実機での移行・rollback 確認が 1.0 前に必要。

## 7. 検証

| コマンド | 結果 |
|---|---|
| `git status` | clean（作業前） |
| `git rev-list --left-right --count origin/main...HEAD` | `0 0`（origin/main と同期） |
| `git diff --check` | pass |
| 変更ファイル | `docs/**` のみ |

> 本監査は read-only。コード・設定・CI は変更していない。監査対象のコード根拠は上記の各行に記載したファイル / 行を参照。
