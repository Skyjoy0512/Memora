# OpenCode フォローアップ指示（2026-08-16）— レビュー結果の反映

以下の `---` から下をそのまま OpenCode に渡してください。

---

# レビュー結果の反映依頼

先の作業（ブランチ `chore/opencode-20260816`）をレビューしました。
**全体として品質は良好**です。テストは 86/86 pass、判断保留の報告も適切でした。

そのうえで **2点の修正**と **1点の確認**をお願いします。
同じブランチ `chore/opencode-20260816` に積んでください。

## 前提（前回と同じ）

- リポジトリ: `/Volumes/DevSSD/Development/Projects/Memora`
- 変更してよいのは `apps/mobile-expo/src/**` と `apps/mobile-expo/app/**`
- **`npx expo prebuild` 禁止**、`git push` 禁止、PR 操作禁止
- `apps/mobile-expo/ios/Podfile.lock` は触らない・ステージしない
- 新規パッケージ追加禁止
- 判定基準: `docs/design/prohibitions.md`

---

## 修正1【要対応】シークバーは hitSlop の対象です

`apps/mobile-expo/src/components/PlayerBar.tsx` の `trackWrap`（高さ 12pt）を
「プログレスバー系なので対象外」と判断していましたが、**これは対象に含めてください。**

理由: この要素は表示専用ではなく、**`onPress={handleSeekPress}` を持つ操作要素**です
（タップで再生位置を変える）。前回の指示で「プログレスバー系は対象外」と書いたのは
**表示専用の進捗表示**を指すつもりでした。指示が曖昧でした。すみません。

```
apps/mobile-expo/src/components/PlayerBar.tsx:49
<Pressable ... onPress={handleSeekPress} style={styles.trackWrap}>
```

`trackWrap` は `height: 12`。**縦方向で 44pt に届くよう `hitSlop` を追加**してください。
`height` は変えないこと（レイアウトが動きます）。

横方向は親の幅いっぱいに広がっているため、縦だけで足ります。

---

## 修正2【要対応】再生速度ボタンの hitSlop が横方向で不足しています

同じファイルの `rateButton`（44行目付近）に付けた

```js
hitSlop={{ bottom: 10, left: 2, right: 2, top: 10 }}
```

について、**縦は足りていますが横が足りていません。**

`rateButton` には明示的な `height` / `width` がなく、
`paddingHorizontal: spacing.xs`(8) + `paddingVertical: spacing.xxs`(4) と
`captionBold`（fontSize 11 / lineHeight 16）から実寸は概ね:

- 縦: 4 + 16 + 4 = **24pt** → `top/bottom: 10` で 24 + 20 = **44pt** ✓
- 横: 「1x」等のテキスト幅（約 14pt）+ 8 + 8 = **約 30pt** → `left/right: 2` で **約 34pt** ✗

**`left` / `right` を、横方向も 44pt に届く値に増やしてください。**

注意: 隣接要素と干渉しないか確認してください。`hitSlop` は重なると
手前の要素が優先されるため、隣のボタンの操作性を落とさない範囲にすること。
干渉しそうなら、**その旨を報告して変更を控えて構いません。**

---

## 確認3【調査のみ・コード変更なし】他の hitSlop も 44pt に届いているか

今回の指摘は「値が小さすぎて 44pt に届いていない」ケースでした。
**前回追加した 7 箇所すべてについて、実効タップ領域が縦横とも 44pt 以上になるか
計算して報告**してください。

計算方法:

```
実効サイズ = 要素の実寸 + hitSlop（両側）
```

要素に明示的な `height` / `width` が無い場合は、
`padding` + テキストの `lineHeight` から見積もってください。

報告は表形式で:

| 箇所 | 実寸(縦×横) | hitSlop | 実効(縦×横) | 44pt 到達 |
|---|---|---|---|---|

**届いていないものが他にもあれば、修正1・2と同じ方針で直してください。**
判断に迷うものは変更せず報告してください。

---

## レビューで確認できた良い点（参考・対応不要）

- **タスクB の判断は正しかったです。** `isIconOnly` は 13 箇所で全てに
  `accessibilityLabel` が付いていました。前回の指示に書いた「4 箇所しか付いていない」
  という数字は**こちらの grep の誤り**でした（props がアルファベット順で
  `accessibilityLabel` が先に来るため、後方だけを見て数え漏らしていた）。
  指示を鵜呑みにせず実物を確認したのは適切です。

- **タスクD の抑制は正しいです。** `heroSummary` の置換は
  `fontSize:16 / lineHeight:24 / fontWeight:'400'` に対し
  `textStyles.callout` が `fontSize:16 / lineHeight:round(16×1.5)=24 /
  weight regular(400)` で**完全に等価**でした。見た目は変わりません。
  他の 8 箇所を丸めずに保留したのも正しい判断です。

---

## 検証（コミット前に必ず実行）

```bash
cd /Volumes/DevSSD/Development/Projects/Memora/apps/mobile-expo
npm test
npm run typecheck
npx expo export --platform web
```

```bash
cd /Volumes/DevSSD/Development/Projects/Memora
git diff --check
```

**iOS ビルド（`npm run qa:ios:build`）とシミュレータ操作は実行しないでください。**
実機確認は別の担当が行います。

---

## コミット

- 修正1・2 をまとめて 1 コミットで構いません
- `git push` は**しない**
- `index.lock` エラーで失敗する場合は再試行せず、差分を残したまま報告

---

## 報告

`docs/agent-workflows/opencode-handoff-2026-08-16-result.md` に追記してください。

- 修正1・2 で実際に設定した `hitSlop` の値と、その根拠（実寸の計算）
- 確認3 の表（7 箇所すべて）
- 隣接要素との干渉で変更を控えたものがあれば、その一覧と理由
- 検証結果とコミットハッシュ
