# Memora Bot Server

Memora アプリからの予約に基づき、オンライン会議（Zoom / Google Meet / Teams）に自動参加して録音する Bot サーバー。

## アーキテクチャ

```
iOS App (Memora)
  → POST /meetings (会議予約)
  → Bot Server がスケジュール実行
  → 会議に参加 → 録音 → S3 互換ストレージにアップロード
  → Webhook で iOS に完了通知
  → iOS App が音声をダウンロード → 文字起こし + 要約
```

## 環境変数

| 変数 | 必須 | 説明 |
|---|---|---|
| `PORT` | - | サーバーポート (default: 3000) |
| `API_KEY` | 必須 | API 認証キー。iOS アプリの BotMeetingConfig と同じ値を設定 |
| `S3_ENDPOINT` | - | S3 互換ストレージのエンドポイント |
| `S3_BUCKET` | - | バケット名 (default: memora-bot-recordings) |
| `S3_REGION` | - | リージョン (default: us-east-1) |
| `S3_ACCESS_KEY` | - | S3 アクセスキー |
| `S3_SECRET_KEY` | - | S3 シークレットキー |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Google Meet 用 | GCP サービスアカウント JSON |
| `ZOOM_CLIENT_ID` | Zoom 用 | Zoom Server-to-Server OAuth Client ID |
| `ZOOM_CLIENT_SECRET` | Zoom 用 | Zoom Server-to-Server OAuth Client Secret |
| `TEAMS_CLIENT_ID` | Teams 用 | Azure AD アプリ Client ID |
| `TEAMS_CLIENT_SECRET` | Teams 用 | Azure AD アプリ Client Secret |

## クイックスタート

### 開発環境

```bash
npm install
npx tsx src/index.ts
```

### Docker デプロイ（ワンコマンド起動）

```bash
# 1. 初回のみ: スクリプトを実行可能にする
chmod +x scripts/start.sh

# 2. 起動（.env がなければ .env.example から自動生成）
./scripts/start.sh
```

手動でセットアップする場合:

```bash
# 1. 環境変数ファイルを準備
cp .env.example .env
# .env を編集して API_KEY 等を設定

# 2. ビルド & 起動
npm run build
docker compose up -d --build
```

サーバーは http://localhost:3000 で起動します。

## 本番デプロイ

### 環境変数チェックリスト

本番環境にデプロイする前に、以下の環境変数がすべて正しく設定されていることを確認してください。

- [ ] `API_KEY` — 強固なランダム値に変更済み（`changeme` のままでは危険）
- [ ] `S3_ENDPOINT` — S3 互換ストレージのエンドポイントが正しい
- [ ] `S3_ACCESS_KEY` / `S3_SECRET_KEY` — 有効な認証情報
- [ ] `S3_BUCKET` — バケットが存在し、Bot サーバーからの書き込み権限がある
- [ ] `GOOGLE_SERVICE_ACCOUNT_JSON` — Google Meet を使用する場合のみ（JSON は 1 行にエスケープ）
- [ ] `ZOOM_CLIENT_ID` / `ZOOM_CLIENT_SECRET` — Zoom を使用する場合のみ
- [ ] `TEAMS_CLIENT_ID` / `TEAMS_CLIENT_SECRET` — Teams を使用する場合のみ
- [ ] ファイアウォールでポート `3000` が iOS アプリからアクセス可能（必要に応じてリバースプロキシを設定）

### リバースプロキシ設定例（nginx）

```nginx
server {
    listen 443 ssl;
    server_name bot.example.com;

    ssl_certificate     /etc/ssl/certs/bot.example.com.pem;
    ssl_certificate_key /etc/ssl/private/bot.example.com.key;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 永続化とバックアップ

- `./recordings` ディレクトリは Docker ボリュームとしてマウントされ、コンテナ削除後も保持されます
- 本番環境では、このディレクトリを定期的にバックアップしてください
- S3 アップロードが成功した録音ファイルは、一定期間後に削除する運用を推奨します

### ヘルスチェック監視

```bash
# Docker 組み込みのヘルスチェック（30 秒間隔）
docker inspect --format='{{json .State.Health}}' memora-bot-server | jq

# 外部からのヘルスチェック
curl http://localhost:3000/health
# → {"status":"ok","timestamp":"2026-05-01T10:00:00.000Z"}
```

## API エンドポイント

### `GET /health`
ヘルスチェック。認証不要。

レスポンス:
```json
{ "status": "ok", "timestamp": "2026-05-01T10:00:00.000Z" }
```

### `POST /meetings`
会議を予約する。

```json
{
  "meetingID": "uuid",
  "platform": "google_meet",
  "meetingURL": "https://meet.google.com/xxx-yyyy-zzz",
  "meetingTitle": "Weekly Sync",
  "scheduledTime": "2026-05-01T10:00:00Z",
  "durationMinutes": 60,
  "webhookURL": "https://ios-app.example.com/webhook"
}
```

### `GET /meetings/:jobID`
会議のステータスを取得。

### `DELETE /meetings/:jobID`
予約済み会議をキャンセル。

### `GET /meetings`
全予約済み会議の一覧を取得。

### `POST /webhooks/test`
Webhook の疎通確認用エンドポイント。指定した URL にテストペイロードを送信する。

```json
{
  "url": "https://ios-app.example.com/webhook",
  "payload": {
    "event": "test",
    "message": "Hello from Memora Bot Server"
  }
}
```

レスポンス:
```json
{
  "delivered": true,
  "url": "https://ios-app.example.com/webhook",
  "timestamp": "2026-05-01T10:00:00.000Z"
}
```

### Webhook 通知（Bot Server → iOS App）

Bot サーバーは会議予約時に `webhookURL` が指定されている場合、以下のイベントを POST します。

**`meeting.completed`**（会議完了時）:
```json
{
  "event": "meeting.completed",
  "meetingID": "uuid",
  "meetingTitle": "Weekly Sync",
  "platform": "google_meet",
  "audioURL": "https://s3.example.com/recordings/uuid.mp3",
  "timestamp": "2026-05-01T11:00:00.000Z"
}
```

**`meeting.failed`**（会議失敗時）:
```json
{
  "event": "meeting.failed",
  "meetingID": "uuid",
  "meetingTitle": "Weekly Sync",
  "platform": "google_meet",
  "error": "Failed to join meeting: room locked",
  "timestamp": "2026-05-01T11:00:00.000Z"
}
```

## 認証

すべてのエンドポイント（`/health` を除く）は `Authorization: Bearer <API_KEY>` ヘッダを要求します。

## プラットフォーム実装状況

| プラットフォーム | 実装方式 | 状態 |
|---|---|---|
| Google Meet | Google Meet REST API（録画・文字起こし事後取得） | Stub |
| Zoom | Zoom Meeting SDK / REST API（録画事後取得） | Stub |
| Microsoft Teams | Microsoft Graph API（文字起こし・録画事後取得） | Stub |

詳細は `src/platforms/` 以下の各ファイルのドキュメントを参照してください。

## 実装上の注意

- 各プラットフォームのリアルタイム Bot 参加は API 単体では困難です
- 現在の推奨方針: 事後に録画・文字起こしデータを API で取得する方式
- リアルタイム参加が必要な場合は、ブラウザ自動化（Playwright/Puppeteer）での対応を検討してください

## トラブルシューティング

### コンテナが起動しない

```bash
# ログを確認
docker compose logs bot-server

# よくある原因:
# 1. ポート 3000 が使用中 → PORT 環境変数で変更
# 2. dist/ がビルドされていない → npm run build を実行してから再起動
# 3. package-lock.json がない → npm install を実行
```

### ヘルスチェックが失敗する

```bash
# ヘルスチェックの状態を確認
docker inspect --format='{{json .State.Health}}' memora-bot-server | python3 -m json.tool

# 手動でヘルスチェックを実行
docker exec memora-bot-server node -e "require('http').get('http://localhost:3000/health', (r) => {r.on('data', d => console.log(d.toString()))})"
```

### S3 アップロードに失敗する

- S3 エンドポイントが正しいか確認（カスタムエンドポイントの場合、プロトコル `https://` を含める）
- アクセスキーとシークレットキーに有効期限が切れていないか確認
- バケットが存在し、書き込み権限があるか確認
- バケットの CORS 設定が適切か確認（iOS アプリから直接ダウンロードする場合）

### API 認証エラー (401)

- `API_KEY` が `.env` と iOS アプリの `BotMeetingConfig` で一致しているか確認
- リクエストヘッダが `Authorization: Bearer <API_KEY>` の形式になっているか確認
- 特殊文字を含む API キーは `.env` 内でクォートで囲む（`API_KEY="key/with=special"`）

### Webhook が届かない

- `POST /webhooks/test` で iOS アプリの Webhook URL に直接テスト送信する
- iOS アプリがフォアグラウンドで動作しているか確認（バックグラウンドでは受け取れない場合あり）
- ファイアウォール / ネットワーク設定で Bot サーバーから iOS アプリへの通信が許可されているか確認

### 本番環境のログを確認する

```bash
# リアルタイムログ
docker compose logs -f bot-server

# 直近 100 行
docker compose logs --tail=100 bot-server

# ログファイル（json-file ドライバ）
docker inspect memora-bot-server | jq -r '.[0].LogPath'
```
