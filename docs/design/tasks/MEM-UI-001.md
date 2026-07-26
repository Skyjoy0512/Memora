# MEM-UI-001: HeroUI Native 導入状況の整備と検証

## Objective

HeroUI Native が設計どおりに動作する状態を確立し、以降のタスクの前提を固める。

## Background

`heroui-native@1.0.6` と `uniwind@1.10.0` は導入済みだが、次の問題が確認されている。

- 一部コンポーネントが HeroUI の slot を使わず、root だけラップした状態で実装されている
- `docs/design/heroui-component-map.md` に記載のとおり、廃止・改名すべきコンポーネントがある
- 開発用ルート（`preview` / `dev-fonts`）が本番ビルドに含まれている

本タスクでは**動作確認と整備のみ**を行い、画面の作り直しは後続タスクで扱う。

## Source specifications

- `docs/design/heroui-component-map.md`
- `docs/design/codex-execution-rules.md`

## Files expected to change

- `apps/mobile-expo/app/_layout.tsx`（Provider 構成の確認。必要なら修正）
- `apps/mobile-expo/global.css`（import 順の確認）
- `apps/mobile-expo/metro.config.js`（Uniwind 設定の確認）
- `apps/mobile-expo/app/preview.tsx` / `dev-fonts.tsx`（本番ビルドからの除外）

## HeroUI Native components

本タスクでは新規のコンポーネント実装は行わない。

## Implementation constraints

- **`expo prebuild` を実行しない**
- §8 の文字起こしコア保護ファイルを編集しない
- 画面の見た目を変更しない（整備のみ）
- 依存バージョンを変更しない（Expo SDK 57 の整合が取れているため）

## Tasks

1. 公式 Skill でコンポーネント一覧とテーマを取得し、**実在する 39 コンポーネント**を確認する
   ```bash
   node .agents/skills/heroui-native/scripts/list_components.mjs
   node .agents/skills/heroui-native/scripts/get_theme.mjs
   ```
2. `app/_layout.tsx` の Provider 構成を確認する
   - `GestureHandlerRootView` → `HeroUINativeProvider` → `BottomSheetModalProvider` の順であること
   - `import '../global.css'` が先頭にあること
   - フォント読み込みとスプラッシュ制御が壊れていないこと
3. `global.css` の import 順を確認する
   - `tailwindcss` → `uniwind` → `heroui-native/styles` → 生成テーマ
4. `metro.config.js` が Expo デフォルトを `withUniwindConfig` でラップしていることを確認する
5. **開発用ルートを本番ビルドから除外する**
   - `preview.tsx` / `dev-fonts.tsx` を `__DEV__` またはビルド構成で分岐させる
   - 設定画面の「開発者向け」セクションも同様
6. 現状のコンポーネントのうち、**root だけラップして slot を使っていないもの**を洗い出し、報告する（修正は後続タスク）

## Out of scope

- 画面の作り直し
- コンポーネントの改名・廃止
- デザイントークンの変更
- ナビゲーション構造の変更

## Acceptance criteria

1. 公式 Skill から取得したコンポーネント一覧が報告に含まれる
2. Provider 構成が設計どおりであることが確認されている
3. **開発用ルートが本番ビルドに含まれない**
4. slot を使っていないコンポーネントの一覧が報告されている
5. 既存の画面の見た目が変わっていない

## Accessibility criteria

本タスクでは変更なし。

## Visual QA checklist

- [ ] 既存画面の見た目が変わっていないこと（回帰確認）
- [ ] Light / Dark 両テーマで起動すること

## iOS / Android 確認項目

- [ ] iOS: アプリが起動し、全タブに遷移できる
- [ ] Android: 同上（可能な範囲で）

## lint / typecheck / test 条件

```bash
npm run typecheck
npx expo export --platform web
npm run theme:check
git diff --check
```

`npm run qa:ios:build` は依頼者側で実行する。
