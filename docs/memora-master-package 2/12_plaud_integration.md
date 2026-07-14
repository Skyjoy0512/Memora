# 12. PLAUD 連携 設計(正規ルートのみ)

対象: iOS アプリ本体 / 依存: 10
出典: dev.plaud.ai/terms(利用規約)、docs.plaud.ai/plaud-embedded(公式SDK)、`Plaud-AI/plaud-sdk-public`

> ⚠️ **最重要**: PLAUD のデバイス BLE プロトコルは非公開。利用規約で **リバースエンジニアリングと競合 AI ノートアプリでの SDK 利用が明示的に禁止**されている。本ドキュメントは正規ルートのみを扱う。実装エージェントは PLAUD の BLE 解析・偽装接続を**絶対に実装してはならない**。

---

## 1. PLAUD 連携で取り得る3つの正規ルート

| ルート | 内容 | 実現性 | 規約リスク |
|---|---|---|---|
| **P-1. インポート方式(現行)** | ユーザーが PLAUD 公式アプリ/Web で録音・文字起こし → Memora に音声/transcript をインポート | ◎ すぐ可能 | なし(ユーザー自身のデータ) |
| **P-2. Plaud Embedded SDK** | 公式 B2B SDK でデバイス接続・録音・同期・文字起こし | △ 要ライセンス確認 | **競合アプリ制限に抵触の可能性** |
| **P-3. 手動ファイル取り込み** | PLAUD からエクスポートした音声ファイルを取り込み | ◎ 実装済 | なし |

### 判断
- **Phase 1 は P-1 / P-3 を磨く**(現行の「参照 transcript」方式)。規約リスクなし、すぐ価値が出る。
- **P-2 は事業判断が必要**。Memora が「AI ノートアプリ」として PLAUD の競合に当たる場合、SDK 利用規約(競合製品開発での利用禁止)に抵触し得る。**PLAUD とのライセンス交渉・法務確認が済むまで実装しない**。本ドキュメントでは技術構造のみ記載し、実装は保留とする。

## 2. P-1 / P-3: インポート方式(現行の強化)

### 2.1 現状(確認済み)
- `AudioFile.referenceTranscript` / `referenceSpeakerCount` が実装済み。「Plaud Toolkit 互換 API」(自前サーバー)経由で参照 transcript を取り込む構造。
- `TranscriptTab` に「参照文字起こし(Plaud)」カードとして表示済み。
- `referenceSpeakerCount` は FluidAudio の numSpeakers ヒントに利用済み。

### 2.2 強化案

**(a) 音声ファイル + transcript の同時インポート**
PLAUD からエクスポートした音声(m4a/wav)と transcript(txt/srt/json)をまとめて取り込むフロー。既存のファイルインポートを拡張:

```swift
// 取り込み時、音声と同名の transcript ファイルがあれば referenceTranscript として紐付け
struct PlaudImportBundle {
    let audioURL: URL
    let transcriptText: String?
    let speakerCount: Int?
}
```

**(b) インポート元の明示**
`AudioFile.sourceType` に `.plaudImport` を追加(■確認: 既存 sourceType の enum ケース)。UI バッジで「PLAUD から取り込み」を表示し、参照 transcript がある場合は Memora 側で再文字起こし不要である旨を示す。

**(c) 参照 transcript を「一級市民」に**
現状は補助表示だが、参照 transcript がある場合はそれを主 transcript として扱い、要約・検索・AskAI の対象にできるようにする(Memora の STT を回さず PLAUD の結果を活かす)。

```swift
// FileDetailViewModel: 主 transcript の解決順
var effectiveTranscriptText: String {
    if let ref = audioFile.referenceTranscript, !ref.isEmpty, useReferenceAsPrimary {
        return ref
    }
    return transcriptResult?.text ?? ""
}
```

### 2.3 AC(P-1/P-3)
1. PLAUD の音声+transcript をインポート → `AudioFile` 作成、参照 transcript 紐付け。
2. 参照 transcript を主として要約・AskAI・検索が動く(Memora STT を回さない選択肢)。
3. 「PLAUD から取り込み」バッジ表示。
4. 音声のみインポート時は通常どおり Memora STT が使える。

## 3. P-2: Plaud Embedded SDK(技術構造のみ・実装保留)

> このセクションは**ライセンス確認が済むまで実装しない**。構造理解のための記録。

### 3.1 SDK アーキテクチャ(公式ドキュメントより)
Plaud Embedded は4コンポーネント構成:
1. **認証**: 自社バックエンドが `client_id` / `client_secret` を PLAUD クラウドに渡しユーザートークンを取得。
2. **デバイス連携**: iOS/Android SDK(`.framework` / `.aar`、プロプライエタリ)がペアリング・録音制御を担う。デバイスは1アプリにのみバインド(オフライン暗号化のため)。
3. **ファイル同期**: BLE または Wi-Fi(高速転送)で録音をバックエンドへ。
4. **文字起こし**: `file_url` を PLAUD Transcription API に渡して結果取得。

### 3.2 API フロー(公式 template app より)
```
1. 音声アップロード: generate-presigned-urls → PUT parts → complete-upload
2. 文字起こし送信: POST /open/partner/ai/transcriptions/
3. ポーリング: GET /open/partner/ai/transcriptions/{id}
Base URL: https://platform-us.plaud.ai/developer/api
```

### 3.3 参照 template app 構造(`Plaud-AI/plaud-template-app`)
`DeviceManager`(scan/connect/OTA)、`SyncManager`(BLE+WiFi 転送)、`TranscriptionManager`(S3 upload + polling)、`PlaudAPIService`(HTTP)。Memora の `RecorderDevice` 抽象に `PlaudDevice` として写せる構造だが、**SDK バイナリはプロプライエタリライセンス**。

### 3.4 実装前チェックリスト(法務・事業)
- [ ] Memora が PLAUD SDK 規約の「競合 AI ノートアプリ」に該当するか法務確認
- [ ] PLAUD と B2B パートナー契約 / ライセンス取得
- [ ] `client_id`/`client_secret` の安全な管理(バックエンド必須、アプリに埋め込まない)
- [ ] デバイスの1アプリバインド制約がユーザー体験に与える影響の評価

## 4. まとめ

- **今やる**: P-1/P-3(インポート強化)。規約クリーン、実装容易、すぐ価値。
- **やらない(当面)**: P-2(公式 SDK)は事業・法務判断待ち。技術的には `RecorderDevice` に後から追加可能。
- **絶対にやらない**: PLAUD BLE のリバースエンジニアリング。
