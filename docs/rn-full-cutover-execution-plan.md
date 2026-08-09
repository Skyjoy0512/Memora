# RN Full Cutover 実行計画

- 状態: 採用（ADR-003 に基づく）
- 作成: 2026-08-09
- 正本の位置: 方針は `docs/decisions/ADR-003-rn-full-cutover.md`、本ファイルは実行の詳細。
  矛盾したら ADR-003 → 本ファイル → CLAUDE.md → `docs/react-native-expo-migration-plan.md` の順に優先する。

## 1. 目的

Memora を React Native / Expo 版（`apps/mobile-expo`、RN iOS ホスト `MemoraRN`）へ完全移行する。
parity と release gate の通過を観測可能な形で判定し、SwiftUI UI と旧 `Memora` app target を削除する。
Swift の STT・録音・SwiftData 共有パッケージ・Keychain・Broadcast Extension・Widget は
RN ホストが依存する **native core として保持**し、別判断なしに削除しない。

この文書は docs 変更のみの PR として確立し、以降は本計画の維持（進捗・gate 判定の更新）を正本とする。
コード・`project.yml`・`.xcodeproj`・`apps/mobile-expo` 実装は本 PR では変更しない。

## 2. 現在地（2026-08-09 / 2026-08-10 監査反映）

> **更新（2026-08-10）**: SwiftUI 削除（#181）・Tasks 実データ化（#180）後のリリース準備監査
> （`docs/rn-release-readiness-2026-08-10.md`）を実施。parity matrix の「実装済みになった残ギャップ」を
> 反映し、詳細なコード根拠と 1.0 推奨は監査文書に譲る。残タスクの正体は §2.3 と parity matrix の「残ギャップ」列。

### 2.1 RN / Expo 側

- `apps/mobile-expo`: Expo SDK 57 / React Native 0.86 / TypeScript / Expo Router。Git 管理下（main に track 済み）。
- UI は Home / File Detail / Ask AI / Settings / Tasks が揃い、V6 デザインとの忠実度調整が進む
  （semantic theme tokens #161、HeroUI provider 基盤 #162、ステータスピル移行 #163 が main に入っている）。
- RN iOS ホスト `apps/mobile-expo/ios/MemoraRN.xcodeproj`（Git 管理下。`expo prebuild --clean` 禁止）に以下が存在:
  - SpeechAnalyzer の RN ホスト実行（`MemoraRNTranscriptionBridge.swift`、#152）と診断強化（#160）
  - `MemoraNativeBridgeBootstrap` による registry 注入（reader / mutator / recording / settings / summary / knowledge / transcription）
  - Keychain（`MemoraRNKeychainSecureCredentials.swift`）、`PrivacyInfo.xcprivacy`、entitlements
  - 共有ストア・要約・検索・語彙のホスト側アダプタ（`MemoraSharedStore*`）
- ネイティブブリッジ `modules/memora-native`: 録音 / インポート / 再生 / メモ写真 / リネーム / 削除 /
  プロジェクト移動 / retry queue / summary / knowledge / settings の registry 契約が実装済み。
- 共有パッケージ `Packages/MemoraSharedData`: `MemoraSharedSchema` / `MemoraSharedCore` /
  `MemoraSharedSummary` / `MemoraSharedAskAI`。ストア契約・store path 契約・`MemoraStoreMigration` と
  テスト群（`swift test` 6 tests + cutover 安全テスト #166）あり。
  **共有 SwiftData ストアは有効化済み（2026-08-10 監査）**: `AppDelegate` → `configureSharedAudioStoreOrDefaults()` →
  `MemoraSharedStoreResolver`（legacy → app group `group.com.memora.shared` の単方向・原子・冪等移行）。
  実データ移行・rollback の実機検証（gate b）は未実施（詳細は `docs/rn-release-readiness-2026-08-10.md` §4）。

#### 2026-08-09 に main へ入った進行（#164〜#170）

| PR | 内容 |
|---|---|
| #164 | RN full cutover 実行計画（本計画・docs のみ PR）を確立 |
| #165 | RN 表示の regression テスト（formatStatus / formatRecordedAt + vitest）を追加 |
| #166 | 共有ストア cutover 安全テストを強化（`MemoraSharedDataTests`） |
| #167 | Git branch / worktree 棚卸しを docs に記録（安全な local branch 7 件削除） |
| #168 | checkpoint から parity slice を抽出（Home / File Detail / Ask AI / Settings / Tasks の V6 parity 強化） |
| #169 | root スコープの stray build artifacts を除去 |
| #170 | **リリースゲート導入**: preview / dev-fonts ルートと設定の開発者セクションを `__DEV__` 時のみ露出（gate c への前進。本番の auth / (tabs) / file/[id] は変更なし） |

### 2.2 SwiftUI 側

- **削除実行済み（2026-08-09）**: オーナー決定により、旧 `Memora` app target・SwiftUI UI（`Memora/**`）・
  `Memora.xcodeproj`・`project.yml`・CI の `ios-build` ジョブを削除した（ADR-003 追記参照）。
  削除 gate（f）の全条件（実機 QA・残 parity 等）は RN 側で後日対応。
- `docs/app-store-review-readiness.md` は SwiftUI 1.0 提出試行の historical checklist（本計画では RN の
  release readiness が正本）。

### 2.3 未統合の作業

- Git checkpoint `212329b8`（`wip/rn-full-cutover-checkpoint-20260809`）が単一 squash commit として
  未統合。RN UI / RN ネイティブ / SwiftUI 1.0 側 / STT 共有 / CI / docs の変更が混在（§9 で分割統合）。
  一部は #168（RN UI parity slice）・#169 / #170（artifacts 除去 / リリースゲート）として main へ統合済み。
- root `MemoraTests/`（旧 SwiftUI テスト 34 ファイル）は **2026-08-10 に削除済み**（RN ビルドに未参照の孤立残存のため）。
- 共有 SwiftData ストアの有効化（ADR-004 実装 #172/#173、**実装済み**）、RN UI への実 STT transcript 表示
  （**実装済み**）、retry queue の host worker 接続、export 先（Notion / ChatGPT）契約などは未着手の残り。
  2026-08-10 時点の残差の正体と状態は `docs/rn-release-readiness-2026-08-10.md` §4 を参照。

#### checkpoint docs残差の取捨判断（2026-08-09）

- **統合（本 PR）**: ADR-001（NativeTabs / FAB）、ADR-002（SwiftUI 1.0 + cutover gate。ADR-003 が supersede）を main へ導入。
- **判断保留（オーナー判断待ち）**: `docs/design-archive-2026-08-02/**`（大規模デザイン資産）、`docs/design/*`（MEMORA_DESIGN 等）、
  `docs/agent-operating-model.md`（+ CLAUDE.md / `agent_prompts.md` / `.github` ラベルの Sol / Luna / OpenCode / Claude 運用方針）、
  `docs/reviews/*`（2026-08-03-status-review、current-ui-ux-audit、final-design-review、implementation-questions 等）。
- **破棄確定**: checkpoint 側の後退版（release gate 除去・bundle ID `com.anonymous.memora-rn`・vitest 除去・StatusPill 後退・
  root stray `main` / `SpeechAnalyzerCheck.swift`）— main の #163〜#174 / #169 で置換・削除済み。

## 3. 完了定義（Definition of Done）

RN への完全移行が「完了」と言えるのは、以下の全てが観測された時:

1. ADR-003 の gate a〜e（parity / production data / release 到達不能化 / privacy / QA）を満たし、
   その証拠が本計画のリリース判定に記録されている。
2. RN 単独で release 候補ビルドと実機 QA が成立している。
3. SwiftUI 削除 gate（f）を満たし、SwiftUI UI（`Memora/Views/**`）と旧 `Memora` app target が削除された
   状態でビルド・テスト・CI が green。
4. native core（STT / 録音 / SwiftData 共有パッケージ / Keychain / Broadcast Extension / Widget）が
   RN ホストの依存として維持されている。

## 4. Parity matrix

| 機能 | SwiftUI 1.0 | RN 現状 | 残ギャップ | 担当 lane | 受入条件（簡潔） |
|---|---|---|---|---|---|
| 録音 record | 実装 | native-file 録音（AVAudioRecorder handler）+ 録音→保存フロー実装。共有 SwiftData 永続化へ配線済み（2026-08-10 監査） | 実機 QA（マイク権限・バックグラウンド継続の主張有無） | G → H | 実録音 → 一覧反映 → 再起動後も残る |
| インポート import | 実装 | `expo-document-picker` + `importAudio`。共有 SwiftData 永続化へ配線済み | 実機 QA | G → H | 実ファイル取込 → 一覧反映 → 永続化 |
| 再生 playback | 実装 | AVAudioPlayer bridge + PlayerBar（実録音で検証済み） | なし | G | 実録音の再生・seek・rate |
| STT | 実装 | SpeechAnalyzer on RN host（#152 / #160）+ 共有 SwiftData `Transcript` へ persist + `onTranscriptionEvent`。RN transcript タブは実データ表示（2026-08-10 監査） | 実機 QA（音声認識権限・精度） | B / G → F | 実録音の文字起こしが RN transcript タブに表示 |
| 要約 summary | 実装 | `generateSummary` bridge + `MemoraSharedStoreSummaryGenerator` を host 接続済み（2026-08-10 監査）。API キーは Keychain | 実機 QA（API キー実接続） | C / G | 実ファイルの要約が RN File Detail に出る |
| 検索 search | 実装 | Ask AI UI + `queryKnowledge` bridge + `MemoraSharedStoreKnowledgeQuery`（host 接続済み、2026-08-10 監査） | retrieval 品質・モデル選択。1.0 必須/推奨の判定 | C / G | Ask で実検索結果が返る |
| 書き出し export | 実装 | Share sheet で title+summary+transcript を書き出し（実装済み） | Notion / ChatGPT 契約（未定・要ユーザー決定） | G / F | 実ファイルの書き出しが成立 |
| 設定 / Keychain | 実装 | UserDefaults settings store + RN 設定 UI、ホスト側 Keychain（service `com.memora.app`、ADR-004 実装済み）。連携行（Notion / ChatGPT / PLAUD / Omi 等）は未接続 Alert | 連携行のスコープ判断 | C / G | 設定永続化、API キーは native 側のみ |
| プロジェクト move | 実装 | `moveAudioFile` bridge + Home のプロジェクト表示（`file.project`） | UI wiring（FileDetail / Tasks シートは未接続 Alert） | G / F | プロジェクト移動が永続化 |
| タスク tasks | 実装 | **#180 で実データ化済み**: `TodoItem` SwiftData + `MemoraSharedStoreTaskBridgeAdapter` + TasksScreen CRUD | 日付選択・タスク化導線（FileDetail / AskAI）の配線 | C / F | タスクの実データ契約 |
| 認証 / ペイウォール | 1.0 で除去（B1/B2） | RN `/auth` mock route。リリースゲート #170 で dev ルート/設定の開発者セクションを `__DEV__` 時のみ露出 | 認証バックエンド・IAP 契約の決定（UI のみ実装） | F / D | release ビルドで到達不能 |
| 共有 SwiftData store | — | 契約・adapter・migration util・test 済み（#166）。**実装済み（#172/#173、2026-08-10 監査）**: bundle ID `com.memora.Memora` / Keychain service `com.memora.app` / legacy→共有ストア移行の RN 配線 | 実データ移行・rollback の実機検証（gate b） | H / C / G | 実データ移行・rollback 検証（gate b） |
| Broadcast Extension | 実装（旧 target 依存） | — | RN ビルドへの同梱・設定維持（`group.com.memora.broadcast` は ADR-004 で保持決定） | D / G | RN ビルドに extension が同梱 |
| Widget | 実装（旧 target 依存） | — | RN ビルドへの同梱・設定維持 | D / G | RN ビルドに widget が同梱 |
| Dynamic Island / 通知 | V6 UI 実装 | RN にピル表示実装（物理 Dynamic Island は Live Activity のため out of scope） | 通知（RN 設定画面は Switch のみ・未接続） | F | RN 録音フローの表示 |

## 5. 依存順とマイルストーン

```
M0 方針確立（ADR-003 + ADR-004 + 本計画）   ← ADR-003 PR 完了済み、ADR-004 は docs PR（本 PR）で確定
M1 checkpoint 分割統合（§9 S1→S9）    ← docs → code の順、依存順に merge
M2 ADR-004 実装（T3）                 ← bundle ID 統一 / Keychain 継承 / legacy→共有ストア移行 / rollback の実機検証
M3 parity 残差解消（T4）              ← STT transcript / export / tasks / search・summary adapter
M4 release gate 充足（T5）            ← gate c / d / e
M5 release 判定（T6）                 ← gate a〜e の evidence 記録
M6 SwiftUI 削除（T7）                 ← 削除 gate f（2026-08-09 実行済み・ADR-003 追記参照）
M7 安定化と rollback 確認（T8）
```

依存の原則:
- 新規 UI 実装は RN（Lane F）。SwiftUI 側へは機能追加しない（削除 gate までの凍結）。
- 共有スキーマ変更は同時に 1 本だけ（CLAUDE.md §3.2 Lane H）。
- native core（§8 STT 含む）を変える PR は、実行前に報告と承認が必要。

## 6. 並列 lane と所有 path

CLAUDE.md §3.2 の lane を踏襲し、cutover 固有の管掌を補足する。

| Lane | 対象 | cutover での責務 |
|---|---|---|
| A: SwiftUI UI | （旧）`Memora/Views/**` | **削除済み（2026-08-09）** |
| B: 音声 / STT | STT コア（§8 保護） | RN への STT 配線・parity 維持（§8 報告義務） |
| C: モデル / 状態 | 共有アダプタ（`MemoraSharedSummary` / `MemoraSharedAskAI`） | summary / knowledge / tasks 契約 |
| D: 基盤 / 統合 | `.github/**`（CI/ワークフロー）、RN ホスト構成 | CI・削除 gate の基盤 |
| E: QA / 運用 | テスト・CI 結果・リリースノート | gate 判定の evidence 収集 |
| F: RN UI | `apps/mobile-expo/src/**`, `app/**` | RN UI の parity 完成 |
| G: RN ネイティブ | `apps/mobile-expo/modules/**`, `apps/mobile-expo/ios/**` | bridge・ホスト adapter・Keychain・extension/widget 同梱 |
| H: 共有データ | `Packages/MemoraSharedData/Sources/MemoraSharedSchema/**`（スキーマ/ストア契約のみ） | 共有ストア有効化の基盤 |
| O: cutover 管掌 | `docs/decisions/ADR-003-rn-full-cutover.md`, `docs/rn-full-cutover-execution-plan.md` | 本計画の維持・gate 判定・checkpoint 統合順序の管理（docs セッション / Lane E と連携） |

## 7. タスク一覧（受け入れ条件と検証コマンド）

各タスクの検証は CLAUDE.md §3.3 の lane 別検証マトリクスに従う（触った範囲だけ）。
全 lane 共通で `git diff --check`。

### T1: 方針確立（本 PR）
- 内容: ADR-003 と本実行計画の作成、既存 docs / CLAUDE.md / README の最小更新。
- 受け入れ: ADR-003 が ADR-002 方針を supersede し、削除 gate と native core 保持が明記されている。
- 注: ADR-004（RN 識別子 / Keychain / 共有ストア移行）は 2026-08-09 の docs PR で追加確立。
- 検証: `git diff --check`。

### T2: checkpoint 212329b8 の分割統合（§9）
- 内容: 単一 squash commit を論理単位ごとに PR 化して main へ統合。
- 受け入れ: 各 PR が lane 別検証に pass。統合後 `git diff origin/main 212329b8` が空（意図的に破棄した分を除く）。
- 検証: 各 PR の lane 別コマンド（§3.3）+ 最終 diff 確認。

### T3: ADR-004 実装（bundle ID / Keychain / 共有ストア移行）(gate b)
- 内容: `docs/decisions/ADR-004-rn-identity-and-data-migration.md` の決定を実装する。
  1. RN 本番 bundle ID を `com.memora.Memora` に統一（`app.json` / `ios` / entitlements / 関連 Swift）。
  2. RN Keychain service を `com.memora.app` に統一し、既存資格情報を引き継ぐ（account/provider マッピング維持）。
  3. legacy store（アプリサンドボックス）→ app group 共有ストア（`group.com.memora.shared`）の単方向・原子・冪等な移行を
     `Packages/MemoraSharedData` に集約し、SwiftUI / RN の両ホストが同一ロジックで解決する。
     RN が先に起動しても空の共有ストアを生成せず、legacy store が存在する限り移行ロジックを実行。移行後も legacy store は保持（rollback 用）。
- 受け入れ: 実データ・実機で移行とロールバックを検証。既存ユーザーのデータが壊れない。
- 検証: `swift test --package-path Packages/MemoraSharedData` + `npm run qa:ios:build` + 実機 QA。

### T4: parity 残差の解消（gate a）
- 内容: RN UI への実 STT transcript 表示、export 契約、tasks データ契約、search / summary の host adapter 接続。
  （Keychain の既存資格情報継承は T3 で実施。）
- 受け入れ: parity matrix の「残ギャップ」が全て解消。
- 検証: lane 別検証（F: typecheck + web export、G: + qa:ios:build、C/H: + swift test）+ 実機 QA。

### T5: release hardening（gate c / d）
- 内容: mock fallback・fake auth/paywall・developer UI の release 到達不能化、Privacy Manifest・
  バックグラウンド録音申告・`ITSAppUsesNonExemptEncryption`・App Privacy の RN バンドルへの充足。
- 受け入れ: release ビルドで gate c / d の各条件を観測。
- 検証: `xcodebuild archive -project apps/mobile-expo/ios/MemoraRN.xcodeproj -scheme MemoraRN` 相当 + 実機確認。

### T6: release 判定（gate a〜e）
- 内容: Lane E が evidence を集め、gate a〜e の達成を本計画に記録。
- 受け入れ: 各 gate に検証コマンドと結果が記録されている。
- 検証: 記録されたコマンド一式を再実行し green を確認。

### T7: SwiftUI 削除（gate f）
- 内容: SwiftUI UI（`Memora/Views/**`）と旧 `Memora` app target の削除。Broadcast Extension / Widget / native core は保持。
- 状態: **実行済み（2026-08-09）**。オーナー決定により gate f の全条件の完了を待たずに削除した
  （ADR-003 追記参照）。
- 実績: `git rm` で `Memora/**`・`Memora.xcodeproj`・`project.yml` を削除し、CI の `ios-build` ジョブ
  （`-scheme Memora` + xcodegen install/generate）を除去。RN 単独構成で `qa:ios:build`・`swift test`・
  RN typecheck/export が green であることを確認。
- 受け入れ（当時）: 削除後も `xcodegen generate` → ビルド・テスト・CI が green（f3）。→ 削除後の現状は
  `xcodegen` 不要の RN 単独構成。
- 備考: 2 段階（参照除去 + target 除去）を 1 PR で行う。

### T8: 安定化と rollback 確認
- 内容: RN 単独構成でのリリース後、rollback 手順（§11）を一度は実施・記録。
- 受け入れ: rollback 手順が実演され、復旧までが記録されている。
- 検証: rollback ドリルの実行ログ。

## 8. 検証コマンド一覧

```bash
# RN UI（Lane F）
cd apps/mobile-expo
npm run typecheck
npx expo export --platform web

# RN ネイティブ（Lane G）
npm run qa:ios:build        # 分離 DerivedData での RN iOS ビルド
npm run qa:ios:test         # RN ホストテスト

# 共有データ / STT（Lane H / C / B）
swift test --package-path Packages/MemoraSharedData

# STT（Lane B）: 上記 + §8 の報告義務

# docs / CI のみ: git diff --check（CI が最終ゲート）
```

## 9. Git checkpoint 212329b8 の分割統合手順

### 9.1 前提

- `212329b8` は `wip/rn-full-cutover-checkpoint-20260809` 上の**単一 squash commit**。
  このブランチは origin/main の 2 コミット先（`98897cd8` docs(design) + `212329b8`）。
- `apps/mobile-expo` は main に track 済み（RN ホスト・native module・UI の現行版は main にある）。
- checkpoint の内容は「実装・検証済みの状態を保存」するのが目的であり、再実装しない。

### 9.2 論理単位（分割 PR 案）

| # | 単位 | 対象ファイル（checkpoint 差分） | lane | 備考 |
|---|---|---|---|---|
| S1 | ADR / 決定記録 | `docs/decisions/ADR-001-navigation-architecture.md`, `docs/decisions/ADR-002-release-bundle-and-rn-cutover.md` | docs | **統合済み**: ADR-001/ADR-002 は本 PR で main 導入済み（残りの checkpoint docs 残差の取捨は §2.3 参照） |
| S2 | 設計資料アーカイブ | `docs/design-archive-2026-08-02/**`, `docs/design/**`（再構成・新規） | docs | rename 検出に注意（`git diff -M`） |
| S3 | 運用・レビュー docs | `docs/agent-operating-model.md`, `docs/reviews/**`, `docs/app-store-review-readiness.md`（checkpoint 差分） | docs | ADR-003 の historical 化と整合させる |
| S4 | 運用ガイド | `CLAUDE.md`, `agent_prompts.md` | docs / D | hunk 分割が必要なら `git checkout -p` |
| S5 | STT / SpeechAnalyzer 共有 | `Packages/.../SpeechAnalyzer*.swift` 削除, `Memora/Core/Services/SpeechAnalyzerPreflight.swift`, `AIServiceLocalTranscription.swift`, `STTServiceDependencyLiveAdapters.swift`, `Memora/Core/Models/SharedSchemaAliases.swift` | B / H | **§8 保護対象の移動を含むため報告必須**。移動は同一 PR で（削除と追加を分けない） |
| S6 | RN ネイティブ | `apps/mobile-expo/ios/MemoraRN/**`, `ios/MemoraRNTests/**`, `ios/Podfile.lock`, `modules/memora-native/**` | G | S5 の後 |
| S7 | RN UI | `apps/mobile-expo/src/**`, `app/**`, `global.css`, `metro.config.js`, `package.json`/`package-lock.json`, `.node-version`, `apps/mobile-expo/README.md` | F | S6 の後（bridge 契約依存） |
| S8 | SwiftUI 1.0 側 | `Memora/Views/**`, `Memora.xcodeproj/project.pbxproj`, `project.yml` | A / D | 独立。pbxproj は Lane D のみ |
| S9 | CI / 基盤 | `.github/**`, `.gitignore`, `scripts/pm/**` | D | 独立 |

マージ順の推奨: **S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9**。
S8 / S9 は S1〜S7 と並列に進めてよい（CI が green なら merge queue の順で吸収）。

### 9.3 手順

1. `git fetch origin` し、`git worktree add ../Memora-<slug> -b <type>/<slug> origin/main` で分割 PR 用の worktree を切る。
2. 追加・変更ファイルは checkpoint から抽出:
   ```bash
   git restore --source=212329b8 --staged --worktree -- <対象パス...>
   git commit -m "<単位に見合うメッセージ>"
   ```
3. 削除（移動元）は `git rm <パス>` し、**移動元・移動先は必ず同一 PR に含める**（間がビルド不能になるのを防ぐ）。
4. 単一ファイル内に複数 lane の変更が混在するもの（`CLAUDE.md`, `project.yml` 等）は
   `git checkout -p 212329b8` で hunk 分割し、lane ごとの PR へ割り当てる。難しい場合はファイル全体を 1 PR に。
5. 各 PR で lane 別検証（§3.3）→ `git diff --check` → commit → push → PR 作成 → auto-merge 設定。
6. 依存順でマージする。マージ中に main が進んでも、分割 PR は main ベースなので rebase/merge main で解決。
7. 全 PR 統合後、次を確認:
   ```bash
   git diff origin/main 212329b8 --stat   # 空（または意図的に破棄した分のみ）
   ```
   破棄する分（例: ADR-002 の一部表現が ADR-003 で supersede 済み）は理由を記録する。
8. `wip/rn-full-cutover-checkpoint-20260809` を削除:
   ```bash
   git branch -d wip/rn-full-cutover-checkpoint-20260809
   git worktree prune
   ```

### 9.4 注意

- checkpoint は「検証済み状態の保存」なので、分割 PR の内容そのものは変えず、PR 説明で由来（checkpoint）と
  lane 別検証結果を記録する。
- 途中で実装内容を直す必要が出た場合も、分割 PR 内で完結させる（checkpoint を書き換えない）。
- S5 は STT コアの移動を含むため、`docs/transcription-core-boundary.md` と CLAUDE.md §8 に従い
  報告（影響範囲 / build・test・log）を PR に添える。

## 10. SwiftUI 削除 gate（f）の手順

> **更新（2026-08-09）**: 削除実行済み。オーナー決定により gate 条件の完了を待たずに削除した
> （ADR-003 追記参照）。以下は実行時の記録。

1. gate f1〜f5（ADR-003）の確認: T6（release 判定）の evidence は未揃いのため、オーナー決定で代替。
2. 削除スコープ:
   - 削除: `Memora/App/**`・`Memora/Views/**`・`Memora/Core/**`・`Memora/DesignSystem/**`・
     `Memora/Resources/**`・`Memora/Memora.entitlements`、`Memora.xcodeproj`、`project.yml`、
     CI の `ios-build` ジョブ。
   - 保持: native core（STT / 録音 / SwiftData 共有パッケージ / Keychain）、
     `MemoraBroadcastExtension/**`、`MemoraWidget/**`、`bot-server/**`。
3. 削除 PR（Lane D）で `git rm` を実施し、残存 CI（shared-data / expo-check / rn-ios-build /
   bot-server-build）が green であることを確認。
4. 削除後の最初のリリースを安定させる。
5. rollback 手順（§11）を一度実施・記録してから、RN 単独構成の運用を宣言する。

## 11. Rollback

| 段階 | ロールバック手段 | 備考 |
|---|---|---|
| M1（checkpoint 統合中） | 各分割 PR を個別に revert。wip ブランチは統合完了まで保持 | 既存 RN/SwiftUI は main に残るため安全 |
| M2〜M5（ADR-004 実装・parity 中） | 機能 PR を revert。ストア移行 PR は未移行のまま残る App Group 設定へ戻す | store 移行前に必ずバックアップ（`MemoraStoreMigration` 前提）。legacy store は移行後も保持（rollback 用） |
| M6（SwiftUI 削除） | 削除 PR を revert で旧 target 復元 | データは共有 SwiftData ストアに一元化済みなので UI 差し戻しのみ |
| M7（RN 単独運用中） | 前リリースタグへ revert / ブランチ復元 | データ移行済みユーザーには前バージョンの移行コードで読めることを確認 |

原則: **データは共有 SwiftData ストアに一元化**し、UI の差し戻しがデータを壊さないようにする。
データ移行（App Group 化）を有効化する PR は、必ずバックアップ → 移行 → rollback の実機検証（gate b）を通してからマージする。

## 12. 関連文書

- `docs/decisions/ADR-003-rn-full-cutover.md` — 方針（本計画の上位）
- `docs/decisions/ADR-004-rn-identity-and-data-migration.md` — RN 本番識別子・Keychain・共有ストア移行の方針（gate b / T3 の実装対象）
- `docs/decisions/ADR-001-navigation-architecture.md` — RN 側ナビゲーション（NativeTabs / FAB）の設計方針（checkpoint 統合）
- `docs/decisions/ADR-002-release-bundle-and-rn-cutover.md` — supersede した 1.0 方針（checkpoint 導入予定）
- `docs/rn-release-readiness-2026-08-10.md` — SwiftUI 削除後のリリース準備監査（2026-08-10。コード根拠付き parity 残差・1.0 推奨）
- `docs/react-native-expo-migration-plan.md` — RN 移行の作業ログ
- `docs/app-store-review-readiness.md` — SwiftUI 1.0 向け審査準備の historical checklist
- `CLAUDE.md` — 運用ルール（lane・検証マトリクス・STT 保護）
- `docs/transcription-core-boundary.md` — STT コアの保護ルール
