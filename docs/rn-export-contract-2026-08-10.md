# RN Export（Notion / ChatGPT）契約

- 日付: 2026-08-10
- 決定: オーナー決定（ユーザー）
- 種別: 1.0 スコープ確定・契約（**実装完了 2026-08-10**）

## 1. 決定

- **Notion / ChatGPT への書き出し（export）を 1.0 の対象とする**（2026-08-10、オーナー決定）。
- 本ドキュメントは「対象・方式・DTO・bridge・設定 UI の置き場所」を確定する **契約** であり、
  **実装（PR #191）で確定済み**。OAuth / WebView 認証は 1.0 対象外。
- 認証情報は native（Keychain）のみで保持し、RN / JS 境界には返さない。

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
- `notion` / `chatgpt`: 本契約で 1.0 対象。**実装済み**（`MemoraNative.exportToDestination`）。

### 3.2 `ExportPayloadDTO`

```ts
export type ExportPayloadDTO = {
  title: string;
  text: string;            // summary + transcript を結合した Markdown テキスト
  createdAt?: string;      // ISO 8601
  sourceFileId: string;    // 共有 SwiftData の AudioFile id
  destination: ExportDestination;
  // format / transcriptOnly / summaryOnly 等の拡張は今回入れない（契約で確定）
};
```

- `text` は `## 要約` / `## 文字起こし` の見出し区切りで構成される。
  組み立ては TS 純関数 `buildExportMarkdown`（`src/native/exportLogic.ts`）が行い、
  native 側（`MemoraRNExportHandlers.makeBlocks`）と区切りを共有する。

### 3.3 bridge 関数

```ts
export async function exportToDestination(payload: ExportPayloadDTO): Promise<ExportResultDTO>;
```

```ts
export type ExportResultDTO = {
  ok: boolean;
  destination: ExportDestination;
  refId?: string;      // Notion page id 等
  error?: string;      // 人間可読のエラー理由
};
```

- 実装時の命名は既存 bridge（`MemoraNative`）の命名規則に合わせて確定（`exportToDestination`）。
- native が未接続の場合は**フォールバックで偽成功せず**、明示エラーを返す。
- **認証情報・API キーは RN 側に置かず、native（Keychain）側のみで扱う**（CLAUDE.md の Keychain 方針・ADR-004 に準拠）。

## 4. 認証方式（1.0 確定）

| Destination | 方式（1.0 確定） | 実装 |
|---|---|---|
| Notion | **Integration token（`ntn_...`）**（OAuth / WebView は 1.0 対象外） | Keychain に保存。`POST https://api.notion.com/v1/pages`（`Authorization: Bearer <token>` / `Notion-Version: 2022-06-28`）で親ページの子ページを作成 |
| ChatGPT | **クリップボードへコピー＋共有シート（UIActivityViewController）**（公開書き込み API が無いため） | `UIPasteboard` へ Markdown をコピーし、システム共有シートを表示 |
| file | 現行 Share sheet のまま | 実装済み（変更なし） |

- トークン・親ページ未設定は明確なエラー（トークン未設定 / 親ページ未設定 / ページID識別不可）。
- 親ページ設定は認証情報ではなく設定のため settings store（UserDefaults `notionParentPage`）に保存する。
- Notion の children は 100 ブロック上限内に分割（`## 要約` / `## 文字起こし` の見出し＋本文ブロック）。

### 未確定事項の解決状況（2026-08-10 確定）

| 未確定事項 | 決定 |
|---|---|
| Notion: Integration token か OAuth か | **Integration token**（1.0 確定） |
| Notion: 書き出し先の選択 UI | Settings「連携」の親ページ入力（URL またはページID） |
| ChatGPT: 共有の具体的な導線 | **クリップボード＋共有シート**（1.0 確定） |
| API キー / トークンの保存先 | Keychain（`apiKey_notion`、RN ホスト内のみ） |
| エラー・リトライ・レート制限の扱い | 失敗は日本語エラーを返す。リトライ・履歴は 1.0 対象外 |
| 書き出し履歴（成功可否）をアプリ側に残すか | 1.0 では持たない（対象外） |

## 5. 設定 UI（実装済み）

- **Settings の「連携」グループ**（`SettingsScreen.tsx`）:
  - 「Notion に書き出す」行: 接続状態（設定済み / トークン未設定 / 親ページ未設定）を表示。
    タップでトークン入力（`presentSecureCredentialInput('Notion')`）と親ページ URL 入力の導線。
    設定済みなら更新 / 親ページ変更 / 解除。
  - 「ChatGPT に共有」行: 「コピー＋共有シート」の説明表示。認証不要。
- **FileDetail の書き出し行**（`FileDetailScreen.tsx`）:
  - 「Notion に転記」: 設定済みなら `exportToDestination` 実行→成功/失敗 Alert。未設定なら設定画面へ誘導。
  - 「ChatGPT に共有」: コピー＋共有シートを実行。
- 連携行の接続状態は settings store（UserDefaults）に持ち、トークン等は native のみで保持する。

## 6. 実装ステップ（完了 2026-08-10）

1. 契約確定の受け入れ（#185）。
2. bridge 契約の実装（Lane G）: `exportToDestination` + `ExportPayloadDTO` / `ExportResultDTO` を
   `MemoraNative` に追加し、型を確定。
3. Notion 連携（Lane G / F）: Integration token → native 実装（`MemoraRNExportHandlers`）→ Settings「連携」の有効化。
4. ChatGPT 連携（Lane G / F）: 共有導線（クリップボード＋共有シート）→ native 実装 → Settings「連携」の有効化。
5. FileDetail 書き出し行の接続（Lane F）: 「Notion に転記」「ChatGPT に共有」の実導線。
6. 実機 QA（Lane E）: **未実施**。実接続（実 Notion トークン・親ページ）での書き出し・エラー・再認証フローは
   実機 QA で確認する（残課題）。

### 実装 PR でやったこと（2026-08-10）

- bridge: `exportToDestination` / `ExportPayloadDTO` / `ExportResultDTO` / `SettingsDTO.notionParentPage`
  / `SecureCredentialProvider`（`Notion`）追加。
- Keychain: `MemoraSecureCredentialProvider.notion`（account `apiKey_notion`）追加。
- native: `MemoraRNExportHandlers`（Notion: URLSession で /v1/pages。ChatGPT: UIPasteboard + 共有シート）。
- UI: Settings「連携」・FileDetail「書き出す」の実導線。
- テスト: TS 純関数（payload 組み立て・ページID抽出）+ native（DTO / 状態分岐）をモックで追加。
  native の実 API 呼び出しテストは行わない。
