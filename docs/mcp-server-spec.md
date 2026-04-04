# Memora MCP Server 設計仕様

## 概要

Memora を MCP（Model Context Protocol）サーバーとして動作させ、AI クライアント（Claude Desktop、ChatGPT 等）から会議データにアクセス可能にする設計。

**注意**: この文書は将来の実装に向けた設計仕様であり、現時点ではコード実装を含まない。

## アーキテクチャ

### Transport

| フェーズ | Transport | 対象クライアント |
|----------|-----------|----------------|
| Phase 1 | stdio | Claude Desktop |
| Phase 2 | HTTP+SSE | ブラウザ拡張、リモートアクセス |

### 実装言語の選択肢

| 言語 | メリット | デメリット |
|------|---------|-----------|
| Swift | SwiftData モデルへの直接アクセス | MCP エコシステムのサポートが少ない |
| TypeScript | MCP SDK 公式サポート、広範なエコシステム | SwiftData へのブリッジが必要 |

推奨: Phase 1 は Swift コマンドラインツールとして実装。SwiftData SQLite を直接読み取る。

## MCP Tools

### `search_meetings`

会議データの全文検索。

```json
{
  "name": "search_meetings",
  "description": "Search across meeting transcripts and summaries",
  "parameters": {
    "query": { "type": "string", "description": "Search query" },
    "limit": { "type": "integer", "default": 10 },
    "scope": { "type": "string", "enum": ["file", "project", "global"], "default": "global" }
  }
}
```

### `get_meeting`

会議データの全文取得。

```json
{
  "name": "get_meeting",
  "description": "Retrieve full meeting data (transcript + summary + metadata)",
  "parameters": {
    "meeting_id": { "type": "string", "format": "uuid" }
  }
}
```

### `list_recent_meetings`

最近の会議一覧。

```json
{
  "name": "list_recent_meetings",
  "description": "List recent meetings",
  "parameters": {
    "limit": { "type": "integer", "default": 20 },
    "project_id": { "type": "string", "format": "uuid" }
  }
}
```

### `get_action_items`

アクションアイテムの取得。

```json
{
  "name": "get_action_items",
  "description": "Retrieve action items across meetings",
  "parameters": {
    "status": { "type": "string", "enum": ["pending", "completed"] },
    "project_id": { "type": "string", "format": "uuid" }
  }
}
```

## MCP Resources

| URI Pattern | Description |
|-------------|-------------|
| `memora://meetings/{id}` | 会議の全文（文字起こし + 要約） |
| `memora://meetings/{id}/transcript` | 文字起こしのみ |
| `memora://meetings/{id}/summary` | 要約のみ |
| `memora://projects/{id}/meetings` | プロジェクト内の全会議 |

## MCP Prompts

| Prompt | Description |
|--------|-------------|
| `summarize_meeting` | 指定された会議の要約を生成 |
| `extract_action_items` | アクションアイテムを抽出・構造化 |

## 認証

| モード | 認証 |
|--------|------|
| ローカル（stdio） | 認証不要（同一デバイス上で実行） |
| リモート（HTTP+SSE） | トークンベース認証（将来実装） |

## データアクセス

- SwiftData の SQLite ストアを直接読み取り
- 書き込みは行わない（Read-only サーバー）
- `ExportService` のフォーマットロジックを再利用

## 実装の依存関係

- SwiftData モデル: `AudioFile`, `Transcript`, `TodoItem`
- フォーマットロジック: `ExportService` の Markdown/JSON 生成
- MCP SDK: swift-sdk または typescript-sdk（+ SQLite ブリッジ）

## マイルストーン

1. **M1**: Swift CLI ツールの雛形作成（stdio transport）
2. **M2**: `list_recent_meetings` / `get_meeting` の実装
3. **M3**: `search_meetings` の実装（SQLite FTS5）
4. **M4**: Resources の実装
5. **M5**: Claude Desktop 統合テスト
6. **M6**: HTTP+SSE transport（Phase 2）
