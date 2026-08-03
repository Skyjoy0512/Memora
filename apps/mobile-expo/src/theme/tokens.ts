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

// ── Radii（控えめ。4pt 基底）────────────────────────────────
export const radius = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  pill: 9999,
} as const;

// ── Semantic colors（モノクロ基調）──────────────────────────
// 赤は recording / danger の意味論例外のみ。状態を色のみで符号化
// しない（必ず文字・図形・音・アクセシビリティラベルと併用）。
const light = {
  canvas: '#F7F7F6',
  surface: '#FFFFFF',
  surfaceAlt: '#F1F1F0',
  surfaceElevated: '#FFFFFF',
  surfaceInverse: '#1B1C1E',

  foregroundPrimary: '#16171A',
  foregroundSecondary: '#5E6063',
  foregroundTertiary: '#949699',
  foregroundQuaternary: '#C3C4C6',
  foregroundInverse: '#FFFFFF',

  border: '#E3E3E1',
  borderStrong: '#C9CACB',
  hairline: '#EDEDEC',

  selection: '#E9EAE9',
  selectionForeground: '#16171A',
  focus: '#16171A',

  accent: '#16171A',
  accentSoft: '#ECECEA',

  recording: '#A34B45',
  recordingSoft: '#F6ECEB',
  danger: '#A34B45',
  dangerSoft: '#F6ECEB',
  processing: '#5E6063',
  processingSoft: '#EDEDEC',
  success: '#4F7A55',
  successSoft: '#EDF2ED',
  warning: '#8A6A3C',
  warningSoft: '#F5EFE7',
  info: '#4E5E6B',
  infoSoft: '#ECF0F3',

  scrim: 'rgba(0,0,0,0.40)',
  scrimLight: 'rgba(0,0,0,0.20)',

  glassFallback: 'rgba(247,247,246,0.78)',
  glassBorderFallback: 'rgba(22,23,26,0.10)',
} as const;

const dark = {
  canvas: '#101112',
  surface: '#17181A',
  surfaceAlt: '#202123',
  surfaceElevated: '#26272A',
  surfaceInverse: '#F2F2F1',

  foregroundPrimary: '#E9E9E8',
  foregroundSecondary: '#9C9D9F',
  foregroundTertiary: '#6E7073',
  foregroundQuaternary: '#45474A',
  foregroundInverse: '#101112',

  border: '#2E2F31',
  borderStrong: '#45474A',
  hairline: '#26272A',

  selection: '#2A2C2E',
  selectionForeground: '#E9E9E8',
  focus: '#E9E9E8',

  accent: '#E9E9E8',
  accentSoft: '#232527',

  recording: '#C98884',
  recordingSoft: '#2E2120',
  danger: '#C98884',
  dangerSoft: '#2E2120',
  processing: '#9C9D9F',
  processingSoft: '#232527',
  success: '#7FA187',
  successSoft: '#1E2A20',
  warning: '#B99A6C',
  warningSoft: '#2B2620',
  info: '#8B9CA8',
  infoSoft: '#1E262C',

  scrim: 'rgba(0,0,0,0.60)',
  scrimLight: 'rgba(0,0,0,0.35)',

  glassFallback: 'rgba(16,17,18,0.72)',
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
