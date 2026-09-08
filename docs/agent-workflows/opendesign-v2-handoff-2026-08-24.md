# Open Design v2 刷新 — 引き継ぎ（2026-08-24）

Claude が `chore/opencode-20260816` の作業ツリー上で進めた Open Design v2 への刷新の
現在地と、残作業の依頼内容をまとめる。`---` から下を Codex / OpenCode にそのまま渡せる。

デザイン正本（プロトタイプ）:
`/Users/ken/Library/Application Support/Open Design/namespaces/release-stable/data/projects/979b1d8f-8288-41f6-8b7a-eee44865422d/memora-ios-prototype-v2.html`
情報構造の正本: 同ディレクトリの `memora-feature-architecture.md`

---

# Memora リポジトリでの作業依頼（Open Design v2 刷新の続き）

## 0. 前提

- 作業対象は **Lane F（RN UI）**: `apps/mobile-expo/src/**`, `apps/mobile-expo/app/**`
- `Packages/**`, `apps/mobile-expo/modules/**`, `apps/mobile-expo/ios/**`, `bot-server/**` は触らない
- ルートの `CLAUDE.md` と `apps/mobile-expo/AGENTS.md` を先に読む
- 検証は Lane F の必須2点: `npm run typecheck` と `npx expo export --platform web`。
  加えて `npm test` と `git diff --check` も通す

## 1. 済んでいること（作業ツリー上・未コミット）

プロトタイプの以下の画面はRNへ反映済み。**同じ作りを踏襲すること**。

| プロトタイプ | RN の実体 |
|---|---|
| `records` | `src/screens/HomeScreen.tsx` + `src/components/FileCard.tsx`（`.record-row`） |
| `tasks` / `task-create` | `src/screens/TasksScreen.tsx` |
| `ask` / `ask-history` | `src/screens/AskAIScreen.tsx` |
| `settings` | `src/screens/SettingsScreen.tsx`（習慣グリッドは `src/utils/recordingHabit.ts`） |
| `detail` / `processing` / `processing-error` / `share` | `src/screens/FileDetailScreen.tsx` + `src/components/ProcessRail.tsx` |
| `onboarding-*` / `signin` / `paywall` | `src/screens/AuthFlowScreen.tsx` |
| `capture-menu` / `importing` | `src/components/CaptureSheet.tsx` / `src/features/capture/CaptureFlowProvider.tsx` |

### 共通部品（新規・これを使う。新しく作らない）

- `src/components/Buttons.tsx` — IconButton / PrimaryAction / SecondaryAction / SheetAction
- `src/components/ProcessRail.tsx` — 処理レール・alert・現在の段階
- `src/components/ToggleSwitch.tsx` — `.switch`（矩形トラック）
- `src/components/AskEntryBar.tsx` — 浮かぶ「Ask AIに質問」
- `src/design/tokens.ts` の `textStyles.rowTitle` / `textStyles.label`

### 禁止事項（このデザインシステムの決定事項）

- **heroui-native の `Button` は使わない**。hover 色を CSS の `color-mix(in oklab, …)` から
  取るが同梱 colorKit がそれを解釈できず、描画のたびに
  `[colorKit.RGB] ...` を console.error に出す。`src/components/Buttons.tsx` を使う
- 角丸を作らない（`radius.circle` は幅=高さの円のみ）
- 生の `fontSize` / HEX を書かない。`textStyles` と `colors` の意味論ロールを使う
- 状態を色だけで表さない（成功=緑は廃止。文言＋黒塗り/枠線バッジ）
- 一覧・タスクに Ask AI の入力欄を常設しない（入口だけ置く）

## 2. 残作業（優先度順）

### A. 仕様決定が要るもの（**先に人へ確認。勝手に作らない**）

1. **`import-review`（取り込み前の確認）**
   プロトタイプはプロジェクト・言語・処理内容を選ばせる。
   `MemoraNative.importAudio(uri)` は現状 uri しか受け取らない。
   → ブリッジ契約の追加が必要。契約が決まるまで UI を作らない
2. **`devices`（PLAUD / Omi 管理）**、**`sync-storage`（同期と保存容量）**
   実データ源がない。作ると見た目だけのモックになる
3. **質問履歴の永続化**
   現状は Ask AI 画面のセッション内のみ（UI にもそう明記してある）

### B. 仕様決定なしで進められるもの

4. **web の入力フォーカス枠**
   `TextInput` のフォーカス時にブラウザ既定のオレンジ枠が出る。
   デザイン上は ink 色の枠。web だけ `outlineColor` 等を当てる
5. **`global.css` のパレット整合**
   heroui 用の色（`#16171A` 系）が `src/theme/tokens.ts` の v0.7 ランプ（`#14181C` 系）と
   ずれている。トークン正本に合わせる
6. **heroui 依存の残りの判断**
   Dialog / Input / RadioGroup / Skeleton / Separator / Spinner が残っている。
   自前実装へ寄せるか依存として残すかを決めて統一する
7. **PR 分割**
   未コミットの差分が 28ファイル・約2,600行ある。CLAUDE.md の「1 PR = 1目的」に沿って
   `トークン・共通部品` → `記録/タスク` → `Ask AI/設定` → `詳細/認証` の順に分ける

## 3. 注意（環境）

- `pod install` を実行すると `ios/Podfile.lock` の checksum と `COCOAPODS:` 行が変わる。
  この Mac は CocoaPods 1.17.0、コミット済みの lock は 1.16.2。
  **CI と揃えるべきかは未確認**。iOS ビルドを通す目的以外で lock を書き換えない
- CocoaPods は UTF-8 ロケールを要求する。`LANG=en_US.UTF-8 pod install` で実行する
- web のタブバーは expo-router の実装上、画面上部に固定表示される。
  `global.css` の `[role='tablist'][aria-label='Main']` で下端へ移してある（web 限定の補正）
- web は全タブを `forceMount` する。タブ選択を検知したいときは `useFocusEffect` を使う
  （`useEffect` はマウント時に全タブぶん走る）
