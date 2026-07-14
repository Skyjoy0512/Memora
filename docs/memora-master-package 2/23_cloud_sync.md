# 23. クラウド同期 設計

対象: iOS + macOS 間の同期 / 依存: 20
目的: PC で録音した会議も iPhone で見られ、逆も可。transcript・要約・プロジェクトも同期。

---

## 1. 方式選定

| 案 | 技術 | 同期範囲 | バックエンド | コスト | 評価 |
|---|---|---|---|---|---|
| **A. CloudKit + SwiftData**(推奨) | `ModelConfiguration(cloudKitDatabase:)` | SwiftData 全モデル | 不要(iCloud) | 無料枠大 | ◎ iOS/macOS ネイティブ、実装最小 |
| B. 自前バックエンド | 既存 bot-server 資産 + S3 等 | 自由 | 要構築・運用 | サーバー費 | △ 運用重い |
| C. iCloud Drive(ファイルのみ) | ファイル同期のみ | 音声ファイル | 不要 | 無料枠 | △ メタデータ同期に別途工夫 |

**A(CloudKit + SwiftData)を推奨**。iOS が SwiftData 主体なので、`ModelContainer` に CloudKit を有効化するだけで大半の同期が動く。音声ファイル本体(大容量)は CloudKit の `CKAsset` か、SwiftData の外部ストレージ属性で扱う。

## 2. CloudKit + SwiftData の構成

### 2.1 ModelContainer の CloudKit 有効化

```swift
// 既存の ModelContainer 生成箇所(MemoraApp / 共有 Core)
let config = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.memora.Memora")   // ■確認: コンテナID
)
let container = try ModelContainer(for: schema, configurations: config)
```

前提・制約(SwiftData + CloudKit):
- CloudKit 同期対象のモデルは **全プロパティが optional か既定値を持つ**必要がある(CloudKit の制約)。既存 `@Model` を確認し、非 optional・既定値なしのプロパティに既定値を付ける移行が要る。■確認せよ: 既存モデルの制約適合(特に `Transcript` の並列配列、`AudioFile` の必須プロパティ)。
- `@Attribute(.unique)` は CloudKit 同期と相性が悪い(サポートされない)場合がある。既存の unique 制約(先の設計 07 の checkpoint 等)を見直す。
- リレーションは inverse 必須。

### 2.2 音声ファイル本体の同期

SwiftData のプロパティに音声を直接載せない。方式:
- **A案**: `AudioFile` に音声の CloudKit 参照(`CKAsset` を別途管理)を持たせ、本体は CloudKit 経由で転送。
- **B案(簡単)**: 音声ファイルを **iCloud Drive のアプリコンテナ**に置き、`AudioFile` は相対パス+同期状態を持つ。SwiftData はメタデータのみ同期、音声は iCloud Drive が同期。

会議録音は大きい(1時間で数十MB〜)。**B案(iCloud Drive にファイル、SwiftData にメタデータ)を推奨**。ダウンロードは遅延取得(オンデマンド)。

```swift
// 音声は iCloud Drive のアプリコンテナへ
let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
    .appendingPathComponent("Documents/Recordings")
// AudioFile には相対パス + ubiquitous ダウンロード状態を保持
```

■確認せよ: 既存 `AudioFile` の音声保存先(現状 Documents 直下)。iCloud Drive コンテナへの移行と、既存ローカルファイルのマイグレーション。`NSMetadataQuery` でダウンロード状態を監視。

## 3. 同期対象と非対象

| 同期する | 同期しない |
|---|---|
| AudioFile メタデータ、Transcript、Summary、Project、ToDo、参照 transcript | 一時チャンク、STT 診断ログ、開発者設定、APIキー(Keychain は別途 iCloud Keychain 任意) |

APIキーは SwiftData に入れない(Keychain)。iCloud Keychain 同期はユーザー選択。

## 4. 競合解決

- SwiftData+CloudKit は**last-write-wins** が基本。会議録音は「片方のデバイスで作成 → もう片方で閲覧」が主なので競合は少ない。
- 同じファイルを両デバイスで同時編集(transcript 編集等)する稀なケースは last-write-wins で許容。厳密なマージは要件化しない。

## 5. macOS 側の扱い

- macOS アプリも同じ `ModelContainer`(CloudKit 有効)を使う → iOS と自動同期。
- macOS で録音 → `AudioFile` 作成 → iCloud Drive に音声保存 → メタデータが CloudKit 経由で iPhone に反映 → iPhone で音声をオンデマンドダウンロード。

## 6. オフラインとダウンロード制御

- メタデータは軽いので常に同期。音声本体は**オンデマンド**(タップ時にダウンロード)。
- 「モバイル通信時は音声を自動ダウンロードしない」設定(既存の類似設定があれば踏襲)。

## 7. プライバシー
- CloudKit private database はユーザーの iCloud に閉じる(Anthropic/開発者はアクセス不可)。プライバシー説明を明記。
- 会議録音は機微。E2E ではないが Apple の iCloud 暗号化(標準/高度なデータ保護)に従う。

## 8. AC

1. iPhone で作った録音・transcript・要約が Mac に出る(逆も)。
2. Mac で録音した会議が iPhone の一覧に出て、タップで音声ダウンロード・再生できる。
3. transcript 編集が両デバイスに反映される(last-write-wins)。
4. APIキーは同期されない(Keychain)。
5. オフラインでメタデータ閲覧、オンラインで音声取得。
6. CloudKit 制約(optional/既定値)に既存モデルが適合し、マイグレーションで既存データが保持される。

## 9. フェーズ
- D1: CloudKit 有効化 + モデルの制約適合(read-only 同期でまず疎通)
- D4: 音声ファイルの iCloud Drive 同期 + オンデマンドダウンロード + 双方向書き込み

## 10. 自前バックエンド案(参考・非推奨)

既存 bot-server 資産を使い、S3 音声 + REST/WS でメタデータ同期する案も可能だが、運用・認証・コストが重い。**Windows 対応が必須になり CloudKit が使えなくなった段階で初めて検討**する。その場合も同期抽象(`CloudSyncService` プロトコル)を挟んでおけば差し替え可能。
