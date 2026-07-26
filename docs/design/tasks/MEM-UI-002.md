# MEM-UI-002: デザイントークンの更新

## Objective

`docs/design/design-tokens.md` の仕様に沿ってデザイントークンを更新し、HeroUI テーマへ反映する。

## Background

現状のトークンには次の不足がある。

- **`transcript` タイポグラフィが無い**（文字起こし専用。行間 1.69）
- **`mono` が経過時間用に定義されていない**（等幅でないと数字の幅が動く）
- **Memora 固有の状態色（`state-*`）が体系化されていない**
- **Dynamic Type に対応していない**（固定 px）
- 話者色が定義されていない

## Source specifications

- `docs/design/design-tokens.md`
- `docs/design/design-system.md`

## Files expected to change

- `apps/mobile-expo/src/design/tokens.ts`
- `apps/mobile-expo/src/design/heroui-theme.css`（**生成物。手で編集しない**）
- `apps/mobile-expo/scripts/generate-heroui-theme.cjs`（必要なら）

## HeroUI Native components

なし（トークンのみ）。

## Implementation constraints

- **`tokens.ts` が正本。** `heroui-theme.css` は生成物として扱い、手で編集しない
- 生成後は `npm run theme:check` が通ること
- **`shadow` は全て 0 / transparent を維持する**
- 黄金比の spacing スケール（3/5/8/13/21/34/55）を変えない
- HeroUI テーマは **OKLCH 形式**。HSL に変換しない

## Tasks

1. **タイポグラフィに `transcript` を追加する**
   - サイズ 16 / 行間 27（1.69）/ Regular
   - 文字起こし本文専用
2. **`mono` を経過時間用に定義する**
   - 等幅フォント。サイズ 13 / 行間 20
3. **`state-*` トークンを追加する**
   - `state-recording`（**唯一彩度を上げる**）
   - `state-processing` / `state-success` / `state-warning` / `state-error` / `state-offline` / `state-idle`
   - 各々に `-foreground` と `-soft` を用意する
4. **話者色を追加する**（`speaker-1` .. `speaker-6`）
   - 低彩度で相互に識別可能
   - 隣接話者に類似色を割り当てない配列順にする
5. **Dynamic Type に対応する**
   - 固定 px をやめ、システムの文字サイズ設定に追従する仕組みにする
   - 方法は任せるが、レイアウトが破綻しないことを優先する
6. テーマを再生成し、`theme:check` が通ることを確認する

## Out of scope

- 画面・コンポーネントの実装
- 色の実値の最終決定（低彩度・ブランド整合の範囲で提案してよいが、大きく変える場合は報告する）

## Acceptance criteria

1. `transcript` タイポグラフィが定義され、行間が 1.69 である
2. `mono` が等幅で定義されている
3. `state-*` が7種類、それぞれ `-foreground` と `-soft` を持つ
4. `speaker-1` .. `speaker-6` が定義されている
5. **Dynamic Type に追従する**
6. `shadow` が全て 0 / transparent である
7. `npm run theme:check` が通る
8. 既存画面がビルドエラーを起こさない

## Accessibility criteria

- 本文と背景のコントラスト比 4.5:1 以上
- 大きい文字は 3:1 以上
- Dynamic Type 最大でレイアウトが破綻しない

## Visual QA checklist

- [ ] Light / Dark 両テーマでコントラストが確保されている
- [ ] Dynamic Type を最大にして主要画面が読める
- [ ] 話者色が相互に識別できる

## iOS / Android 確認項目

- [ ] iOS: Dynamic Type の設定変更が反映される
- [ ] Android: フォントスケール設定が反映される

## lint / typecheck / test 条件

```bash
npm run typecheck
npm run theme:check
npx expo export --platform web
git diff --check
```
