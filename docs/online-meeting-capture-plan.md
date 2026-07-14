# Memora Online Meeting Capture Plan

最終更新: 2026-07-13

## 1. 目的

Zoom / Google Meet / Microsoft Teams の会議を、次の3経路から Memora に取り込み、同じ **文字起こし → 要約 → File Detail → Ask AI** パイプラインへ流す。

1. **Chrome 拡張**: ユーザーが参加中の会議タブを明示操作で録音する。
2. **会議アーティファクト連携**: 各サービスが生成した録画・文字起こしを会議終了後に取得する。
3. **参加 Bot**: `Memora Notetaker` が会議参加者として入室し、許可された音声を取得する。

Chrome / Bot 専用の transcript・summary 保存形式は作らない。すべて `AudioFile` / `Transcript` / summary の既存 product path に合流させる。

## 2. 現在地

### すでにあるもの

- `bot-server` の Fastify API、API key 認証、会議予約、30秒スケジューラ。
- 録音、音声前処理、S3 互換ストレージへの upload、完了 / 失敗 webhook の骨格。
- iOS 側の `BotMeetingService`、`ScheduledBotMeeting`、`OnlineMeetingCapture`、設定・予約・履歴 UI。
- Bot 完了後の音声 download と既存 `AudioFile` import の導線。
- Google Meet / Zoom / Teams の platform adapter ファイル。

### まだ実装ではないもの

- 各 platform adapter の実参加 / artifact 取得処理は `TODO`。
- Chrome 拡張 target / package は存在しない。
- 会議 job はメモリ上の `Map` だけで、server restart で消える。
- scheduler は join 失敗を warning にして録音へ進むため、参加できていないのに成功扱いになる余地がある。
- `GET /meetings/:jobID` と iOS の status DTO に field 名の不一致がある。
- 固定 duration timer で終了しており、waiting room / early end / host rejection を状態として扱えない。
- server-side の文字起こし・要約 worker と結果保存がない。

## 3. 製品モード

### Mode A — Chrome Local Capture

ユーザー自身が参加している会議で、拡張ボタンを押して録音する。最初に出す経路。

主な体験:

1. 対象の Meet / Zoom / Teams タブで Memora 拡張を開く。
2. 会議名、録音対象、同意確認を表示する。
3. ユーザー操作で録音開始。
4. 録音中は常時インジケータ、経過時間、停止ボタンを表示する。
5. 音声を小さな chunk として upload し、切断時は IndexedDB から再送する。
6. 終了後に server-side processing を開始し、transcript / summary / todo を生成する。
7. 拡張の side panel と Memora アプリの File Detail の両方から結果を開ける。

技術構成:

- Manifest V3。
- `chrome.tabCapture` はユーザーが拡張を明示的に起動した時だけ使用する。
- service worker で stream ID を取得し、offscreen document で `MediaStream` と `MediaRecorder` を維持する。
- tab 音声を capture した後も会議音声がユーザーへ聞こえるよう、Web Audio で出力へ再接続する。
- 自分のマイクが tab output に含まれない場合に限り、明示許可付き `getUserMedia` と audio mix を追加する。プラットフォームごとに実機検証する。
- content script は URL / title / platform 検出と補助メタデータに限定し、壊れやすい DOM scraping を録音の必須条件にしない。

Chrome 公式仕様:

- `tabCapture`: <https://developer.chrome.com/docs/extensions/reference/api/tabCapture>
- offscreen document: <https://developer.chrome.com/docs/extensions/reference/api/offscreen>

### Mode B — Post-meeting Artifact Import

プラットフォーム側で録画・文字起こしが生成された場合は、音声を再録音せず公式 artifact を優先する。

- Google Meet: Meet REST API から conference record / recording / transcript / transcript entries を取得する。
- Zoom: cloud recording / transcript API の利用可否を account と権限ごとに判定する。
- Teams: Microsoft Graph の meeting transcript / recording を優先し、raw media bot を必須にしない。

同じ会議について Chrome 録音と公式 transcript の両方がある場合、重複 File を作らず1件へ統合する。公式 transcript は `referenceTranscript`、録音音声からの Memora STT は final transcript 候補として比較できるようにする。

Google Meet 公式仕様:

- REST API overview: <https://developers.google.com/workspace/meet/api/guides/overview>
- artifacts: <https://developers.google.com/workspace/meet/api/guides/artifacts>

### Mode C — Participant Bot

会議に `Memora Notetaker` として入室する。Chrome 拡張を使えない不在会議・代理記録向け。

必須 UX:

- Bot 名で録音主体が明確に見える。
- camera off / microphone muted を既定にする。
- host approval / waiting room / denied / removed を状態表示する。
- 録音開始前に organizer の同意を記録する。
- 参加者から見える録音インジケータと、即時停止・削除手段を用意する。

実装方針:

1. まず各サービスの **事後 artifact API** を完成させる。
2. 実参加は `MeetingPlatformAdapter` の背後に置き、公式 media API / managed bot provider を差し替え可能にする。
3. Google Meet Media API は real-time media を取得できるが、現時点では Developer Preview 条件があるため実験 adapter とする。
4. Teams application-hosted media bot は権限・admin consent・Windows Server/Azure 構成が重く、AI meeting agent には transcript API が推奨されているため後段とする。
5. Playwright / Puppeteer によるブラウザ自動参加は、MFA、CAPTCHA、待機室、UI変更、利用規約の影響が大きい。production の唯一の経路にせず experimental fallback に限定する。

参考:

- Google Meet Media API: <https://developers.google.com/workspace/meet/media-api/guides/overview>
- Teams calling bot: <https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/registering-calling-bot>
- Teams real-time media guidance: <https://learn.microsoft.com/en-us/microsoftteams/platform/bots/calls-and-meetings/real-time-media-concepts>

## 4. 共通アーキテクチャ

```text
Chrome Extension ─┐
Platform Artifact ├─> Capture Ingestion API ─> Object Storage
Participant Bot ──┘              │
                                 ├─> Processing Worker
                                 │   ├─ transcription
                                 │   ├─ speaker/timestamp normalization
                                 │   ├─ summary / todo
                                 │   └─ searchable chunks
                                 │
                                 └─> Result API / signed webhook
                                             │
                                      Memora iOS/macOS/RN
                                             │
                                      File Detail / Ask AI
```

### 共通 capture contract

最低限、全経路が次を返す。

- `captureID`
- `source`: `chrome_extension | platform_artifact | meeting_bot | macos_local | watch`
- `platform`: `google_meet | zoom | teams | other`
- `meetingURLHash`。生 URL は必要期間を超えて保持しない。
- `title`, `startedAt`, `endedAt`, `duration`
- `consentAttestedAt`, `consentActor`
- `audioArtifact`, `referenceTranscript`, `participants`
- `status`, `stage`, `errorCode`, `retryable`
- `audioFileID` または Memora 側の import token

### 状態遷移

```text
scheduled -> joining -> waiting_room -> capturing -> uploading
          -> processing -> completed

各状態 -> failed / cancelled
```

`join` に失敗した job は `capturing` へ進めない。終了は固定 timer だけでなく、platform event、capture stream end、ユーザー停止を扱う。

### Processing 方針

- Chromeで「録音→要約」まで完結させる場合は cloud processing を明示 opt-in にする。
- audio / transcript / summary の保持期間をユーザー設定可能にする。
- provider 送信前に provider 名、送信対象、削除方針を表示する。
- server worker の出力は既存 Core DTO へ変換し、iOS の `STTService` 実装を server へ複製しない。
- local-first を選ぶユーザーには、音声だけを暗号化保存し、Memora アプリが取得後に既存 STT を実行する経路も残す。

## 5. セキュリティ・プライバシー

- 録音は必ずユーザーの明示操作または事前予約と organizer consent を起点にする。
- 隠し録音、無表示の自動開始、参加者になりすます Bot は実装しない。
- upload は短命な署名 URL を使い、拡張へ S3 credential を配布しない。
- API key 1本ではなく、ユーザー認証、device token、scope 付き capture token へ移行する。
- webhook は署名、timestamp、replay protection、idempotency key を持つ。
- meeting URL、参加者名、音声、transcript は別々の retention と削除処理を持つ。
- platform OAuth token は暗号化保存し、ログへ出さない。
- 録音可否・同意要件は国、組織、会議サービスの規約で異なるため、リリース前に法務確認する。

## 6. PRロードマップ

### OM-0 — Contract hardening

- server / iOS の status DTO を一致させる。
- `MeetingPlatformAdapter` / `CaptureArtifact` / state machine を定義する。
- join failure を握りつぶさない。
- DB 永続化、idempotency、signed webhook を追加する。

### OM-1 — Chrome capture PoC

- `apps/chrome-extension` に MV3 雛形を追加する。
- Google Meet 1タブで user gesture → tab audio capture → WebM/Opus 保存を実証する。
- 録音中インジケータ、停止、tab audio 再生維持を確認する。

### OM-2 — Chunk upload and recovery

- 30〜60秒 chunk upload、IndexedDB queue、再送、cancel、checksum。
- presigned upload と capture status API を追加する。
- 60分会議でメモリが増え続けないことを確認する。

### OM-3 — Transcription and summary worker

- upload 完了 event から transcription / summary job を作る。
- progress、retry、provider error、partial artifact を保存する。
- extension side panel と Memora アプリへ結果を返す。

### OM-4 — Google Meet productization

- Meet URL / title 検出、録音復旧、artifact API import、重複統合。
- 実会議で録音 → transcript → summary → File Detail を end-to-end 検証する。

### OM-5 — Platform artifact adapters

- Zoom cloud recording / transcript。
- Teams Graph transcript / recording。
- OAuth consent、権限不足、artifact 未生成を明示する。

### OM-6 — Bot provider abstraction

- participant bot adapter 契約を追加する。
- waiting room、host denied、removed、meeting ended event を実装する。
- 1プラットフォームまたは managed provider で end-to-end を成立させる。

### OM-7 — Official real-time adapters

- Google Meet Media API preview adapter を検証する。
- Zoom / Teams は公式要件・審査・インフラ費を再評価してから個別 PR にする。
- browser automation は experimental flag の下だけで検証する。

### OM-8 — Production readiness

- retention / delete / export / audit log。
- concurrency、cost cap、dead-letter queue、observability。
- Chrome Web Store / OAuth verification / platform app review。
- 録音同意、Privacy Policy、利用規約、削除要求フロー。

## 7. 優先順

1. OM-0 Contract hardening
2. OM-1 Chrome capture PoC
3. OM-2 Chunk upload and recovery
4. OM-3 Transcription and summary worker
5. OM-4 Google Meet productization
6. OM-5 Post-meeting artifact adapters
7. OM-6 Participant Bot MVP
8. OM-7 / OM-8

Chrome拡張を先にする理由は、ユーザー操作で権限と録音開始が明確になり、Botのプラットフォーム審査・待機室・専用インフラを待たずに「オンライン会議→要約」の価値を検証できるため。

## 8. 完成条件

- Chrome の Meet タブで録音開始・停止でき、会議音声を聞き続けられる。
- 60分録音を chunk upload し、Chrome / network 再接続後に回復できる。
- 録音終了後、transcript / summary / todo が生成される。
- 同じ会議が Memora の1つの File Detail として表示される。
- Bot が少なくとも1経路で会議参加し、waiting room / rejected / recording / processing / completed を正しく表示する。
- 録音同意、削除、retention、provider送信先がユーザーから確認できる。
