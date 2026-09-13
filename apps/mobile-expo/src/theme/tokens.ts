// ============================================================
// Memora Design Tokens — デザインターゲット（Palantir原則適応版）
// 場所: apps/mobile-expo/src/theme/tokens.ts
// 更新: 2026-08-02
//
// このモジュールは単体で完結する型安全トークン（全て as const）で、
// React Native UI の意味論トークン正本として使用する。
//
// ## 既存トークンとの関係（マイグレーション経路）
// - 既存コードは `../design/tokens` / `../../design/tokens` を
//   import しているため、`src/design/tokens.ts` を互換アダプタとして
//   残し、本モジュールへ委譲する。
// - 新規コードは本モジュールを直接参照し、既存 import は段階的に
//   移行する。（設計背景は docs/design/MEMORA_DESIGN.md §13）
//
// ## HeroUI Native との将来マッピング
// - React Native に CSS 変数は存在しない。将来 HeroUI Native を
//   導入する際は、本ファイルの意味論トークンを HeroUI Native の
//   セマンティックロール（テーマキー）へ1:1でマップする。
//   独立した変数レイヤーは作らない。
// - 本ファイルは HeroUI Native に依存しない（インストール不要）。
//
// ## フォント方針
// - フォントパッケージに依存しない。fontFamily は指定せず
//   プラットフォーム System フォント（iOS: SF Pro / Android:
//   Roboto）を使用し、日本語はシステム CJK フォールバック
//   （Hiragino / Noto Sans CJK）に任せる。装飾用ディスプレイ
//   フォントは採用しない。
// ============================================================

import { StyleSheet } from 'react-native';

// ── Border / hairline ──────────────────────────────────────
// ヘアライン枠線は StyleSheet.hairlineWidth を使う（1物理画素）。
export const hairline = StyleSheet.hairlineWidth;

export const borderWidth = {
  hairline,
  standard: 1,
  strong: 2,
} as const;

// ── Grid / spacing（4pt 基底・名称付き倍数）──────────────────
// 画面左右マージンは compact=16pt / regular=20pt、内部リズムは
// 8pt。任意の一回限り値（11pt, 17pt など）は禁止。
export const grid = {
  unit: 4,
  rhythm: 8,
} as const;

export const space = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  xxxl: 40,
  huge: 48,
  massive: 64,
} as const;

export const screenMargin = {
  compact: 16,
  regular: 20,
} as const;

// ── Radii（v0.6: 全廃）──────────────────────────────────────
// 自分で描く矩形の角丸は 0。角丸長方形は作らない。
// 丸が許されるのは「幅 = 高さ」の円形要素だけ（点・円形コントロール）で、
// その場合は radius.circle を使う。xs/sm/md/lg/pill は互換のため残すが
// すべて 0 に解決するので、新規コードでは radius.none を使う。
// 元に戻す場合はこのブロックだけを差し替える。
export const radius = {
  none: 0,
  xs: 0,
  sm: 0,
  md: 0,
  lg: 0,
  /** @deprecated 角丸長方形は廃止。0 に解決する。円には circle を使う */
  pill: 0,
  /** 幅 = 高さ の要素のみ。長方形に使わない */
  circle: 9999,
} as const;

// ── Semantic colors（寒色モノクロ / hue 220）────────────────
// デザインシステム v0.6 準拠。純グレー（R=G=B）は使わず、hue 220 の
// 連続 11 段ランプ（n0 #FFFFFF 〜 n10 #14181C）から採る。
// 有彩色は signal 1 色（light #B64351 / dark #DD7E8B）のみで、
// 用途は録音・LIVE と破壊的操作の確認に限定する。
// success / warning / info はランプ内の明度差で表す（v0.6 で脱色）。
// 状態を色のみで符号化しない（必ず文字・図形・音・a11y ラベルと併用）。
//
// コントラスト実測（on #FFFFFF）:
//   foregroundSecondary #535B67  6.86:1
//   foregroundTertiary  #8C95A3  3.02:1 … 15pt 以上か非テキストのみ
//   foregroundPrimary   #14181C 17.84:1
//   recording           #B64351  5.37:1
const light = {
  canvas: '#F9FAFB',
  surface: '#FFFFFF',
  surfaceAlt: '#F3F4F7',
  surfaceElevated: '#FFFFFF',
  surfaceInverse: '#14181C',

  foregroundPrimary: '#14181C',
  foregroundSecondary: '#535B67',
  foregroundTertiary: '#8C95A3',
  foregroundQuaternary: '#C2C8D0',
  foregroundInverse: '#FFFFFF',

  border: '#DFE2E7',
  borderStrong: '#C2C8D0',
  hairline: '#EBEDF1',

  selection: '#EBEDF1',
  selectionForeground: '#14181C',
  focus: '#14181C',

  accent: '#14181C',
  accentSoft: '#EBEDF1',

  recording: '#B64351',
  recordingSoft: '#F9EBED',
  danger: '#B64351',
  dangerSoft: '#F9EBED',
  processing: '#666F7D',
  processingSoft: '#EBEDF1',
  success: '#535B67',
  successSoft: '#EBEDF1',
  warning: '#535B67',
  warningSoft: '#F3F4F7',
  info: '#666F7D',
  infoSoft: '#F3F4F7',

  scrim: 'rgba(20,24,28,0.44)',
  scrimLight: 'rgba(20,24,28,0.20)',

  glassFallback: 'rgba(249,250,251,0.78)',
  glassBorderFallback: 'rgba(20,24,28,0.10)',
} as const;

const dark = {
  canvas: '#0F1014',
  surface: '#15171C',
  surfaceAlt: '#1E2025',
  surfaceElevated: '#262A30',
  surfaceInverse: '#F9FAFB',

  foregroundPrimary: '#E7E8EC',
  foregroundSecondary: '#9197A1',
  foregroundTertiary: '#6E757F',
  foregroundQuaternary: '#454B54',
  foregroundInverse: '#0F1014',

  border: '#2F333A',
  borderStrong: '#454B54',
  hairline: '#1E2025',

  selection: '#262A30',
  selectionForeground: '#E7E8EC',
  focus: '#E7E8EC',

  accent: '#E7E8EC',
  accentSoft: '#23262B',

  recording: '#DD7E8B',
  recordingSoft: '#2A1D20',
  danger: '#DD7E8B',
  dangerSoft: '#2A1D20',
  processing: '#9197A1',
  processingSoft: '#23262B',
  success: '#9197A1',
  successSoft: '#23262B',
  warning: '#9197A1',
  warningSoft: '#23262B',
  info: '#9197A1',
  infoSoft: '#1E2025',

  scrim: 'rgba(0,0,0,0.60)',
  scrimLight: 'rgba(0,0,0,0.35)',

  glassFallback: 'rgba(15,16,20,0.72)',
  glassBorderFallback: 'rgba(255,255,255,0.12)',
} as const;

export const colors = { light, dark } as const;

export type ColorScheme = keyof typeof colors;
export type SemanticColor = keyof typeof colors.light;

// ── Typography（プラットフォーム System / 日本語フォールバック）─
// 大見出し（title1/2/3）と小さなメタデータ（caption/footnote）の
// コントラストが設計原則。メタデータは小さく・wide tracking で
// 技術的で正確な印象を与える。
// 行間は固定 px ではなく比率で扱い、Dynamic Type 拡大時も比例して
// 伸びるようにする（コンポーネント側は allowFontScaling=true を維持）。
// ── Font families（v0.6: IBM Plex）─────────────────────────
// !! RN はフォントフォールバックチェーンを持たない。fontFamily は 1 つだけで、
//    Web の「欧文 Plex Sans / 和文 Plex Sans JP」という分離は再現できない。
//    そのため既定は和欧どちらも破綻しない Plex Sans JP とし、
//    欧文が確定している要素（大文字ラベル等）だけ latin.* を明示する。
//    数値は必ず mono.*（tabular-nums と併用）。
// 読み込みは app/_layout.tsx の useFonts。未ロード時は描画しない。
export const fontFamily = {
  jp: {
    light: 'IBMPlexSansJP_300Light',
    regular: 'IBMPlexSansJP_400Regular',
    medium: 'IBMPlexSansJP_500Medium',
    semibold: 'IBMPlexSansJP_600SemiBold',
  },
  // v0.7: 欧文は Inter を採用。Plex Sans JP と x-height 差 0.9% で、
  // 同じ fontSize のまま混植しても段差が出ない（Plex Sans は 4.6% 小さく、
  // Web では font-size-adjust で埋めていたが RN にその仕組みが無い）。
  latin: {
    light: 'Inter_300Light',
    regular: 'Inter_400Regular',
    medium: 'Inter_500Medium',
    semibold: 'Inter_600SemiBold',
  },
  mono: {
    regular: 'IBMPlexMono_400Regular',
    medium: 'IBMPlexMono_500Medium',
  },
} as const;

export const typography = {
  size: {
    caption2: 11,
    caption1: 12,
    footnote: 13,
    subheadline: 15,
    callout: 16,
    body: 17,
    headline: 17,
    title3: 20,
    title2: 22,
    title1: 28,
    largeTitle: 34,
  },
  lineHeight: (fontSize: number) => Math.round(fontSize * 1.5),
  letterSpacing: {
    tightLargeTitle: -0.4,
    tightTitle: -0.2,
    normal: 0,
    wide: 0.3,
  },
  weight: {
    regular: '400',
    medium: '500',
    semibold: '600',
    bold: '700',
  } as const,
} as const;

// ── Touch targets（最小44pt は要件）──────────────────────────
export const touchTarget = {
  min: 44,
  default: 44,
  comfortable: 48,
  fab: 56,
} as const;

// ── Icons ──────────────────────────────────────────────────
export const icon = {
  xs: 14,
  sm: 16,
  md: 20,
  lg: 24,
  xl: 28,
} as const;

// ── Opacity / state ────────────────────────────────────────
export const opacity = {
  pressed: 0.5,
  disabled: 0.38,
  dimmed: 0.6,
  placeholder: 0.4,
  scrim: 0.4,
  scrimLight: 0.2,
} as const;

// ── Motion ─────────────────────────────────────────────────
// Reduce Motion 有効時は reducedDuration へ差し替える（fade のみ
// 残し、移動・スケール・スクロール駆動のアニメーションを止める）。
// 実行時の検出は AccessibilityInfo / useReducedMotion 系フックを
// アプリ側で行い、本ファイルは代替値のみ定義する。
export const motion = {
  duration: {
    fast: 120,
    normal: 200,
    deliberate: 320,
    slow: 480,
  },
  // v0.6: 3 段＋リビール。cubic-bezier は easing.* と組で使う。
  // spring / bounce / overshoot は UI クロームに使わない。
  state: 110, // hover / press / focus
  move: 180, // 出現・移動・展開
  page: 260, // 画面遷移・シート
  reveal: 560, // スクロールリビール（総時間の上限でもある）
  char: 140, // 文字単位リビールの 1 文字あたり
  // Easing.bezier(...) に渡す制御点。Reanimated / RN Animated 共通。
  easing: {
    standard: [0.2, 0, 0.2, 1],
    out: [0, 0, 0.2, 1],
    in: [0.4, 0, 1, 1],
  },
  reducedDuration: {
    fast: 0,
    normal: 0,
    deliberate: 120,
    slow: 120,
  },
  spring: {
    control: { damping: 20, stiffness: 350, mass: 0.5 },
    sheet: { damping: 28, stiffness: 300, mass: 0.9 },
    fab: { damping: 18, stiffness: 320, mass: 0.6 },
    subtle: { damping: 22, stiffness: 200, mass: 1 },
  },
} as const;

// ── Shadow policy（ゼロ/デフォルトなし）──────────────────────
// 影はデフォルトの階層手段ではない。影を許容するのは
// 浮遊ナビゲーション（BottomAccessory / Liquid Glass）と録音FAB
// に限定した控えめトークンのみ。カード・リスト行・セクションに
// 影を付けてはならない。
export const shadow = {
  none: {
    shadowColor: 'transparent',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0,
    shadowRadius: 0,
    elevation: 0,
  },
  floatingNav: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 16,
    elevation: 6,
  },
  recordingFab: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.12,
    shadowRadius: 20,
    elevation: 8,
  },
} as const;

// ── Data visualization ─────────────────────────────────────
// 色は colors.* の意味論ロールを参照する（波形 active は
// foregroundPrimary / inactive は hairline。処理中は processing +
// processingSoft。話者表示は foregroundSecondary 等）。ここでは
// 形状・周期パラメータのみ定義する。
export const dataViz = {
  waveform: {
    barWidth: 2,
    barGap: 2,
    minHeight: 4,
    maxHeight: 56,
  },
  transcript: {
    segmentGap: 12,
    speakerLabelWidth: 68,
    speakerChipSize: 24,
  },
  processing: {
    railHeight: 3,
    dotSize: 6,
    indeterminateCycle: 0.9,
  },
} as const;
