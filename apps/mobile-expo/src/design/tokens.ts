// ============================================================
// Memora Design Tokens — 互換アダプタ
// 更新: 2026-08-02
//
// このモジュールは既存画面（`../design/tokens` import）を壊さずに
// `src/theme/tokens.ts`（意味論トークン正本）へ委譲する互換レイヤー。
// 生HEXはここに書かず、全て theme の意味論ロールを参照する。
// System フォント方針のため fontFamily は指定しない。
//
// 移行経路: docs/design/MEMORA_DESIGN.md §13
// ============================================================

import type { LayoutAnimationConfig } from 'react-native';
import {
  colors as themeColors,
  typography as themeTypography,
  space,
  screenMargin,
  radius as themeRadius,
  shadow as themeShadow,
  icon,
  motion as themeMotion,
} from '../theme/tokens';

// ── Fonts（System フォント。fontFamily を指定しない）──────────
// 装飾的な極細・極太は避け、regular/medium/semibold 系へ正規化する。
const systemWeight = themeTypography.weight;

export const fonts = {
  sans: {
    extralight: { fontWeight: systemWeight.regular },
    light:      { fontWeight: systemWeight.medium },
    regular:    { fontWeight: systemWeight.regular },
    medium:     { fontWeight: systemWeight.medium },
    semibold:   { fontWeight: systemWeight.semibold },
  },
  display: {
    extralight: { fontWeight: systemWeight.regular },
    light:      { fontWeight: systemWeight.medium },
  },
  mono: {
    regular:  { fontWeight: systemWeight.regular, fontVariant: ['tabular-nums'] as 'tabular-nums'[] },
    bold:     { fontWeight: systemWeight.bold, fontVariant: ['tabular-nums'] as 'tabular-nums'[] },
  },
} as const;

// ── Colors (Light) ─────────────────────────────────────────
const L = themeColors.light;

export const colors = {
  canvas:         L.canvas,
  surface:        L.surface,
  surfaceAlt:     L.surfaceAlt,
  surfaceElevated: L.surfaceElevated,

  text:           L.foregroundPrimary,
  textSecondary:  L.foregroundSecondary,
  textTertiary:   L.foregroundTertiary,
  textInverse:    L.foregroundInverse,

  border:         L.border,
  borderLight:    L.hairline,
  separator:      L.hairline,

  accent:         L.accent,
  accentSoft:     L.accentSoft,
  accentMuted:    L.foregroundQuaternary,

  success:        L.success,
  successSoft:    L.successSoft,
  warning:        L.warning,
  warningSoft:    L.warningSoft,
  danger:         L.danger,
  dangerSoft:     L.dangerSoft,
  info:           L.info,
  infoSoft:       L.infoSoft,

  recording:      L.recording,
  recordingSoft:  L.recordingSoft,

  skeleton:       L.processingSoft,
  skeletonShimmer: L.surfaceAlt,

  overlay:        L.scrim,
  overlayLight:   L.scrimLight,

  // Category（互換表示用。各スロットが両テーマで重複しないロールを参照）
  categorySlate:  L.foregroundSecondary,
  categoryTeal:   L.info,
  categoryOlive:  L.success,
  categoryMauve:  L.warning,
} as const;

// ── Colors (Dark) ──────────────────────────────────────────
const D = themeColors.dark;

export const darkColors = {
  canvas:         D.canvas,
  surface:        D.surface,
  surfaceAlt:     D.surfaceAlt,
  surfaceElevated: D.surfaceElevated,

  text:           D.foregroundPrimary,
  textSecondary:  D.foregroundSecondary,
  textTertiary:   D.foregroundTertiary,
  textInverse:    D.foregroundInverse,

  border:         D.border,
  borderLight:    D.hairline,
  separator:      D.hairline,

  accent:         D.accent,
  accentSoft:     D.accentSoft,
  accentMuted:    D.foregroundQuaternary,

  success:        D.success,
  successSoft:    D.successSoft,
  warning:        D.warning,
  warningSoft:    D.warningSoft,
  danger:         D.danger,
  dangerSoft:     D.dangerSoft,
  info:           D.info,
  infoSoft:       D.infoSoft,

  recording:      D.recording,
  recordingSoft:  D.recordingSoft,

  skeleton:       D.processingSoft,
  skeletonShimmer: D.surfaceAlt,

  overlay:        D.scrim,
  overlayLight:   D.scrimLight,

  // Category（互換表示用。各スロットが両テーマで重複しないロールを参照）
  categorySlate:  D.foregroundSecondary,
  categoryTeal:   D.info,
  categoryOlive:  D.success,
  categoryMauve:  D.warning,
} as const;

// ── Spacing（4pt 基底）──────────────────────────────────────
export const spacing = {
  xxs:  space.xxs,
  xs:   space.xs,
  sm:   space.sm,
  md:   space.md,
  lg:   space.lg,
  xl:   space.xl,
  xxl:  space.xxl,
} as const;

export const screenPadding = {
  horizontal: screenMargin.regular,
} as const;

// ── Radius ─────────────────────────────────────────────────
export const radius = {
  xs:    themeRadius.xs,
  sm:    themeRadius.sm,
  md:    themeRadius.md,
  lg:    themeRadius.lg,
  pill:  themeRadius.pill,
} as const;

// ── Typography ─────────────────────────────────────────────
const T = themeTypography;

export const typography = {
  size: {
    caption:   T.size.caption2,
    footnote:  T.size.footnote,
    body:      T.size.body,
    callout:   T.size.callout,
    title3:    T.size.title3,
    title2:    T.size.title2,
    title1:    T.size.title1,
    // Legacy consumers treated `headline` as a display-scale size.
    headline:  T.size.largeTitle,
  },
  // Preserve the legacy optional ratio while defaulting to the theme rhythm.
  lineHeight: (fontSize: number, ratio: number = 1.5) =>
    Math.round(fontSize * ratio),
  letterSpacing: {
    tight:  T.letterSpacing.tightLargeTitle,
    normal: T.letterSpacing.normal,
    wide:   T.letterSpacing.wide,
  },
} as const;

// ── Text style presets ─────────────────────────────────────
export const textStyles = {
  display: {
    fontSize: T.size.largeTitle,
    lineHeight: T.lineHeight(T.size.largeTitle),
    letterSpacing: T.letterSpacing.tightLargeTitle,
    ...fonts.sans.extralight,
  },
  screenTitle: {
    fontSize: T.size.title1,
    lineHeight: T.lineHeight(T.size.title1),
    letterSpacing: T.letterSpacing.tightTitle,
    ...fonts.sans.extralight,
  },
  title2: {
    fontSize: T.size.title2,
    lineHeight: T.lineHeight(T.size.title2),
    ...fonts.sans.extralight,
  },
  sectionTitle: {
    fontSize: T.size.title3,
    lineHeight: T.lineHeight(T.size.title3),
    ...fonts.sans.extralight,
  },
  callout: {
    fontSize: T.size.callout,
    lineHeight: T.lineHeight(T.size.callout),
    ...fonts.sans.extralight,
  },
  body: {
    fontSize: T.size.body,
    lineHeight: T.lineHeight(T.size.body),
    ...fonts.sans.extralight,
  },
  bodyBold: {
    fontSize: T.size.body,
    lineHeight: T.lineHeight(T.size.body),
    ...fonts.sans.light,
  },
  footnote: {
    fontSize: T.size.footnote,
    lineHeight: T.lineHeight(T.size.footnote),
    ...fonts.sans.extralight,
  },
  footnoteBold: {
    fontSize: T.size.footnote,
    lineHeight: T.lineHeight(T.size.footnote),
    ...fonts.sans.light,
  },
  caption: {
    fontSize: T.size.caption2,
    lineHeight: T.lineHeight(T.size.caption2),
    letterSpacing: T.letterSpacing.wide,
    ...fonts.sans.light,
  },
  captionBold: {
    fontSize: T.size.caption2,
    lineHeight: T.lineHeight(T.size.caption2),
    letterSpacing: T.letterSpacing.wide,
    ...fonts.sans.light,
  },
  monoBody: {
    fontSize: T.size.footnote,
    lineHeight: T.lineHeight(T.size.footnote),
    ...fonts.mono.regular,
  },
} as const;

// ── Shadows（カード・エレベーテッドは影なしへマップ）────────────
export const shadow = {
  card:     themeShadow.none,
  elevated: themeShadow.none,
  floating: themeShadow.floatingNav,
} as const;

// ── Icons ──────────────────────────────────────────────────
export const iconSize = {
  sm:  icon.sm,
  md:  icon.md,
  lg:  icon.lg,
  xl:  icon.xl,
} as const;

// ── Motion presets ─────────────────────────────────────────
export const motion = {
  duration: {
    fast:   themeMotion.duration.fast,
    normal: themeMotion.duration.normal,
    slow:   themeMotion.duration.slow,
  },
  spring: {
    tap: themeMotion.spring.control,
  },
  layout: {
    easeInEaseOut: {
      duration: themeMotion.duration.deliberate,
      create: { type: 'easeInEaseOut', property: 'opacity' },
      update: { type: 'easeInEaseOut' },
      delete: { type: 'easeInEaseOut', property: 'opacity' },
    } as LayoutAnimationConfig,
  },
} as const;
