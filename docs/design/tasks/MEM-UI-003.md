# MEM-UI-003: 独自コンポーネント ProgressBar

## Objective

決定的進捗を表示する `ProgressBar` を実装する。

## Background

**HeroUI Native に `Progress` / `ProgressBar` は存在しない**（v1.0.3 で確認済み）。

一方 Memora には決定的進捗が必要な場面が複数ある。

- 文字起こしの進捗
- 音声認識モデルのダウンロード（**初回は数分かかり、これが不可視だったため「フリーズと区別できない」問題が発生した**）
- 書き出し
- ストレージ使用量

`Slider` は入力用であり、進捗表示に流用してはならない。

## Source specifications

- `docs/design/components.md`（ProgressBar の節）
- `docs/design/design-tokens.md`（進捗表示の仕様）
- `docs/design/screens/processing.md`

## Files expected to change

- `apps/mobile-expo/src/components/ProgressBar.tsx`（新規）

## HeroUI Native components

- なし（独自実装）
- 補助として `Text`, `Description` を使ってよい

## Implementation constraints

- **`transform: scaleX` でアニメートする。** `width` を使わない（レイアウト再計算を招く）
- Reanimated を使う
- **Reduce Motion 有効時もバー自体は動かす。** 進捗は情報であり装飾ではない
- 高さ 4pt、角丸 pill
- 背景 `surface-tertiary`、前景 `state-processing`
- **色を直接指定しない。** トークンを使う

## Props

```ts
type ProgressBarProps = {
  value: number;          // 0-1
  label?: string;         // 「文字起こしを作っています」
  showPercentage?: boolean;
  variant?: 'default' | 'compact';  // compact はグローバルバー用
};
```

## Out of scope

- 非決定的な待機表示（`Spinner` を使う）
- 進捗を取得するロジック（呼び出し側の責務）

## Acceptance criteria

1. `value` に応じてバーが伸縮する
2. **`transform: scaleX` を使い、`width` をアニメートしていない**
3. `showPercentage` でパーセンテージを表示できる
4. `variant="compact"` でグローバルバー用の小さい表示になる
5. **Reduce Motion 有効時もバーが進捗を反映する**
6. 色がトークン経由で指定されている
7. 高さ 4pt、角丸 pill

## Accessibility criteria

- `accessibilityRole="progressbar"`
- `accessibilityValue={{ now, min: 0, max: 100 }}`
- `label` がある場合は `accessibilityLabel` に含める
- 進捗の細かい更新を VoiceOver が読み上げ続けないこと

## Visual QA checklist

- [ ] Light / Dark 両テーマで視認できる
- [ ] 0% と 100% で破綻しない
- [ ] compact variant がグローバルバーの高さに収まる

## iOS / Android 確認項目

- [ ] iOS: 60fps でアニメートする
- [ ] Android: 同上

## lint / typecheck / test 条件

```bash
npm run typecheck
npx expo export --platform web
npm run theme:check
git diff --check
```
