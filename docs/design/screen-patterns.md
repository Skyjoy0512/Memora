# Memora 画面パターン（Screen Patterns）

- 更新日: 2026-08-02
- 前提: 既存IA・ルートは不変。ルート一覧は
  [`screen-inventory.md`](./screen-inventory.md)、遷移は
  [`navigation-flow.mmd`](./navigation-flow.mmd) を参照。
- 関連: [`MEMORA_DESIGN.md`](./MEMORA_DESIGN.md) / [`component-map.md`](./component-map.md) / [`prohibitions.md`](./prohibitions.md)

## 共通の縦構成ルール

1. **1カラム縦並び**。横分割はしない（wide での分割のみ例外可）。
2. **画面見出し**（`largeTitle` / `title1`）= 最上位。ヘッダー内アクションは右端に
   `Button isIconOnly`（44pt以上）。
3. **セクション見出し**（`title3`）+ セクション内容。セクション間は `space.lg`〜`xl`。
4. **メタデータは小さく**（`footnote` / `caption`、wide tracking）で見出しと対比。
5. 画面左右マージン: compact 16pt / regular 20pt。内部リズム 8pt。
6. **主要アクションは右下FAB かヘッダー右**に固定。複数あるならプライマリを1つに。
7. リスト行は `Surface` + `Separator`（ヘアライン）で区切り、カード化しない。
8. 状態（empty / loading / error）は必ず専用ビューで示す（`StateViews` 相当）。

## 1. ホーム / ライブラリ（`(tabs)/index`）

- **階層**: 画面見出し（ホーム）→ ヘッダー内 Select（ファイル / プロジェクト切替）→
  一覧（ファイル: 日付セパレータ付き / プロジェクト: グリッド）→ `NativeTabs.BottomAccessory`（AIコンポーザー）。
- **主要アクション**: 中央FAB（作成メニュー）。ファイル行タップ → file/[id]。
- **状態**: 一覧 loading（`SkeletonGroup`）→ empty（導線付き空状態）→ error（`Alert` + 再試行）。
  切替中は選択トナル + ヘッダーに現在スコープを明示。
- **構成**: `ListGroup` または `Surface` + `Separator`。検索はヘッダーから `search` modal。
- **カードにしない**: ファイル行・プロジェクトタイルを装飾カードにしない。
  プロジェクトは小さな `Surface` タイル（等間隔グリッド、影なし）に留める。

## 2. 録音セットアップ（`record` / fullScreenModal）

- **階層**: 見出し（録音）→ 録音対象（入力・プロジェクト選択）→ 開始ボタン。
- **主要アクション**: 「録音開始」プライマリボタン（`Button primary` + `RecordingWaveform` プレビュー）。
- **状態**: 権限未許可時は `Alert` と設定への導線。マイク未接続・エラーは開始前に防ぐ。
- **構成**: `Input` / `TextArea`（タイトル任意）+ `Select`（プロジェクト）+ `Button primary`。
  ヘッダー右に閉じる（`Button isIconOnly`）。
- **カードにしない**: 対象選択や説明を装飾カードで囲まない。ヘアライン区切りで配置。

## 3. 録音中（アクティブ録音）

- **階層**: **録音状態を最上位に**（赤 + `RecordingWaveform` + `RecordingTimer` + ラベル「録音中」）。
  その下に経過情報（話者数 / 保存先プロジェクト）をメタデータで。
- **主要アクション**: 停止・保存（`RecordingControlFab` = 赤。停止アイコン + 「停止して保存」）。
- **状態**: 録音中は波形が動く。中断（アプリ復帰・権限喪失）は `Alert` + 復帰導線。
  **赤はここでのみ許容**される強力な意味論例外。
- **構成**: 全面 `canvas` + ガラス制御面（`LiquidGlassView`）。`RecordingTimer` は等幅表示で正確に読める。
- **カードにしない**: 波形をカードの中に閉じ込めない。全幅で情報構造を露出する。

## 4. 処理中（Processing）

- **前提**: 録音・インポート・オンライン会議の後、[`navigation-flow.mmd`](./navigation-flow.mmd) の
  `Processing → FileDetail` に続く状態。
- **階層**: 見出し（処理中）+ 何を処理しているか（文字起こし / 要約）+ 進捗。
- **状態**: 決定性進捗は `ProcessingRail` / `ProgressBar`（`dataViz.processing`）、
  不確定・段階不明は `Spinner` + `SkeletonGroup`（文字起こし行の形をスケルトンで示す）。
  エラー時は `Alert` + 再試行。**処理中を示すラベルを必ず併記**（色だけにしない）。
- **構成**: `ProcessingRail` + ステータス `Chip` + キャンセル（`Button tertiary`）。
- **カードにしない**: 進捗を装飾カードで囲まず、ヘアライン + 余白で整理する。

## 5. ファイル詳細（`file/[id]`）

- **階層**: `title1`（タイトル）→ メタデータ行（日時・長さ・話者数・プロジェクト）→
  タブ（要約 / 文字起こし / メモ）で本体。
- **主要アクション**: 再生（`AudioTimeline`）、共有・編集はヘッダー右。
- **状態**: 生成前は `SkeletonGroup`、生成中は `ProcessingRail`、完了で本体表示。
  未生成の項目は生成ボタン + 状態ラベル。
- **構成**: ヘッダー + `Tabs`（画面内）+ `TranscriptSegment` / 要約ブロック / `TextArea`（メモ）。
  要約ブロックは**唯一** `Card` を使ってもよい境界を持った対象物の例。
- **カードにしない**: メタデータ・再生バー・各タブ内容を無意味にカード化しない。

## 6. 文字起こし

- **階層**: 見出し + メタデータ（時刻・話者数）→ `TranscriptSegment` の縦並び。
- **構成**: `TranscriptSegment`（話者ラベル + 時刻 + テキスト）。話者ラベルは
  `dataViz.transcript.speakerLabelWidth` で揃え、読点でなく改行で区切る。
  検索ヒットはハイライト（`selection` トナル + 前景）。
- **状態**: 読み込みはスケルトン行、空は「文字起こしなし」の導線。
  選択中はトナル + テキストで状態を示す。
- **カードにしない**: 各セグメントをカード化しない。ヘアライン区切り + 余白で。

## 7. 要約・タスク

- **階層**: 要約は見出し + 本文（箇条書き可）。タスクは「未完了」を優先表示。
- **構成**: 要約ブロック（`Card` 可）→ `ListGroup` のタスク行（チェックボックス + 期限 `Chip`）。
- **状態**: タスク完了はチェック + 前景を quaternary に。期限超過は `warning` ラベル。
- **カードにしない**: タスク行を装飾カードにしない。`Switch` / `Checkbox` は行内に収める。

## 8. プロジェクト

- **階層**: 見出し（プロジェクト名）→ メタデータ（ファイル数・合計時間）→ ファイル一覧。
- **構成**: ホームのプロジェクト切替から遷移。ファイル行はホームと同じ `Surface` + `Separator`。
- **状態**: empty（ファイル追加導線）/ loading（スケルトン行）。
- **カードにしない**: プロジェクトヘッダーをガラスやカードで装飾しない。ヘアラインで分離。

## 9. Ask AI（`(tabs)/ask-ai`）

- **階層**: 見出し（AI）→ スコープ `Select`（全体 / ファイル / プロジェクト）→
  質問履歴（`ListGroup`）→ 回答。
- **主要アクション**: `NativeTabs.BottomAccessory` のコンポーザー送信。AIタブ内にも入力可。
- **状態**: 回答生成中は `Spinner` + ソース参照 `Chip`。エラーは `Alert` + 再試行。
  参照ソースはタップで file/[id] へ遷移（[`navigation-flow.mmd`](./navigation-flow.mmd)）。
- **構成**: `TextArea`（コンポーザー）+ `Button isIconOnly`（送信）+ `Select`（モデル / Auto）。
- **カードにしない**: 質問・回答それぞれをカードで包まず、`ListGroup` + `Separator` で並べる。

## 10. 設定（`(tabs)/settings`）

- **階層**: 見出し（設定）→ グループ別 `ListGroup`（処理 / データ / アプリ / アカウント）。
- **構成**: `ListGroup` + `ControlField` + `Switch` / `Select`。区分線はヘアライン。
- **状態**: 切替中の保存は `Spinner`（一時）or `Toast`（完了）。危険な操作（データ削除等）は
  `Dialog` で確認。
- **カードにしない**: 設定をカード群にしない。標準のグループ化 `ListGroup` を使う。

## 禁則への誘導

全パターン共通の禁止事項と客観的レビューテストは
[`prohibitions.md`](./prohibitions.md) に集約する。
