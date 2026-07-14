# 外部レコーダー連携計画（PLAUD UX改善 + 他社デバイス取り込み）

Last updated: 2026-07-13
Status: Draft（Web検証未実施の項目に ⚠️要検証 マークあり — 実装前に各社公式ドキュメントで確認すること）

## 0. 前提

- 既存の拡張ポイント: `Memora/Core/Capture/CaptureSource.swift` プロトコル + `CaptureSourceRegistry`。
  接続階層は `ConnectionTier`（bleDirect=0 / cloudSync=1 / fileImport=2）で表現済み。
- 実装済みソース: `OmiAdapter`（BLE直結）、`GenericFileSource`（汎用ファイル取り込み）。
- PLAUD向け資産: `PlaudImportService`（エクスポート音声+JSON/TXT取り込み、話者数抽出付き）、
  `PlaudExportModels.swift`（エクスポートJSONスキーマ）— **実装済みだがV6 UIから未配線**。
- 方針: App Store販売を前提とするため、**非公式API・リバースエンジニアリング経路は製品機能にしない**
  （`PlaudService.swift` の互換APIクライアントは `#if DEBUG` に格納する。docs/rn-expo-ui-polish-handoff.md とは別件）。

## 1. 他社デバイスの連携手段マップ

### Tier A: 公式APIあり（cloudSync として統合可能）

| デバイス | 連携手段 | 実現性 | 備考 |
|---|---|---|---|
| **Limitless Pendant** | 公式 Developer API（APIキー認証、lifelogs エンドポイントで文字起こし/要約を取得） | ◎ 最有力 | ⚠️要検証: 音声ファイル自体のダウンロード可否とレート制限。テキストのみでも `referenceTranscript` として価値がある。ユーザーが自分のAPIキーを入れるBYOK方式なのでApp Store審査上も安全 |
| **Bee (bee.computer)** | 開発者API（会話・文字起こし取得） | △ | ⚠️要検証: 2025年のAmazon買収後にAPIが継続しているか。継続していればLimitlessと同型で実装可能 |

### Tier B: 公開BLEプロトコル（bleDirect — 実装済みパターンの横展開）

| デバイス | 連携手段 | 実現性 | 備考 |
|---|---|---|---|
| **Omi (Based Hardware)** | オープンソースBLEプロトコル（Opusストリーミング） | ✅ 実装済み | `OmiAdapter` |
| Omi互換DIYデバイス（XIAO等） | 同上プロトコル | ○ | OmiAdapterがそのまま使える可能性。優先度低 |

### Tier C: ファイルベース（fileImport — 追加実装ほぼ不要で対応デバイスが一気に広がる）

| デバイス | 連携手段 | 実現性 | 備考 |
|---|---|---|---|
| **PLAUD Note / NotePin** | 公式アプリの書き出し（音声 + JSON/TXT）→ 共有/Files | ◎ 本計画の主対象 | §2で詳細設計。公式APIは無い ⚠️要検証: 2025年後半に発表された「PLAUD Open Platform」系の動きがあれば方針見直し |
| **Sony ICD / OM System / Tascam / Zoom Hシリーズ** | USB-C接続（iPhone 15+）→ Filesアプリでマスストレージとして見える | ◎ 既に動く | `GenericFileSource` で取り込み可能。UX改善（複数選択・フォルダ一括）だけで「対応」を謳える |
| **DJI Mic 等ワイヤレスマイク** | 内蔵ストレージ→USBマスストレージ | ◎ 既に動く | 同上 |
| **iFLYTEK / Notta Memo / Viaim 等** | 各社アプリからの書き出し→共有 | ○ | 閉じたエコシステム。共有シート経由の汎用取り込みで受ける |

### 対象外（実装しない）

- PLAUD NoteへのBLE直結（プロトコル非公開・音声を第三者に公開していない）
- 非公式クラウドAPI経由の同期（App Storeリスク。DEBUGビルド限定に格納）
- Apple Watch単体録音（North Star P3、別Epic）

### 結論

1. **最優先: PLAUD書き出し取り込みのUX改善**（§2）— 資産が既にあり、配線とShare Extensionだけで劇的に良くなる。
2. **次点: USBレコーダーの複数ファイル一括取り込み**（§3）— 数行の変更でSony/Tascam/Zoom/DJIを「対応デバイス」にできる。
3. **その次: Limitless公式API連携**（§4）— 新規`CaptureSource`アダプタ1個。ただしAPI仕様の検証が先。
4. Beeは Limitless 完成後にAPI存続を確認してから判断。

## 2. PLAUD取り込みUX改善（主対象）

### 現状の体験（悪い）

PLAUDアプリで書き出し → Filesに保存 → Memoraを開く → FAB → インポート → ファイルを1個選ぶ
→ **JSONメタデータ（PLAUD側の文字起こし・要約）は捨てられる**（PlaudImportServiceが未配線のため）。

### 目標の体験

**経路1（メイン）: 共有シート直行**
PLAUDアプリで書き出し → 共有シートで「Memora」をタップ → Memoraが開き、取り込み完了スナックバー
→ ファイル一覧の先頭に出現。音声+メタデータが揃っていれば文字起こし・要約も引き継がれた状態。

**経路2: アプリ内インポートの自動判別**
FAB → インポート → 複数選択可のファイルピッカー → PLAUDエクスポートのペア
（同名の .m4a + .json/.txt）を自動検出して `PlaudImportService.importFromExport` へルーティング。
ユーザーは「PLAUD用ボタン」を探す必要がない。

### 実装タスク

#### 2-1. V6インポートの複数選択 + PLAUD自動判別（Lane A+C、先行PR）

**現状（2026-07-13時点の実コード）**:
- `ContentView.importContentTypes` は既に `.mpeg4Audio, .wav, .mp3, .aiff, .json, .plainText` を含む。
- `ContentView.fileImporter` は既に `allowsMultipleSelection: true`。
- **未実装なのはルーティング**: `handleImportResult` は選択URLを1個ずつ `importAudioFile`
  （= `AudioFileImportService.importAudio`）に渡すだけ。そのため .m4a + .json のペアを選ぶと
  .json が汎用インポートに流れて失敗し、.m4a はメタデータなしで取り込まれる。
  `PlaudImportService` は完成しているのに一度も呼ばれない。

**やること**:
- `ContentView.handleImportResult` を、URL群を basename でグルーピングしてから振り分ける形に変更。
  グルーピング/判定ロジックは取り込みルータとして新設: `Memora/Core/Capture/ImportRouter.swift`
  1. 選択されたURL群を basename でグルーピング
  2. 音声(.m4a/.wav/.mp3/.aac/.caf) + 同名 .json → JSONを `PlaudExportFile` としてデコード試行
     → 成功したら `PlaudImportService.importFromExport(audioURL:metadataURL:)`
  3. 音声 + 同名 .txt → `PlaudImportService.attachReferenceTranscript`
  4. 音声単独 → 既存の `AudioFileImportService.importAudio`（現行動作）
  5. .json/.txt 単独 → `PlaudImportService.importTextOnly`（参照テキストのみの記録）
- `allowedContentTypes` に `.json`, `.plainText` を追加。
- 取り込み結果はDynamic Islandスナックバー（`V6IslandController`の既存snackbar）で
  「3件を取り込みました」形式で通知。
- UI文言に「PLAUD」を出す場合は「PLAUDアプリの書き出しに対応」という互換性記述に留める
  （商標: 機能名として「PLAUD連携」を大書しない。docs/rn-expo-ui-polish-handoff.md の方針と同じ）。

#### 2-2. Share Extension（Lane D、別PR — pbxproj変更を伴うため分離）

- 新ターゲット `MemoraImportExtension`（share extension）。
- `NSExtensionActivationRule`: 音声ファイル + public.json + public.plain-text、最大件数 ~20。
- App Group（既に `MemoraSharedData` / 共有ストアの仕組みがある — `MemoraSharedStoreLocation` を再利用）
  経由でコンテナに書き込み、メインアプリ起動時に取り込みキューを消化する方式。
  Extension内でSwiftDataフルスタックを動かさない（起動時間とメモリ制約のため、
  ファイルをApp Groupの `ImportInbox/` に置いてURLスキームでメインアプリを開くだけに留める）。
- メインアプリ側: 起動時+foreground時に `ImportInbox/` をスキャンして 2-1 のルータへ流す。
- 受け入れ条件: PLAUDアプリの共有シートからMemoraが選べ、タップ後Memoraが前面に来て
  スナックバーが出る。メタデータペアが引き継がれている。

#### 2-3. 設定画面の表記修正（Lane A、小PR）

- 「PLAUD / Omi デバイス管理」行（V6AppShellView.swift:568）を実態に合わせる:
  - 行名を「録音デバイス」に変更
  - 遷移先で Omi=BLE接続、PLAUD/その他レコーダー=「書き出しファイルの取り込み方」ガイド
    （経路1/経路2の説明）を表示
- `PlaudService`（非公式API）関連UIを `#if DEBUG` ガードに格納。

## 3. USBレコーダー一括取り込み（ついでに広がる対応）

2-1 の複数選択対応だけで、USB-C接続したSony/Tascam/Zoom/DJI等のレコーダーから
Filesアプリ経由で複数ファイルを一括取り込みできるようになる。追加作業:

- 取り込み時にファイルの作成日時メタデータを `AudioFile.createdAt` に反映
  （現状はインポート時刻になる — レコーダー録音は数日前のものが多いため重要）。
  `URLResourceValues.creationDate` を `AudioFileImportService` で読む。
- タイトルはファイル名から拡張子を除いたもの（現行動作でOK）。

## 4. Limitless Pendant 連携（公式API / cloudSync）

⚠️ 実装前に必ず公式ドキュメントで検証すること:
- APIキーの発行方法・利用規約（第三者アプリでの利用が許可されているか）
- lifelogs取得エンドポイントのレスポンス（文字起こし・話者・タイムスタンプの形式）
- **音声ファイル自体を取得できるか**（できない場合はテキストのみの連携になる —
  それでも `PlaudImportService.importTextOnly` と同じ「参照テキスト記録」として成立する）
- レート制限・ページネーション

設計（検証後）:

- 新規 `Memora/Core/Capture/LimitlessAdapter.swift`: `CaptureSource` 準拠、`tier = .cloudSync`。
- 認証: ユーザーが自分のAPIキーを設定画面で入力 → `KeychainService` に保存
  （既存の `.apiKeyOpenAI` 等と同じパターン。BYOK方式なのでOAuth不要・審査上も安全）。
- 同期: 手動「今すぐ同期」ボタン + foreground時の差分取得。取得したlifelogを
  `AudioFile`（音声あり）または参照テキスト記録（音声なし）として `ImportSink` へ流す。
- `SourceType` に `.limitless` を追加（`AudioFile.sourceTypeRaw` のマイグレーション不要 — 文字列raw）。
- UI: 設定 > 録音デバイス に「Limitless」行を追加、接続状態と最終同期時刻を表示。

## 5. 実装順序と競合回避

| 順 | PR | Lane | 依存 |
|---|---|---|---|
| 1 | 2-1 複数選択+PLAUD自動判別ルータ | A(Views) + C(Core/Capture) | なし |
| 2 | 2-3 設定表記修正 + PlaudServiceのDEBUG格納 | A | なし（1と並走可） |
| 3 | 3 作成日時メタデータ反映 | C | 1のルータに乗せる |
| 4 | 2-2 Share Extension | D(pbxproj/新ターゲット) | 1のルータ完成後 |
| 5 | 4 Limitless連携 | B/C | API仕様のWeb検証後 |

- pbxproj を触るのは PR4 のみ（Lane D規約遵守）。
- STTコア（CLAUDE.md §10）はどのPRも触らない。`referenceTranscript` への書き込みは
  既存の `PlaudImportService` 経由のみ。

## 6. App Store観点の注意（本計画に固有）

- Share Extension 追加時、App Privacy の申告対象は変わらない（音声はローカル処理のまま）。
- 「PLAUD」「Limitless」等の商標は互換性の事実記述としてのみ使用し、
  スクリーンショットやキーワード欄で「公式連携」を示唆しない。
- Limitless連携はユーザー自身のAPIキーによるデータ取得であり、ガイドライン5.2.2
  （第三者サービスへの無許可アクセス）に当たらないことをAPI利用規約で確認してから出荷する。
