# ADR-004: RN本番識別子・Keychain・共有ストア移行の方針

- 状態: 採用
- 日付: 2026-08-09
- 関連: `docs/rn-full-cutover-execution-plan.md`（実行計画・gate b の実装対象）、
  `docs/decisions/ADR-003-rn-full-cutover.md`（上位方針）

> 本 ADR は方針（design decision）を確定する文書である。ここで示す bundle ID・Keychain・
> 共有ストア移行の**実装は別 PR** で行う（docs 変更のみの本 PR ではコードを変更しない）。

## 背景: コード上の現状（2026-08-09 時点）

| 対象 | 現在値 | 場所 |
|---|---|---|
| SwiftUI 本番 target bundle ID | `com.memora.Memora`（bundleIdPrefix `com.memora`。Team ID 前置 `4R82H2PVGL.` は `fix/bundle-id-restore` で除去済み） | `project.yml` |
| RN iOS bundle ID | `com.anonymous.memora-rn` | `apps/mobile-expo/app.json` `ios.bundleIdentifier` |
| RN ホスト entitlements | `group.com.memora.shared` のみ（broadcast は未同梱） | `apps/mobile-expo/ios/MemoraRN/MemoraRN.entitlements` |
| RN Keychain service | `com.anonymous.memora-rn.ai-credentials` | `MemoraRNKeychainSecureCredentials.swift` |
| SwiftUI Keychain service | `com.memora.app`（account: `apiKey_openai` / `apiKey_gemini` / `apiKey_deepseek` ほか） | `Memora/Core/Services/KeychainService.swift` |
| SwiftUI 共有ストア解決 | `MemoraApp.persistentStoreURL()`: 共有ストア存在→それを使用／legacy 存在かつ共有ディレクトリ無し→ `migrateStoreAtomically` で移行 | `Memora/App/MemoraApp.swift` |
| RN 共有ストア経路 | `MemoraNativeBridgeBootstrap.configureSharedAudioStoreOrDefaults()`: app group 内に空ストアを新規生成。legacy ストアからの移行は未実行 | `apps/mobile-expo/ios/MemoraRN/MemoraNativeBridgeBootstrap.swift` |
| 共有ストア契約 | `primaryAppGroupIdentifier = "group.com.memora.shared"`、store path = `<container>/Memora/Memora.store`、`migrateStoreAtomically` / `copyStore` | `Packages/MemoraSharedData/Sources/MemoraSharedData/MemoraSharedData.swift` |
| `copyStore` の利用 | テストのみ。RN ホストには未配線 | `Packages/MemoraSharedData/Tests/**` |

## 決定

### 1. RN 本番 bundle ID を `com.memora.Memora` に統一する

RN 本番ビルドの bundle ID を現状の `com.anonymous.memora-rn` から **`com.memora.Memora`** に変更し、
SwiftUI 本番 target（旧 `Memora`）と同一にする。実装時に以下を変更する方針とする:

- `apps/mobile-expo/app.json` の `ios.bundleIdentifier`
- RN iOS ホスト `apps/mobile-expo/ios/MemoraRN.xcodeproj`（PRODUCT_BUNDLE_IDENTIFIER 相当）
- `apps/mobile-expo/ios/MemoraRN/MemoraRN.entitlements`
- 識別子に依存する関連 Swift（Keychain service の既定値・ストア・診断表示など）

統一の根拠:

- **App Store アップデート経路**: 同一アプリ ID として既存ユーザーのアップデートで移行できる。
  別 ID だと新規アプリとして扱われ、既存データ・レビュー・購入状態が引き継がれない。
- **同一データコンテナ**: サンドボックス内コンテナが同一になり、legacy store への到達と
  app group 共有ストアへの移行が単一の所有権モデルで成立する。
- **Keychain 連続性**: 資格情報は service/account で引かれ、bundle ID 自体は Keychain の
  アクセス制御（access group）に影響する。同一 ID にすることで既存資格情報を確実に継承できる。
- **APNs 維持**: push entitlement・Device Token の文脈が同一アプリとして維持される。

> 注: `fix/bundle-id-restore`（Team ID 前置の除去）は `com.memora.Memora` を正とする変更であり、
> 本 ADR はその方針と矛盾しない（同一 ID に RN を合わせる）。

### 2. Keychain: RN も service `com.memora.app` を使用し既存資格情報を引き継ぐ

RN ホストの Keychain service を `com.anonymous.memora-rn.ai-credentials` から **`com.memora.app`** に変更し、
SwiftUI 側（`KeychainService`）と同一の service で資格情報を読み書きする。
provider ごとの account 識別子と provider の対応（マッピング）は維持する。

- 既存ユーザーはサービス利用のたびに再設定する必要がなくなる。
- account 名は現行 SwiftUI 側の `apiKey_openai` / `apiKey_gemini` / `apiKey_deepseek` と整合させる
  （現行 RN の `openai-api-key` 等とは異なる点は実装 PR で mapping として扱い、既存資格情報を優先して読む）。
- 秘密情報は引き続き native 側のみで保持し、RN state / JS 層に出さない（ADR-003 gate d）。

### 3. 共有 SwiftData ストア: legacy store → app group 共有ストアへの単方向・原子・冪等な移行

共有 SwiftData ストアの所有権は次のとおりとする:

- **移行方向**: 「旧アプリサンドボックス内の legacy store（`Application Support/Memora/Memora.store`）
  → app group 共有ストア（`group.com.memora.shared` 配下の `Memora/Memora.store`）」への**単方向**移行。
- **原子性・冪等性**: `MemoraStoreMigration.migrateStoreAtomically`（staging へのコピー → 一括 move、
  `-shm` / `-wal` sidecar 対応）を利用し、既に共有ストアが存在する場合は再移行しない（冪等）。
- **RN が先に起動した場合**: 空の共有ストアを**生成しない**。legacy store が存在する限り、
  旧アプリと同一の移行ロジックを実行してから共有ストアを開く。
- **移行後も legacy store は削除しない**: ロールバック（gate b）用に保持する。
- **解決関数の集約**: ストア URL 解決・移行判定ロジックを `Packages/MemoraSharedData` に集約し、
  SwiftUI と RN の**両ホストが同一ロジック**を使うことを実装目標とする（実装は別 PR）。

### 4. App Groups: `group.com.memora.shared` を維持、`group.com.memora.broadcast` は保持

- `group.com.memora.shared`: 共有 SwiftData ストアの正本として維持する（両ホストの entitlements に含まれる）。
- `group.com.memora.broadcast`: Broadcast Extension（`MemoraBroadcastExtension`）用に保持する。
  **RN ホストにはまだ同梱されていない**（RN entitlements は `group.com.memora.shared` のみ）。
  Broadcast Extension の RN 同梱は実行計画の parity matrix（「Broadcast Extension」行）の残タスクとして扱う。

## 現状リスクと本 ADR による解消

| リスク | 内容 | 本 ADR での扱い |
|---|---|---|
| RN 先起動で空の共有ストアが生成される | 現行 `MemoraNativeBridgeBootstrap.configureSharedAudioStoreOrDefaults()` は app group 内に**空の共有ストアを直接生成**する。先に RN が起動すると、SwiftUI 側の解決ロジックは「共有ストアが存在する」と判断して legacy 移行をスキップし、既存データが共有ストアに移行されない | 決定 3 により「legacy store が存在する限り移行ロジックを実行」し、空共有ストア生成を禁止 |
| `copyStore` が RN に未配線 | `MemoraStoreMigration.copyStore` はテストでのみ使用され、RN ホストの移行経路に接続されていない | 決定 3 の解決関数（`MemoraSharedData` 集約）の実装 PR で配線 |
| bundle ID 不一致 | RN が `com.anonymous.memora-rn` のままではデータコンテナ・Keychain・App Store 更新経路が旧アプリと別物になる | 決定 1・2 で統一 |

## 帰結

- 実装は本 ADR の決定を満たす形で、以下の順に別 PR で進める（docs 変更のみの本 PR では変更しない）:
  1. bundle ID 統一（`com.memora.Memora`）+ Keychain service 統一（`com.memora.app`）
  2. 共有ストア解決関数の `MemoraSharedData` への集約と RN 配線
  3. 実機での移行・rollback 検証（gate b、実行計画 T3）
- SwiftUI 側の既存解決ロジック（`MemoraApp.persistentStoreURL()`）は、集約後の `MemoraSharedData`
  関数へ置き換える（挙動は変えない）。
- parity matrix の「共有 SwiftData store」行の残ギャップは、この ADR の実装で解消する。

## 関連文書

- `docs/rn-full-cutover-execution-plan.md` — 実行計画（gate b / T3 の受け入れ条件）
- `docs/decisions/ADR-003-rn-full-cutover.md` — 上位方針（native core 保持・gate 定義）
- `docs/react-native-expo-migration-plan.md` — RN 移行の作業ログ
- `docs/react-native-swiftdata-target-sharing-decision.md` — 共有ターゲット/ストア契約の経緯
