# ADR-003: RN完全移行（React Native / Expo版への full cutover）

- 状態: 採用
- 日付: 2026-08-09
- Supersedes: ADR-002「1.0リリース対象（SwiftUI）とRN移行のcutover gate」
- 関連: `docs/rn-full-cutover-execution-plan.md`（実行計画・正本）

> 注: ADR-002 は現時点では Git checkpoint `212329b8`（`wip/rn-full-cutover-checkpoint-20260809`）内にのみ存在する。
> 分割統合手順（実行計画 §9）で main に導入される予定。本 ADR は、その導入の前後を問わず
> ADR-002 が定めた「SwiftUI 1.0 を提出対象とする」方針を明示的に supersede する。

## 決定

Memora は **React Native / Expo 版（`apps/mobile-expo`、RN iOS ホスト `MemoraRN`）へ完全移行する**。

- 移行の成否は **parity（機能同等性）と release gate** で観測可能に判定する。
- parity と release gate 通過後、**SwiftUI UI（`Memora/Views/**`）と旧 `Memora` app target を削除する**。
- 削除は本 ADR の SwiftUI 削除 gate（後述 f）を全て満たした時点で、別 PR として実行する。

次の **native core は、RN ホストが依存する native core として保持**し、別判断（新しい ADR）なしに削除しない:

| native core | 内容 |
|---|---|
| Swift の STT | SpeechAnalyzer / SFSpeechRecognizer / TranscriptionEngine 系（§8 保護対象含む） |
| Swift の録音 | AVFoundation による録音・音声インポート |
| SwiftData 共有パッケージ | `Packages/MemoraSharedData`（スキーマ・ストア契約・移行ロジック） |
| Keychain | API キー・資格情報の安全な保持 |
| Broadcast Extension | `MemoraBroadcastExtension/**` |
| Widget | `MemoraWidget/**` |

## 本 ADR が supersede する方針

ADR-002 は「Memora 1.0 の App Store 提出対象は既存 SwiftUI アプリ（`Memora` target）とし、
RN 版は cutover gate を全て満たすまで提出対象にしない」と決定した。
本 ADR はその **1.0 提出対象に関する方針** を明示的に supersede する。

- 今後 UI の正本は RN 版（`apps/mobile-expo`）とする。
- SwiftUI UI と旧 `Memora` app target は、削除 gate（f）に達するまで「削除対象として管理される延命状態」に置く。
  新規 UI 実装は原則 RN に置き、SwiftUI 側へ機能追加しない。
- ADR-002 の cutover gate a〜f（parity / production data / release 到達不能化 / privacy / QA / 明示決定）は、
  本 ADR の gate 定義に引き継ぎ・再定義する。gate の内容は無効化せず、RN 提出の実体条件として維持する。

## 理由

- **ユーザー決定（2026-08-09）**: RN/Expo 版へ完全移行し、parity と release gate 通過後に
  SwiftUI UI と旧 Memora app target を削除する方針が確定した。
- **RN 版の実用度が上がった**: SpeechAnalyzer が RN ホスト上で動作（#152）、共有 SwiftData 契約
  （`Packages/MemoraSharedData`）と RN ホストのアダプタ群（reader / mutator / summary / knowledge /
  transcription / keychain）が存在し、主要機能の bridge 経路が実装済み。
- **二重 UI の維持コスト**: 2 つの UI（SwiftUI / RN）の parity 維持、STT 経路の二重配線、
  SwiftUI 1.0 と RN 両方の審査準備を同時に続けるのは非効率。UI を RN に一本化する。
- **native core は移行後も必須**: STT / 録音 / SwiftData / Keychain / Broadcast Extension / Widget は
  RN ホストから参照され続けるため削除しない。これらの削除は「RN が実装を代替した」ことを個別に
  証明した上で、別の ADR 判断が必要。

## Cutover gate（観測可能な条件）

RN 版を提出対象とするには、以下を全て満たし、その証拠を記録する。主観的な「できた」ではなく、
実機・CI・テスト結果で観測できる形で判定する。詳細は `docs/rn-full-cutover-execution-plan.md`。

- a. **core parity**: 録音（record）/ インポート（import）/ 再生（playback）/ STT / 要約（summary）/
  検索（search）/ 書き出し（export）が RN 版で SwiftUI 相当に動作する（parity matrix で管理）。
- b. **production data**: SwiftData 共有ストアの移行とロールバックが実データ・実機で検証済み。
  既存ユーザーのデータを壊さないこと。
- c. **release 到達不能化**: release ビルドで mock fallback、fake auth/paywall、developer UI が
  到達不能であること（SwiftUI 1.0 で実施した B1/B2 相当の対応が RN 版でも完了していること）。
- d. **privacy / security / readiness**: Privacy Manifest、Keychain、バックグラウンド録音申告、
  `ITSAppUsesNonExemptEncryption`、App Privacy などが RN バンドルに対して満たされていること。
- e. **QA / CI**: typecheck / web export / RN iOS ビルド（`qa:ios:build`）/ RN ホストテスト
  （`qa:ios:test`）/ 共有パッケージテスト（`swift test --package-path Packages/MemoraSharedData`）/
  実機 QA が全て pass していること。

## SwiftUI 削除 gate（f）

本 ADR の帰結として SwiftUI UI と旧 `Memora` app target を削除できるのは、以下の**全て**を満たした時:

- f1. 上記 gate a〜e を全て満たし、その証拠が実行計画のリリース判定に記録済み。
- f2. RN 単独の release 候補ビルド（`xcodebuild archive -scheme MemoraRN`）と実機 QA が成立。
- f3. 旧 target 削除後も `xcodegen generate` からの再ビルド・テスト・CI が green。
- f4. ロールバック手順が決定済み（削除 PR の revert / 旧ブランチ復元 / データの共有ストア一元化の確認）。
- f5. 削除スコープが明示されている（削除対象・保持対象の一覧。Broadcast Extension / Widget / native core は保持）。

## 帰結

- `apps/mobile-expo`（RN）が UI の正本。SwiftUI UI と旧 target は削除 gate（f）まで「延命・凍結」する。
- native core（STT / 録音 / SwiftData 共有パッケージ / Keychain / Broadcast Extension / Widget）は
  RN ホストの依存先として維持する。削除は別 ADR が必要。
- `docs/app-store-review-readiness.md` は **SwiftUI 1.0 提出試行の historical checklist** とし、
  RN の release readiness は `docs/rn-full-cutover-execution-plan.md` が正本。
- `docs/react-native-expo-migration-plan.md` は RN 移行の作業ログとして継続し、方針の正本は本 ADR
  と実行計画に置く。
- 実行順序・並列 lane・checkpoint 分割・受け入れ条件・rollback は `docs/rn-full-cutover-execution-plan.md` に従う。

## 関連文書

- `docs/rn-full-cutover-execution-plan.md` — 実行計画（現在地・parity matrix・lane・checkpoint 分割・rollback）
- `docs/decisions/ADR-002-release-bundle-and-rn-cutover.md` — supersede する 1.0 提出方針（checkpoint 導入予定）
- `docs/react-native-expo-migration-plan.md` — RN 移行の作業ログ
- `docs/app-store-review-readiness.md` — SwiftUI 1.0 向け審査準備の historical checklist
- `CLAUDE.md` — 運用ルール（lane・検証マトリクス・STT 保護）
