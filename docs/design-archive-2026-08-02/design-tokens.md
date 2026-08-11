# Memora デザイントークン

作成日: 2026-07-26
基盤: HeroUI Native v1.0.3（OKLCH）
正本: `apps/mobile-expo/src/design/tokens.ts` → `heroui-theme.css` を生成

**本ドキュメントは仕様である。実装フェーズで Codex が反映する。設計フェーズではファイルを変更しない。**

## 命名規則

- セマンティック名を使う。`gray500` のような値ベースの名前を使わない
- 状態は `state-*` 接頭辞
- 画面固有の色を定義しない

## カラートークン

### HeroUI 標準（テーマから継承）

| トークン | Light | Dark | 用途 |
|---|---|---|---|
| `background` | 明るいオフホワイト | 深いグレー | 画面背景 |
| `foreground` | ほぼ黒 | ほぼ白 | 本文 |
| `muted` | 中間グレー | 中間グレー | メタ情報 |
| `surface` | 白 | 背景より明るい | 第1層 |
| `surface-secondary` | わずかに沈む | わずかに明るい | 第2層 |
| `surface-tertiary` | さらに沈む | さらに明るい | 第3層 |
| `border` | 極薄 | 極薄 | ヘアライン |
| `accent` | ブランド色 | 明度調整版 | 主要 CTA |
| `field-background` | 白 | 沈んだ面 | 入力欄 |
| `overlay` | 白 | 沈んだ面 | シート・ダイアログ |

**値は HeroUI テーマの OKLCH を基準に、Memora のブランド（低彩度）へ調整する。**

### Memora 状態トークン

| トークン | 彩度方針 | 用途 | 必須の併記テキスト |
|---|---|---|---|
| `state-recording` | **高め**（唯一の例外） | 録音中 | 「録音中」 |
| `state-processing` | 低 | 文字起こし・要約の処理中 | 「文字起こし中」等 |
| `state-success` | 低 | 完了 | 「完了」 |
| `state-warning` | 中 | 上限接近・オフライン | 具体的な内容 |
| `state-error` | 中 | 失敗 | 失敗理由 |
| `state-offline` | 低 | オフライン | 「オフライン」 |
| `state-idle` | 極低（muted 相当） | 未処理・待機 | 「順番待ち」 |

各状態には `-foreground` と `-soft`（背景用の淡色）を用意する。

### 話者色

```
speaker-1 .. speaker-6
```

- 低彩度で相互に識別可能
- 隣接する話者に類似色を割り当てない
- 色に加えて必ず話者名を表示する

## タイポグラフィトークン

| トークン | サイズ | 行間 | ウェイト | 用途 |
|---|---|---|---|---|
| `display` | 36 | 44 (1.22) | ExtraLight | 大きな数値 |
| `screenTitle` | 30 | 38 (1.27) | ExtraLight | 画面タイトル |
| `title2` | 24 | 33 (1.38) | Light | 大見出し |
| `sectionTitle` | 20 | 28 (1.40) | Light | セクション見出し |
| `callout` | 17 | 26 (1.53) | Regular | 強調本文 |
| `body` | 15 | 24 (1.60) | **Regular** | 本文 |
| `bodyEmphasis` | 15 | 24 (1.60) | **Medium** | 強調 |
| `transcript` | 16 | 27 (1.69) | Regular | **文字起こし本文専用** |
| `footnote` | 13 | 20 (1.54) | Regular | 補足 |
| `footnoteEmphasis` | 13 | 20 (1.54) | Medium | 補足の強調 |
| `caption` | 11 | 16 (1.45) | Regular | メタ情報 |
| `captionEmphasis` | 11 | 16 (1.45) | Medium | メタ情報の強調 |
| `mono` | 13 | 20 (1.54) | Regular | 時刻・経過時間（等幅） |

**`transcript` を新設する。** 文字起こしは最も長く読まれるテキストであり、本文より広い行間が必要。

**`mono` を経過時間に使う。** 等幅でないと数字が変わるたびに幅が動く。

### Dynamic Type

上記のサイズは基準値であり、システムの文字サイズ設定に応じてスケールする。レイアウトは相対値で組み、文字が拡大しても破綻しないこと。

## スペーシング

黄金比スケール。

| トークン | 値 |
|---|---|
| `xxs` | 3 |
| `xs` | 5 |
| `sm` | 8 |
| `md` | 13 |
| `lg` | 21 |
| `xl` | 34 |
| `xxl` | 55 |

画面の左右パディング: `lg`(21)

**80pt を超える余白を定義しない。**

## 角丸

| トークン | 値 | 用途 |
|---|---|---|
| `xs` | 4 | タグ・小要素 |
| `sm` | 8 | 入力欄 |
| `md` | 13 | カード内要素 |
| `lg` | 21 | カード・シート |
| `pill` | 999 | Chip・丸ボタン |

入れ子は同心円（内側 = 外側 − padding）。

## エレベーション

**影は使わない。** 以下を階層表現とする。

| レベル | 表現 |
|---|---|
| 0 | `background` |
| 1 | `surface` |
| 2 | `surface-secondary` + `border` ヘアライン |
| 3 | `surface-tertiary` + `border` ヘアライン |
| 浮遊 | Liquid Glass（iOS 26）。それ以外は `overlay` + ヘアライン |

`tokens.ts` の `shadow` は全て 0 / transparent を維持する。

## アイコンサイズ

| トークン | 値 |
|---|---|
| `sm` | 16 |
| `md` | 20 |
| `lg` | 24 |
| `xl` | 28 |

## タップ領域

| トークン | 値 |
|---|---|
| `minTouch` | 44 |
| `listRow` | 50 |
| `recordButton` | 64 |
| `minGap` | 8 |

## モーション

### Duration

| トークン | 値 | 用途 |
|---|---|---|
| `fast` | 150ms | 微細な状態変化 |
| `normal` | 200ms | 標準 |
| `slow` | 350ms | 大きな遷移 |
| `reduceMotion` | 120ms | Reduce Motion 時のクロスフェード |

### Spring

Apple の damping ratio / response から換算（`k = m(2π/r)²`, `c = 2ζ√(km)`, `m = 1`）。

| トークン | ζ | r | 用途 |
|---|---|---|---|
| `press` | 1.0 | 0.3 | 押下フィードバック |
| `entrance` | 1.0 | 0.4 | 出現 |
| `reorder` | 1.0 | 0.4 | 並び替え |
| `sheet` | 0.8 | 0.3 | シート・ドロワー |

### Easing

- 表示: `ease-out` 系
- **`ease-in` を使わない**（鈍く感じる）
- `linear` は連続的な進捗表示のみ

## 進捗表示（独自実装の仕様）

HeroUI に `Progress` が存在しないため独自実装する。

| 種類 | 用途 | 表現 |
|---|---|---|
| 決定的 | 文字起こし進捗、書き出し | バー + パーセンテージ + 残り時間の目安 |
| 非決定的 | モデル準備中など | `Spinner` + 「準備しています」 |

**決定的進捗が取れない処理を、決定的なバーで見せない。** 動かないバーはフリーズと誤認される（監査 H-2）。

進捗バーの仕様:
- 高さ 4pt、角丸 pill
- 背景 `surface-tertiary`、前景 `state-processing`
- `transform: scaleX` でアニメートする（width は使わない）
- Reduce Motion 時もバー自体は動かす（進捗は情報であり装飾ではない）
