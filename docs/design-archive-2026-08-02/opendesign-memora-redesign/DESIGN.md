# DESIGN.md — Memora リデザイン デザインシステム

> **ステータス**: 設計フェーズ / Codex 実装用仕様
> **対象**: `apps/mobile-expo`（Expo SDK 57 / React Native 0.86）
> **更新日**: 2026-07-14

---

## 1. デザイン理念

### 1.1 プロダクトの芯

Memora は「音声・メモ・ファイルから知識を蓄積し、あとから振り返り・検索・AI との対話ができる個人向けアプリ」である。この本質から、デザインの芯を以下に定める。

> **静けさのなかで、必要な知識が自然と手に届く。**

- 情報を取り込むときは、操作を意識させない。
- 振り返るときは、必要なものだけが目の前にある。
- AI に聞くときは、会話の相手として自然に感じられる。

### 1.2 デザイン原則

| 原則 | 意味 | 判断基準 |
|------|------|----------|
| **静寂（Quiet）** | インターフェースは主張せず、コンテンツを引き立てる | 「この画面で目に入る最初のものはユーザーの記録か？」 |
| **明瞭（Clear）** | 情報の優先順位が一瞥でわかる | 「3秒でこの画面の一番大事な操作がわかるか？」 |
| **信頼（Trustworthy）** | 状態が常に正直に表示され、操作結果が予測できる | 「いま何が起きているか、ユーザーは迷わないか？」 |
| **持続（Sustainable）** | 毎日使っても疲れない、情報が積み重なっても破綻しない | 「100件の記録があっても同じ快適さか？」 |
| **日本語最適（Japanese-first）** | 日本語UIを前提に、文字の美しさと可読性を両立する | 「長文の議事録でもストレスなく読めるか？」 |

### 1.3 視覚姿勢

- **落ち着いた背景** — 白ではなく、わずかに温かみのあるページトーン。情報を読むためのキャンバスとして機能する。
- **明確な階層** — 太さ・サイズ・色の3軸で情報の優先順位を表現。すべてを Bold にしない。
- **余白を機能させる** — 黄金比スケールの余白で、情報の「かたまり」を自然に知覚させる。
- **一点だけのアクセント** — 操作の起点となる要素だけが色を持つ。それ以外はモノトーンに徹する。
- **動きは意味だけ** — 画面遷移・状態変化・操作フィードバックだけにアニメーションを使う。装飾のための動きはしない。

### 1.4 スタイルリファレンス

以下のアプリ・プロダクトを「雰囲気の参照先」として挙げる。これらを模倣するのではなく、Memora が目指すべき **質感・情報の扱い方・落ち着き** の方向性を共有するために参照する。

| リファレンス | 学ぶべき点 | Memora での適用 |
|-------------|-----------|----------------|
| **Apple Notes** | 余白の使い方、最小限のクローム、コンテンツが主役 | ファイル詳細のレイアウト、メモ編集画面 |
| **Linear** | キーボード操作の快適さ、ステータス遷移の明瞭さ、タイポグラフィの精緻さ | タスク画面、状態表示全般 |
| **Kindle** | 長文日本語の読みやすさ、フォントと行間の調整、フォーカスモード | 文字起こし表示、要約の読書ビュー |
| **Notion（2024年以降）** | 情報ブロックの階層化、サイドバーとメイン領域の関係 | プロジェクトビュー、設定画面の整理 |
| **Muji（無印良品）のプロダクト哲学** | 「これでいい」ではなく「これがいい」と思わせる引き算の美学 | 全画面の余白設計、装飾を削ぎ落とす判断基準 |

### 1.5 記憶に残る3つの視覚的特徴

多くの「落ち着いたUI」が埋もれる中、Memora を識別可能にする固有の要素を3つだけ定義する。

#### A. 「紙とインク」の質感

- **背景（canvas）**: `#FAFAF8` — 純白よりわずかに温かく、上質紙のような落ち着き
- **カード（surface）**: `#FFFFFF` + 極細ボーダー `#E2E3E5` — 紙の端の「かすかな線」として
- **テキスト（text）**: `#1A1C1E` — 純黒ではなく、インクの吸い込まれたようなわずかな青み
- **影は最小限**: カードの浮遊感より「ページ上の書き込み」の印象を優先。`shadow.card` は opacity 0.04、実質的に境界の補助としてのみ使う
- **禁止**: 過剰なエレベーション、多段シャドウ、カードの「浮き上がり」表現

#### B. 「余白のリズム」

画面を縦方向に3つの呼吸ゾーンに分ける：

```
上部（ヘッダー領域）:  密。ナビゲーションと検索をコンパクトに
中部（コンテンツ領域）: 疎。情報の「かたまり」の間に十分な呼吸
下部（アクション領域）: 密。再生バー・入力エリアを機能的に配置
```

具体的には：
- リストの行間（`paddingVertical: 14`）は均等に保つ
- セクションの変わり目には `spacing.lg`（21px）のギャップを入れる
- 画面下部は `safeAreaInsets.bottom` + 112px のパディングでタブバーとの重なりを防止

#### C. シグネチャーモーション: 「開く」

Memora 固有の記憶に残るアニメーションを1つだけ実装する。

**「カードがページになる」共有要素遷移**:
- ホームのファイルカードをタップ → カードが拡大してファイル詳細画面全体になる
- `react-native-reanimated` の `useSharedValue` + `useAnimatedStyle` で実装
- 実装優先度: P2（他画面の基本動作が安定した後に導入）

その他のアニメーションは、意味のあるフィードバックに限定：
- チェックボックス完了: 0.15秒で緑背景に変化 + チェックマークが小さくスプリング出現
- タブ切替: 0.2秒フェード（opacity crossfade）
- 削除確認: 0.2秒で背面が暗転 + カードが中央にスケール表示

---

## 2. カラートークン

### 2.1 考え方

既存の `colors.ts` は `#FF3030`（強い赤）をアクセントにしており、警告や危険と結びつきやすい。Memora の「静かに知識を蓄える」という性格には、**落ち着いた青緑系** が適切である。

知識・信頼・静けさを感じさせる色相（Hue 190–210）をベースに、以下の体系に再構築する。

### 2.2 ライトモードトークン

```ts
// src/design/tokens.ts の colors を以下に置換
export const colors = {
  // ── Canvas ──────────────────────────────────────────
  canvas:         '#FAFAF8',   // ページ背景：純白よりわずかに温かい
  surface:        '#FFFFFF',   // カード・シート・入力欄の背景
  surfaceAlt:     '#F3F3F2',   // 交互背景・選択中・ホバー
  surfaceElevated:'#FFFFFF',   // モーダル・ポップオーバー（影つき）

  // ── Text ────────────────────────────────────────────
  text:           '#1A1C1E',   // 本文・見出し（ほぼ黒、わずかに青み）
  textSecondary:  '#5F6368',   // 補足情報・メタデータ
  textTertiary:   '#9AA0A6',   // プレースホルダ・無効テキスト
  textInverse:    '#FFFFFF',   // 濃色背景上のテキスト

  // ── Border ──────────────────────────────────────────
  border:         '#E2E3E5',   // カード境界・入力枠
  borderLight:    '#EEEEEF',   // 薄い仕切り線
  separator:      '#F0F0F0',   // リスト区切り

  // ── Accent ──────────────────────────────────────────
  // メインアクセント：深い青緑。落ち着き・信頼・知性を表現
  accent:         '#1A7F6B',   // メインアクション・選択中・強調
  accentSoft:     '#E8F5F1',   // アクセントの薄い背景（選択ハイライトなど）
  accentMuted:    '#B8D8CF',   // アクセントの中間色（非アクティブ指標など）

  // ── Status ──────────────────────────────────────────
  success:        '#2E7D32',   // 完了・保存成功
  successSoft:    '#E8F5E9',   // 成功の薄い背景
  warning:        '#E65100',   // 注意・期限切れ
  warningSoft:    '#FFF3E0',   // 注意の薄い背景
  danger:         '#C62828',   // 削除・破壊的操作
  dangerSoft:     '#FFEBEE',   // 危険の薄い背景
  info:           '#1565C0',   // 情報・ヒント
  infoSoft:       '#E3F2FD',   // 情報の薄い背景

  // ── Recording ───────────────────────────────────────
  recording:      '#C62828',   // 録音中のインジケータ（視認性重視で赤を維持）
  recordingSoft:  '#FFEBEE',

  // ── Skeleton ────────────────────────────────────────
  skeleton:       '#E8E8E6',   // ローディングプレースホルダ
  skeletonShimmer:'#F0F0EE',   // シマーアニメーション用

  // ── Overlay ─────────────────────────────────────────
  overlay:        'rgba(0,0,0,0.40)',   // モーダル背面
  overlayLight:   'rgba(0,0,0,0.20)',   // 軽いオーバーレイ
} as const;
```

### 2.3 ダークモードトークン

```ts
export const darkColors = {
  canvas:         '#0F1114',
  surface:        '#1A1D21',
  surfaceAlt:     '#23262A',
  surfaceElevated:'#2A2D32',
  text:           '#E8EAED',
  textSecondary:  '#9AA0A6',
  textTertiary:   '#5F6368',
  textInverse:    '#1A1C1E',
  border:         '#3C4043',
  borderLight:    '#313437',
  separator:      '#2A2D32',
  accent:         '#3DD9B0',   // ダークモードでは明るい青緑に
  accentSoft:     '#1A332E',
  accentMuted:    '#2A5C52',
  success:        '#4CAF50',
  successSoft:    '#1B3320',
  warning:        '#FF9800',
  warningSoft:    '#332A1A',
  danger:         '#EF5350',
  dangerSoft:     '#331A1D',
  info:           '#42A5F5',
  infoSoft:       '#1A2533',
  recording:      '#EF5350',
  recordingSoft:  '#331A1D',
  skeleton:       '#23262A',
  skeletonShimmer:'#2A2D32',
  overlay:        'rgba(0,0,0,0.60)',
  overlayLight:   'rgba(0,0,0,0.35)',
} as const;
```

### 2.4 カラーユーティリティ

```ts
// カラースキームに応じてトークンを切り替えるフック
// src/design/useColors.ts
import { useColorScheme } from 'react-native';
import { colors, darkColors } from './tokens';

export function useColors() {
  const scheme = useColorScheme();
  return scheme === 'dark' ? darkColors : colors;
}
```

---

## 3. タイポグラフィ

### 3.1 フォントスタック

```ts
export const fonts = {
  // 和文＋欧文の混植に強い Noto Sans JP をベースに、
  // コード・数値には Menlo をモノスペースとして使う
  sans: {
    regular:  { fontFamily: 'NotoSansJP_400Regular',  fontWeight: '400' as const },
    medium:   { fontFamily: 'NotoSansJP_500Medium',   fontWeight: '500' as const },
    bold:     { fontFamily: 'NotoSansJP_700Bold',      fontWeight: '700' as const },
  },
  // 表示用・大きな見出しには M PLUS 1p（やや幾何学的で静かな印象）
  display: {
    regular:  { fontFamily: 'MPLUS1p_400Regular', fontWeight: '400' as const },
    medium:   { fontFamily: 'MPLUS1p_500Medium',  fontWeight: '500' as const },
    bold:     { fontFamily: 'MPLUS1p_700Bold',     fontWeight: '700' as const },
  },
  // 数値・コード・タイムスタンプ
  mono: {
    regular:  { fontFamily: 'Menlo', fontWeight: '400' as const },
    bold:     { fontFamily: 'Menlo', fontWeight: '700' as const },
  },
};
```

### 3.2 タイプスケール

```ts
// 黄金比ベース（既存を踏襲しつつ微調整）
export const typography = {
  // サイズ（pt）
  size: {
    caption:   11,   // 極小補足・バッジ
    footnote:  13,   // 脚注・メタ情報
    body:      15,   // 本文（日本語の可読性を考慮し 15pt に）
    callout:   17,   // やや強調・リストタイトル
    title3:    20,   // 小見出し
    title2:    24,   // 中見出し
    title1:    30,   // 画面タイトル
    headline:  36,   // 大きな数値・強調
  },
  // 行間係数（fontSize × ratio）
  lineHeight: (fontSize: number, ratio: number = 1.6) =>
    Math.round(fontSize * ratio),
  // 字間
  letterSpacing: {
    tight:  -0.4,   // 大きい見出し
    normal:  0,
    wide:    0.3,   // キャプション・バッジ
  },
} as const;
```

### 3.3 プリセットスタイル

```ts
export const textStyles = {
  screenTitle: {
    fontSize: typography.size.title1,       // 30
    lineHeight: typography.lineHeight(30, 1.3),
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.sans.bold,
  },
  sectionTitle: {
    fontSize: typography.size.title3,       // 20
    lineHeight: typography.lineHeight(20, 1.4),
    ...fonts.sans.bold,
  },
  body: {
    fontSize: typography.size.body,         // 15
    lineHeight: typography.lineHeight(15, 1.6),
    ...fonts.sans.regular,
  },
  bodyBold: {
    fontSize: typography.size.body,
    lineHeight: typography.lineHeight(15, 1.6),
    ...fonts.sans.bold,
  },
  caption: {
    fontSize: typography.size.caption,      // 11
    lineHeight: typography.lineHeight(11, 1.4),
    letterSpacing: typography.letterSpacing.wide,
    ...fonts.sans.regular,
  },
  monoBody: {
    fontSize: 13,
    lineHeight: typography.lineHeight(13, 1.5),
    ...fonts.mono.regular,
  },
  // 大きな表示用（例：録音タイマー、統計数値）
  display: {
    fontSize: typography.size.headline,     // 36
    lineHeight: typography.lineHeight(36, 1.15),
    letterSpacing: typography.letterSpacing.tight,
    ...fonts.display.bold,
  },
};
```

### 3.4 日本語UIでの注意

- 本文は **15pt** 以上を確保する（日本語漢字は小さいと潰れる）
- 行間は **1.5–1.7** を基本とし、漢字の密度が高い場合は広めにとる
- 見出しと本文でフォントファミリーを変え、階層を明確にする
- 長文（議事録・文字起こし）は `lineHeight: 1.7` 以上で読みやすさを優先

---

## 4. スペーシング

既存の黄金比スケールを維持しつつ、`xxs` を追加して細かい調整を可能にする。

```ts
export const spacing = {
  xxs:  3,    // 極小：アイコンとテキストの間
  xs:   5,    // 最小単位：同一要素内の隙間
  sm:   8,    // 小：関連する要素間
  md:   13,   // 中：サブセクション間
  lg:   21,   // 大：セクション間
  xl:   34,   // 特大：画面の主区切り
  xxl:  55,   // 最大：上下の安全領域
} as const;

// 画面水平パディング
export const screenPadding = {
  horizontal: spacing.lg,   // 21px
} as const;
```

---

## 5. 角丸

```ts
export const radius = {
  xs:    4,     // 極小：インラインコード・バッジ
  sm:    8,     // 小：ボタン・入力欄・チップ
  md:    13,    // 中：カード
  lg:    21,    // 大：モーダル・シート
  pill:  999,   // 完全なピル型
} as const;
```

---

## 6. シャドウ・エレベーション

背景との区別が必要な場合のみ、最小限のシャドウを使う。

```ts
export const shadow = {
  // 微妙な浮き上がり：カード
  card: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.04,
    shadowRadius: 4,
    elevation: 1,
  },
  // 明示的な浮き上がり：モーダル・ポップオーバー
  elevated: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.10,
    shadowRadius: 16,
    elevation: 4,
  },
  // フローティング要素：FAB・ツールチップ
  floating: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.14,
    shadowRadius: 24,
    elevation: 8,
  },
} as const;
```

---

## 7. アイコン

- システムアイコンは `@expo/vector-icons` の **Ionicons** を継続使用する
- 線（outline）を基本とし、選択中のみ塗り（filled）に切り替える
- サイズ体系：16 / 18 / 20 / 22 / 24（最小タップ領域 44px を常に確保）

```ts
export const iconSize = {
  sm:   16,   // 補足・バッジ内
  md:   20,   // 標準（リスト行・ボタン内）
  lg:   24,   // ナビゲーション・タブ
  xl:   28,   // 大きな指標（空状態など）
} as const;
```

---

## 8. モーション

### 8.1 原則

- デフォルトのアニメーション時間は **200ms**。速すぎず遅すぎず。
- イージングは **ease-out**（開始が速く終わりが遅い）を基本とする。
- 画面遷移には React Navigation の標準アニメーションを使う。
- `LayoutAnimation` はリストの並べ替え・表示切り替えのみに限定する。

### 8.2 プリセット

```ts
export const motion = {
  duration: {
    fast:    150,   // ボタンフィードバック・チェックボックス
    normal:  200,   // 標準的な状態変化
    slow:    350,   // 画面遷移・モーダル表示
  },
  // React Native Animated / Reanimated 用の設定
  spring: {
    // タップフィードバック用小気味よいスプリング
    tap: {
      damping: 15,
      stiffness: 300,
      mass: 0.5,
    },
  },
  // LayoutAnimation プリセット
  layout: {
    easeInEaseOut: LayoutAnimation.Presets.easeInEaseOut,
  },
} as const;
```

### 8.3 使用箇所

| 状況 | アニメーション | 時間 |
|------|---------------|------|
| タブ切り替え（File Detail） | フェードイン（opacity 0→1） | 200ms |
| リスト項目の追加・削除 | `LayoutAnimation.easeInEaseOut` | 300ms |
| モーダル表示 | 下からスライド + 背面フェード | 350ms |
| ボタン押下 | `scale(0.97)` + `opacity(0.8)` | 150ms |
| チェックボックス | 背景色 + チェックマーク出現 | 150ms |
| 録音波形 | 実データ駆動のリアルタイム更新 | - |
| 読み込み中 | スケルトンシマー + `Infinity` ループ | 1200ms/周 |

---

## 9. タップ領域・アクセシビリティ

- 最小タップ領域：**44×44px**（iOS HIG準拠）
- リスト行・ボタンは `minHeight: 48`（押しやすさを優先）
- `accessibilityLabel` / `accessibilityRole` / `accessibilityState` をすべてのインタラクティブ要素に付与
- 録音中など重要な状態は `accessibilityLiveRegion` または同等の手段で通知
- 文字の最小コントラスト比：**4.5:1**（本文）/ **3:1**（大見出し18pt以上）

---

## 10. 禁止事項（アンチパターン）

### 10.1 視覚

- ❌ グラデーション背景（ページ全体・カード・ボタン背景への過剰なグラデーション）
- ❌ 背景色 `#FAFAF8` 以外の warm beige / cream / peach 系ページ背景
- ❌ 3色以上のアクセントカラーが同時に見える状態
- ❌ カード全面へのグラスモーフィズム（`liquid-glass` はタブバーと録音オーバーレイのみ）
- ❌ 角丸 21px を超える汎用カード（フォーム・リスト行は 8–13px）

### 10.2 情報設計

- ❌ 1画面に3つ以上の主要操作（CTA）ボタン
- ❌ 空状態での「今すぐ始める」以外の説明的長文（2行まで）
- ❌ 「✨🚀🎯」などの絵文字を使った機能アイコン
- ❌ 偽の統計数値（「99.9%」「10×高速」など根拠のない数字）
- ❌ 「特徴1」「特徴2」のようなプレースホルダ文言

### 10.3 実装

- ❌ スクロールビューの入れ子
- ❌ `scrollIntoView` の使用（Open Design プレビューとの非互換）
- ❌ ネイティブブリッジをバイパスしたファイル操作
- ❌ STT / 録音コアファイルへの変更（`CLAUDE.md §10` 参照）
- ❌ コンポーネント名 `styles`（複数ファイルで衝突する）

---

## 11. コンポーネントビジュアル仕様

トークンだけでは実装者が最終的な見た目を想像できないため、主要コンポーネントのビジュアル仕様を定義する。

### 11.1 FileCard（ファイルカード）

```
┌─────────────────────────────────────────┐
│ padding: spacing.md (13px)               │
│ borderRadius: radius.md (13px)           │
│ backgroundColor: colors.surface          │
│ borderColor: colors.border (1px)         │
│ shadow: shadow.card                      │
│ flexDirection: 'row', gap: spacing.md    │
│ minHeight: 72                            │
│                                          │
│ [icon]  [title         ]  [status pill]  │
│  32×32  [meta           ]  [       ⋯  ]  │
│         [summary preview]                │
│          1行のみ, color: textSecondary  │
└─────────────────────────────────────────┘
```

- 左アイコン: 32×32px、背景 `surfaceAlt`、borderRadius `sm`
- タイトル: `textStyles.bodyBold`、1行、overflow hidden
- メタ情報: `textStyles.caption`、`color: textSecondary`
- 要約プレビュー: `fontSize: 13`、`color: textSecondary`、1行のみ（`numberOfLines: 1`）
- ステータスピル: 右寄せ、高さ 22px、borderRadius `pill`
- 「⋯」ボタン: 44×44px タップ領域、右端

### 11.2 SegmentedControl

```
┌──────────────────────────────────────────────┐
│ backgroundColor: colors.surfaceAlt            │
│ borderRadius: radius.sm (8px)                 │
│ padding: 3px                                  │
│ flexDirection: 'row'                          │
│                                               │
│ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│ │  すべて   │ │ お気に入り│ │ プロジェクト  │   │
│ │ selected │ │          │ │              │   │
│ └──────────┘ └──────────┘ └──────────────┘   │
│  bg: surface  bg: transp   bg: transp         │
│  shadow.card                                │
└──────────────────────────────────────────────┘
```

- 選択セグメント: `backgroundColor: surface`、`shadow.card`、borderRadius 6px
- 非選択セグメント: 背景透明、`color: textSecondary`
- ラベル: `fontSize: 13`、`fontWeight: '600'`、水平中央揃え
- 各セグメント: `paddingVertical: 6`、`paddingHorizontal: spacing.md`、minHeight: 32
- アニメーション: 選択インジケータのスライド移動（`LayoutAnimation.easeInEaseOut`）

### 11.3 TabBar（ファイル詳細）

```
┌─────────────────────────────────────────────┐
│ borderBottom: colors.border (1px)            │
│ flexDirection: 'row', justifyContent: 'center'│
│                                              │
│    概要     文字起こし      メモ     質問      │
│    ════                              　      │
│   active indicator (2px, colors.accent)      │
└─────────────────────────────────────────────┘
```

- タブ間: `gap: spacing.lg`（21px）
- アクティブタブ: `color: accent`、下部に 2px のインジケータバー
- 非アクティブタブ: `color: textTertiary`
- ラベル: `fontSize: 14`、`fontWeight: '600'`
- 各タブ: `paddingVertical: spacing.sm`、`paddingHorizontal: 0`
- コンテナ全体: `paddingHorizontal: 0`、中央寄せ

### 11.4 PlayerBar（再生バー）

```
┌─────────────────────────────────────────────┐
│ height: 56px                                 │
│ backgroundColor: colors.surface              │
│ borderTop: colors.border (1px)               │
│ shadow: shadow.card                          │
│ paddingHorizontal: spacing.md                │
│ flexDirection: 'row', alignItems: 'center'   │
│ gap: spacing.sm                              │
│                                              │
│ [▶] ────●──────── [32:00] [1×]              │
│ 44px  シークバー    時間    速度               │
│       flex:1       mono    44px              │
└─────────────────────────────────────────────┘
```

- 再生ボタン: 44×44px、Ionicons `play` / `pause`、`color: text`
- シークバー: `flex: 1`、Slider。アクティブトラック `colors.accent`、インアクティブトラック `colors.border`
- 時間表示: `fontFamily: 'Menlo'`、`fontSize: 12`、`color: textSecondary`
- 速度ボタン: 44×44px、`fontSize: 12`、`fontWeight: '600'`、`color: textSecondary`
- 速度サイクル: 1× → 1.5× → 2× → 0.75× → 1×

### 11.5 StatusPill（ステータスピル）

5つのバリアント。すべて高さ 22px、borderRadius `pill`、paddingHorizontal `spacing.sm`。

| バリアント | 背景色 | テキスト色 | ラベル | ドット |
|-----------|--------|-----------|--------|-------|
| `ready` | `surfaceAlt` | `textSecondary` | 準備完了 | — |
| `transcribing` | `accentSoft` | `accent` | 文字起こし中 | パルスアニメーション |
| `summarized` | `successSoft` | `success` | 要約済 | — |
| `failed` | `dangerSoft` | `danger` | 失敗 | — |
| `processing` | `infoSoft` | `info` | 処理中 | 回転インジケータ |

---

## 12. アセット戦略

### 12.1 アイコン

- **システムUI**: `@expo/vector-icons` の Ionicons（既存維持）
- **アプリアイコン**: 既存資産を維持（`assets/` 以下）
- **空状態イラスト**: 線画スタイルのシンプルなSVG。色は `colors.textTertiary` 単色。
  - 必要なイラスト: 「録音開始」（マイクとノート）、「検索結果なし」（虫眼鏡）、「タスクなし」（チェックリスト）

### 12.2 空状態ビジュアル

3つの定型パターンを用意：

1. **初回空状態（Call to Action 付き）**: 大きめのアイコン（48px）+ タイトル + 1行の説明 + プライマリボタン
2. **検索空状態**: 虫眼鏡アイコン + 「一致する記録はありません」+ 「別のキーワードで試してみてください」
3. **機能未実装**: アイコン + 「準備中」+ 代わりにできることの提案

### 12.3 ブランド要素

- **カラーブランド**: accent `#1A7F6B`。この色は Memora の唯一のブランド識別色。
- **タイポグラフィブランド**: M PLUS 1p Bold の画面タイトル。Noto Sans JP の本文。
- **プロダクト名**: 「Memora」表記を統一。ロゴタイプは既存資産を使用。

---

## 13. 実装トークンサマリー

`src/design/tokens.ts` を以下の構造に改変する：

```ts
// エクスポートされるもの
export { colors }          // ライトモード（デフォルト）
export { darkColors }      // ダークモード（useColorScheme で切り替え）
export { spacing }         // 黄金比スペーシング
export { radius }          // 角丸
export { typography }      // タイプスケール + ヘルパー
export { textStyles }      // プリセットテキストスタイル
export { shadow }          // シャドウプリセット
export { iconSize }        // アイコンサイズ
export { motion }          // モーションプリセット
export { screenPadding }   // 画面パディング
```

既存の `src/design/tokens.ts` はバックアップとして `src/design/tokens.v6.ts` にリネームする。

---

## 14. デザイン決定の根拠

### アクセントカラーを赤から青緑に変更する理由

1. **プロダクト性格との一致**: Memora は「静かに知識を蓄える」アプリであり、警告・危険を想起させる赤は不適切
2. **長時間利用への配慮**: 赤は興奮色であり、毎日使うアプリの主色として疲労を誘発する
3. **差別化**: AI アシスタント系アプリの多くが紫・青・緑を使う中、深い青緑（teal）は信頼性と落ち着きを両立する
4. **アクセシビリティ**: `#1A7F6B` は白背景に対して WCAG AA（4.5:1）を満たす

### フォントに M PLUS 1p を表示用に追加する理由

1. Noto Sans JP だけではすべての見出しと本文が同じファミリーになり、階層の手がかりが減る
2. M PLUS 1p のやや幾何学的なフォルムは、大きく表示したときに静かで現代的な印象を与える
3. 既に `package.json` に依存が存在する（`@expo-google-fonts/m-plus-1p`）

---

## 次に読むべきドキュメント

- `UX_AUDIT.md` — 現状の課題と改善方針
- `SCREEN_SPECS.md` — 画面ごとの詳細仕様
- `COMPONENT_MAP.md` — 再利用コンポーネント一覧
- `CODEX_IMPLEMENTATION_PROMPT.md` — 実装指示
