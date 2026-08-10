# RN Export（Notion / ChatGPT）契約

- 日付: 2026-08-10
- 決定: オーナー決定（ユーザー）
- 種別: 1.0 スコープ確定・契約（実装は別 PR）

## 1. 決定

- **Notion / ChatGPT への書き出し（export）を 1.0 の対象とする**（2026-08-10、オーナー決定）。
- 本ドキュメントは「対象・方式・DTO・bridge・設定 UI の置き場所」を確定する **契約** であり、
  OAuth / API 呼び出し等の**実連携は別 PR で実装**する（本 PR では実装しない）。
- 画面の「未接続」表示は「1.0 対象（実装準備中）」へ更新済み（文言のみ）。

## 2. 対象データ

現在 Share sheet で書き出している内容（`FileDetailScreen.handleShare`）を引き継ぐ。

| 項目 | 内容 | 出所 |
|---|---|---|
| title | 録音タイトル | `file.title` |
| summary | 要約（Markdown） | `file.summary`（`generateSummary` bridge） |
| transcript | 文字起こし（`time text` の行並び） | `file.transcript`（STT bridge / shared SwiftData `Transcript`） |
| action items | 対応（タスク化導線から生成。実装は後続 PR で確定） | Tasks（`TodoItem`）連携を検討 |

> 将来的なスコープ: 添付（写真等）、プロジェクト情報。1.0 では対象外のため契約に含めない。

## 3. 契約（DTO / bridge）

### 3.1 `ExportDestination`

```ts
export type ExportDestination = 'notion' | 'chatgpt' | 'file';
```

- `file`: 現行 Share sheet の「Markdown / TXT / SRT で書き出す」相当（既存 `handleShare`）。
- `notion` / `chatgpt`: 本契約で 1.0 対象。実装は別 PR。

### 3.2 `ExportPayloadDTO`

```ts
export type ExportPayloadDTO = {
  title: string;
  text: string;            // summary + transcript を結合した Markdown テキスト
  createdAt?: string;      // ISO 8601
  sourceFileId: string;    // 共有 SwiftData の AudioFile id
  destination: ExportDestination;
  // 実装 PR で確定する拡張候補:
  // format?: 'markdown' | 'txt' | 'srt';
  // transcriptOnly?: boolean;
  // summaryOnly?: boolean;
};
```

### 3.3 bridge 関数（提案）

```ts
// ネイティブ側で実際の転記処理を行う（トークン管理・API 呼び出しは native のみで扱う方針）
export async function exportToDestination(payload: ExportPayloadDTO): Promise<ExportResultDTO>;
```

```ts
export type ExportResultDTO = {
  ok: boolean;
  destination: ExportDestination;
  refId?: string;      // Notion page id 等。未確定
  error?: string;      // 人間可読のエラー理由
};
```

- 実装時の命名は既存 bridge（`MemoraNative`）の命名規則に合わせて確定する。
- **認証情報・API キーは RN 側に置かず、native（Keychain）側のみで扱う**（CLAUDE.md の Keychain 方針・ADR-004 に準拠）。

## 4. 認証方式（要検討・実装時確定）

| Destination | 方式候補 | 状態 |
|---|---|---|
| Notion | Integration token（`ntn_...`）／ OAuth（AppStore 審査・UX 面） | **要検討**（1.0 でどちらにするかは実装 PR で確定） |
| ChatGPT | 共有テキスト（ショートカット経由のクリップボード / URL scheme / App Intents） | **要検討**（1.0 でどの導線を使うかは実装 PR で確定） |
| file | 現行 Share sheet のまま | 実装済み（変更なし） |

### 未確定事項（実装時に決定し、本契約を更新する）

- Notion: Integration token か OAuth か。scope（page 書き込み先の選択 UI）。
- ChatGPT: 共有の具体的な導線（API 契約は公開されていないため、OS 標準の共有/クリップボード経由を前提に検討）。
- API キー / トークンの保存先とローテーション方針（Keychain 前提）。
- エラー・リトライ・レート制限の扱い。
- 書き出し履歴（成功可否）をアプリ側に残すか。

## 5. 設定 UI（置き場所）

- **Settings の「連携」グループ**（`SettingsScreen.tsx`）:
  - 「Notion に書き出す」「ChatGPT に共有」の 2 行を 1.0 対象として**有効化**する方針。
    - 未接続時: 「1.0 対象（準備中）」表示（本 PR で文言更新済み）。
    - 実装後: 接続状態・認証導線（OAuth / token 入力）・ON/OFF をこの行で扱う。
- **FileDetail の書き出し行**（`FileDetailScreen.tsx`）:
  - 「書き出す」シートの「Notion に転記」「ChatGPT に共有」の接続先をここに配置。
    - 未接続時: 「1.0 対象（準備中）」表示（本 PR で文言更新済み）。
    - 実装後: 接続済みなら実際の転記を実行、未接続なら設定画面への導線を提示。
- 連携行の接続状態は settings store（UserDefaults）に持ち、トークン等は native のみで保持する。

## 6. 実装ステップ（別 PR で進める）

1. 契約確定の受け入れ（本 PR）: parity matrix・release readiness の更新、画面文言の更新。
2. bridge 契約の実装（Lane G）: `exportToDestination` + `ExportPayloadDTO` / `ExportResultDTO` を
   `MemoraNative` に追加し、型を確定。
3. Notion 連携（Lane G / C）: Integration token または OAuth の決定 → native 実装 → Settings「連携」の有効化。
4. ChatGPT 連携（Lane G / C）: 共有導線の決定 → native 実装 → Settings「連携」の有効化。
5. FileDetail 書き出し行の接続（Lane F）: 「Notion に転記」「ChatGPT に共有」の実導線。
6. 実機 QA（Lane E）: 実接続での書き出し・エラー・再認証フローの確認。

### この PR でやらないこと

- 実 API 連携・OAuth・ネットワーク実装
- 認証情報の取り扱い（Keychain 登録等）
- export の実データ作成
