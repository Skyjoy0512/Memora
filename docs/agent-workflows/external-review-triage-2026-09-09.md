# 外部レビュー指摘（R01–R20）コード照合結果（2026-09-09）

- レビュー対象: PR #212（`chore/opencode-20260816`）
- レビュー時 HEAD: `771c66df` = 現在の PR ブランチ HEAD（**コードはレビュー時から未変化**）
- 現在の main: `bc73cd71`（docs のみ。v2 刷新・波2 実装は未マージのため、**照合は PR ブランチ基準**）
- 照合方法: 各指摘の対象関数・処理を PR ブランチの実コードで確認（ファイル:行つき）
- 分類: **修正済み / 未対応 / 要再現（実機・障害注入が必要）/ 指摘不成立**

## 分類サマリ

| 分類 | 件数 | 該当 |
|---|---|---|
| 修正済み（2026-09-09・wave2〜7） | 17 | R01〜R17 |
| コード改善済み・要実機確認 | 3 | R18〜R20 |
| 未対応 | 0 | — |
| 指摘不成立 | 0 | — |

※ R18〜R20 はコード上の改善を実装済み。割込み・AudioSession・DB保存失敗の再現確認は
実機QA・障害注入で実施する（完了扱いにしない）。

### wave 4〜7 追記（2026-09-09 深夜: 全 R コード対応完了）

全指摘のコード対応が完了。最終 push `43817891`（PR #212 は 38 コミット構成）。
統合検証は各 wave で npm test（133件） / typecheck / web export / git diff --check 全て pass。

| ID | コミット | 内容 |
|---|---|---|
| R10 | `ae7ad6c9` | 一覧の50件上限を撤廃し保存層から全件取得へ |
| R17 | `40670024` | Markdown/TXT/SRT 表記を実際の共有動作（共有シート）に一致 |
| R04 | `5cce3e79` | Ask AI（OpenAI）キー行を通常設定へ追加 |
| R09 | `29e70a9d` | 削除時に音声・メモ・写真の実体も削除（所有範囲限定・冪等） |
| R06 | `8f2da101`+`a7ec4e9f` | STT/話者識別を設定ストア接続・テンプレートを要約へ反映・設定UI整理 |
| R15 | `dd9c3103` | Ask AI セッション・履歴（直近6件・各800字）の引き継ぎ |
| R11 | `727298be` | 次のアクションを actionItems 明示 DTO へ接続・タスク追加導線 |
| R16 | `8dd934d2` | Ask AI を回答生成 API（generate）へ切替 |
| CI | `b266e94d` | GitHub Actions に vitest（npm test）を追加 |
| R14 | `ee8a413a` | ユーザーメモを Ask AI file スコープ参照へ含める |
| R18 | `05260c0c` | ユーザー一時停止を割込み自動再開から除外（要実機確認） |
| R20 | `dbc15343` | 録音保存（DB upsert）失敗時に再試行可能な状態を保持（要実機確認） |
| R19 | `acc6034f` | AudioSession 再生用変更を再生開始時へ遅延（要実機確認） |

## 修正進捗（2026-09-09: R07 / R08 / R12 / R13 を実装・統合済み）

PR #212（`chore/opencode-20260816`）に下記を追加し、統合検証（npm test 101件 / typecheck /
web export / git diff --check）は全て pass。push 済み（`052aa12d`）。

| ID | コミット | 内容 |
|---|---|---|
| R08 | `45a3a3e4` | Notion/ChatGPT 書き出しに共有トグル（要約/文字起こし）を反映。exportLogic に選択オプション追加＋4通りテスト8件 |
| R12 | `e07bd957` | 辞書適用を保存時1回に一元化し、DTO 読込時の再適用を撤去。二重適用回帰テスト2件追加（iOS テストは CI で検証） |
| R13 | `876ccd07` | STT キャンセル時にタスク状態を終端（cancelled）へ確定し running 残留を防止 |
| R07 | `3c4343bd` | Tasks 画面を useFocusEffect によるフォーカス復帰時再取得に変更 |

### wave 3（2026-09-09: R01 / R02 / R03 / R05 を実装・統合済み）

PR #212 に下記を追加。統合検証（npm test 124件 / typecheck / web export / git diff --check）
は全て pass。push 済み（`c2907342`）。

| ID | コミット | 内容 |
|---|---|---|
| R01 | `fdbec565` | withNative の try/catch 除去。native 不在時のみサンプルフォールバック、実処理の throw は呼び出し元へ伝搬（テスト11件追加） |
| R02 | `599f8aa6` | runGeneration を固定 delay から STT 完了イベント駆動へ変更（transcriptionWait ヘルパー＋テスト9件） |
| R03 | `10848e11` | 「生成をスキップ」が生成を開始しないよう導線を修正（モーダルを閉じるのみ・STT/要約0回） |
| R05 | `aed1c9a3` | FileDetail→/ask-ai へ audioFileId を渡し、AskAIScreen が対象スコープを初期化・表示・リクエストへ反映（テスト3件追加） |

残る未対応 8 件（R04 / R06 / R09〜R11 / R14〜R17）と要再現 3 件（R18〜R20）は下表のとおり。

## 照合表

| ID | 現状 | 現在の根拠（PR #212 = 771c66df） | 対応方針 | 検証方法 | 依存関係 |
|---|---|---|---|---|---|
| R01 | 未対応 | `src/native/MemoraNative.ts`: `withNative`(217-226) が throw を全て捕捉し undefined 化。startRecording(494-505)・stopRecording(516-525)・importAudio は native 結果が無い/失敗時にサンプル成果物を返す | native 不在（web/デモ）と native 実処理の失敗を分離。失敗は throw で呼び出し元へ伝搬 | 録音開始・停止・保存を各失敗させ成功画面へ進まないこと（ユニット＋実機） | デモ環境判定の設計 |
| R02 | 未対応 | `CaptureFlowProvider.tsx` runGeneration: startTranscription 後に `delay(650)` 固定待ち（302-322）。native は start 時に running を返し完了イベントは別経路 | 固定遅延を廃止し completed イベント完了を待つ。failed/cancelled では要約開始しない | 650ms 超・即時完了・失敗・キャンセルの4系（native テスト＋実機） | STT イベント契約 |
| R03 | 未対応（要確認） | `CaptureFlowProvider.tsx`: 生成オプション画面の「生成をスキップ」(522-529) が `onSkip`→`startGeneration`→`runGeneration` に接続（166-179, 224）。ラベルは「スキップ」だが生成を開始する構造 | 「設定を飛ばして生成」なのか「生成せず詳細へ」なのか仕様確定後、導線を張り分け | スキップで STT/要約呼び出しが0回になるケースを確認 | プロダクト意図の決定 |
| R04 | 未対応 | `MemoraSharedStoreKnowledgeQuery.swift:51-54`: OpenAI キー固定・`.openAI` 固定。`AskAIScreen.tsx:69` も OpenAI キーを確認。Settings 既定 Gemini で切替は開発者セクション（SettingsScreen.tsx:245-280） | Ask AI と通常設定のプロバイダー/キー条件を一致させる（UI 事前チェックと native 必要条件の統一） | Gemini のみ設定時に Ask AI を使えない状態を解消・検証 | 設定モデルの設計判断 |
| R05 | 未対応 | `FileDetailScreen.tsx:518`: `/ask-ai` へパラメータ無し push。`AskAIScreen.tsx:47-49`: audioFileId/projectId は useState(undefined) で経路未実装と明記 | ルートパラメータで対象 ID を受け取り表示・リクエストを一致。存在しない/削除済み/全体切替も検証 | FileDetail→Ask AI で対象付き質問が届くこと | ルーティング契約 |
| R06 | 未対応（一部確認） | Settings の要約モデル/テンプレート行は `notConnected`（準備中）。`MemoraRNTranscriptionBridge.swift:296` は `isSpeechAnalyzerEnabled=true / isSpeakerDiarizationEnabled=false` 固定。native に templateId 消費なし（grep で該当なし） | 設定→Bridge→処理パラメータの接続。未対応項目は利用可能に見せない | 設定値が STT/要約へ届くこと（native テスト） | 設定 DTO の設計 |
| R07 | 未対応 | `TasksScreen.tsx:61-79`: マウント時 `useEffect` のみで取得。フォーカス復帰時の再取得なし | useFocusEffect での再取得 or 共有キャッシュ無効化 | 他画面で変更→戻って反映されること | — |
| R08 | 未対応 | `FileDetailScreen.tsx:391-420`: runNotionExport/runChatGptExport はトグルを渡さず `buildExportPayload(file,'notion'/'chatgpt')`。`exportLogic.ts:32-42` は summary+transcript を常時両方含む（トグルは handleShare(274-285) のみ参照） | 全共有先で共通の「選択済みペイロード」を使う。要約×文字起こし4通りを各先で検証 | exportLogic 単体テスト＋各先ペイロード検査 | — |
| R09 | 未対応 | 削除は `MemoraSharedStoreBridgeAdapters.swift:87-93` の `store.delete(id)` のみ。`AudioFileRepository.swift:61-68` もレコード削除のみ。音声実体・`memo-notes.json`・写真ディレクトリ削除なし | アプリ所有の音声/分割音声/メモ/写真の削除と再試行を設計。import 原本は対象外 | 関連データを持つレコード削除→実ファイル・再起動後状態確認（障害注入） | 所有範囲の設計 |
| R10 | 未対応 | `MemoraSharedStoreBridgeAdapters.swift:25-27`: `fetchPage(offset:0, limit:50)`。Home 検索は取得済み配列を filter（HomeScreen.tsx:85-92） | ページング＋保存層検索の接続 | 51件/100件で最古が検索・一覧に出ること | 検索 API 設計 |
| R11 | 未対応 | `adapters.swift:96-107`: memo に `Stored path: ファイル名` を格納。`FileDetailScreen.tsx:584-603` が memo を次のアクション表示・`memo.length` をタスク件数表示。actionItems は DTO に未接続 | actionItems/keyPoints/タスクを明示 DTO 化し内部情報の流用を廃止 | アクション0件/2件データで表示と件数を検証 | DTO 設計 |
| R12 | 未対応 | persist で辞書適用済み `cleanedSegmentTexts` を保存（`MemoraRNTranscriptionBridge.swift:135-139`）→ DTO 生成時に `transcriptDTOs` が再度 `vocabularyApplier.apply`（adapters 116-127）＝二重適用 | 補正前文字列から1回だけ適用に統一。再適用方針を定義 | STT保存→DTO読込を通した回帰テスト（既存テスト 337-374 では未検出） | 補正データ設計 |
| R13 | 未対応（要再現） | `useTranscriptionTask.ts:64-76`: cancel は native 応答後に購読解除するが task.status を更新しない。native は cancel 要求のみで終端イベント完了を待たない | キャンセル確認→状態更新→購読解除の順序を定義。終端イベント前後両方を検証 | cancel→running 残留の再現（実機）＋状態遷移テスト | STT 状態契約 |
| R14 | 未対応 | RN メモは `MemoraNativeFileMemoStore()`（Bootstrap:32）→ `Documents/…/memo-notes.json`。Ask AI は SwiftData `MeetingMemo` を参照（`KnowledgeQueryCore.swift:617-619`） | 保存先統一 or 同期・検索接続。既存 JSON メモ/写真の移行検討 | メモ固有文で検索・回答を検証 | 保存層の設計判断 |
| R15 | 未対応 | `askAiLogic.ts:52-63`: リクエストに履歴/sessionId なし。native は毎回新規 session を作成し過去を読まない（`MemoraSharedStoreKnowledgeQuery.swift:48-63`） | セッション維持と必要な履歴の入力含め。追記処理を整備 | 追質問（短くして/2つ目）の連続動作 | セッション契約 |
| R16 | 未対応（要確認） | `MemoraSharedStoreKnowledgeQuery.swift:49-56`: 回答生成に `provider.summarize(transcript:)` を使用（要約用 API）。品質影響はモデル実行で要確認 | 回答用 generate/専用 API へ切替え。固定質問で旧処理と比較 | 同一質問での新旧比較 | LLM API 契約 |
| R17 | 未対応 | `FileDetailScreen.tsx:951-956`: 行ラベルは Markdown/TXT/SRT だが実体は `Share.share`（文字列のみ、274-285）。native は `.file` destination 未対応（`MemoraRNExportHandlers.swift:62-69`） | 表示を現実に合わせる or 形式別書き出しを実装（SRT は時刻仕様要確認） | 各形式の出力検査 | 書き出し仕様 |
| R18 | 要再現 | `MemoraRecordingBridgeDTO.swift:111-118,194-218`: pause 後も activeRecorders に残り、割込み終了時に全 activeRecorders を record() 再開 | 停止理由を状態化しユーザー停止は自動再開しない | 一時停止→割込み→復帰の実機確認 | 録音状態設計 |
| R19 | 要再現 | `usePlayback.ts:13-19` + `MemoraPlaybackDTO.swift:73-82`: 詳細表示の load で AVAudioSession を .playback へ変更・有効化 | 録音と再生の AudioSession 管理を統一 | 最小化→別詳細→録音終了の実機確認 | AudioSession 設計 |
| R20 | 要再現 | `MemoraRecordingBridgeDTO.swift:91-108,302-317`: activeRecorders から除去後に DB upsert。失敗時は session 消滅で再試行不可 | 保存成功まで復旧情報を保持。暫定レコード/再起動時救済を検討 | DB 保存失敗注入→再試行・再起動で救済 | 保存層の設計 |

## 横断課題の照合

- **CI**: `.github/workflows/ci.yml` は shared-data `swift test` / expo typecheck+export / rn-ios-build+qa:ios:test / bot-server build。
  **vitest（`npm test`）は CI に含まれていない** → 追加が必要（未対応）。
- **exportLogic.test.ts:50-75**: トグル未接続の検証なし → R08 修正時に回帰テスト追加。
- **MemoraSharedStoreBridgeAdapterTests.swift:337-374**: 辞書二重適用は未検出 → R12 修正時に回帰テスト追加。
- **fontSize 直書き残3件**: `app/(tabs)/_layout.tsx:46`(11) / CaptureFlowProvider islandTimer(12) / recordingTime(44)。
  いずれも新トークン追加 or 設計判断が必要（変更せず判断保留）。
- **hitSlop**: PlayerBar シークバーは非干渉上限 top/bottom8（実効28pt）で44未達の判断保留。要レイアウト変更 or 実機確認。
- **Ask AI 履歴の説明と永続化**: `AskAIScreen.tsx:391`「アプリを閉じると消えます」の一方、native は
  AskAISession/AskAIMessage を毎回 SwiftData へ保存（`MemoraSharedStoreKnowledgeQuery.swift:58-63`）→ 説明と実態の不一致（未対応・要設計）。
- **メモ・写真の共有ストア移行**: DB 移行のみならず実体とパス参照の確認が必要（R09/R14 と一体）。

## 所見

- レビュー時 HEAD（771c66df）と現在の PR ブランチは一致しており、**指摘の前提コードは全て現存**。
- 分類上「修正済み」はゼロ。ただし波2 で実施済みの hitSlop（rateButton/AskAI対象行）・FileDetail 残骸削除・
  T1 失敗画面は本レビュー対象（PR #212）に含まれており、指摘対象外。
- 大半は「native と RN の接続・設計判断」で、安全な即時修正は R07 / R08 / R12 / R13（＋R10 の UI 側）に限られる。
- R18–R20 はコード上リスクを確認済みだが、分類上は「要再現」として実機・障害注入を待つ。
